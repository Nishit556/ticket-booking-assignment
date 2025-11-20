const express = require('express');
const axios = require('axios');
const multer = require('multer');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const path = require('path');
const fs = require('fs');

const app = express();
const upload = multer({ dest: 'uploads/' }); // Temp storage for uploads

app.use(express.static('public'));
app.use(express.json());

// --- CONFIGURATION (Internal K8s DNS) ---
// These addresses ONLY work inside the cluster, which is why this Node server must do the calling.
const BOOKING_SERVICE_URL = process.env.BOOKING_SERVICE_URL || 'http://booking-service:5000';
const EVENT_SERVICE_URL = process.env.EVENT_SERVICE_URL || 'http://event-catalog:5000';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:3000';

// S3 Configuration (For Ticket Generator)
// We pick up credentials automatically from the EKS Node Role
const s3Client = new S3Client({ region: "us-east-1" });
const BUCKET_NAME = "ticket-booking-raw-data-1f8db074";
const DEMO_FILE_PATH = path.join(__dirname, '..', '..', 'id_proof.txt');

// --- API ROUTES ---

// 1. Proxy to Event Catalog
app.get('/api/events', async (req, res) => {
  try {
    const response = await axios.get(`${EVENT_SERVICE_URL}/events`);
    res.json(response.data);
  } catch (error) {
    console.error("Event Service Error:", error.message);
    res.status(500).json({ error: "Could not fetch events" });
  }
});

// 2. Proxy to Booking Service
app.post('/api/book', async (req, res) => {
  try {
    const response = await axios.post(`${BOOKING_SERVICE_URL}/book`, req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    console.error("Booking Service Error:", error.message);
    res.status(500).json({ error: "Booking failed" });
  }
});

// 3. Proxy to User Service
app.post('/api/users', async (req, res) => {
  try {
    const response = await axios.post(`${USER_SERVICE_URL}/users`, req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    console.error("User Service Error:", error.message);
    res.status(500).json({ error: "Registration failed" });
  }
});

// 4. Handle File Upload (Triggers Lambda)
app.post('/api/upload', upload.single('id_proof'), async (req, res) => {
  if (!req.file) return res.status(400).send('No file uploaded.');

  // Read the file from temp storage
  const fileContent = fs.readFileSync(req.file.path);
  const key = `uploads/${req.file.originalname}`;

  try {
    // Upload to S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: fileContent
    });
    await s3Client.send(command);
    
    // Cleanup temp file
    fs.unlinkSync(req.file.path);

    res.json({ message: "File uploaded successfully! Ticket generation started." });
  } catch (error) {
    console.error("S3 Upload Error:", error);
    res.status(500).send("Upload failed.");
  }
});

// 5. List Generated Tickets (from Lambda)
app.get('/api/tickets', async (_req, res) => {
  try {
    const command = new ListObjectsV2Command({
      Bucket: BUCKET_NAME,
      Prefix: 'tickets/'
    });
    const data = await s3Client.send(command);
    const items = (data.Contents || [])
      .filter(obj => obj.Key && obj.Key !== 'tickets/')
      .sort((a, b) => new Date(b.LastModified) - new Date(a.LastModified))
      .map(obj => ({
        key: obj.Key,
        lastModified: obj.LastModified
      }));
    res.json(items);
  } catch (error) {
    console.error("Ticket list error:", error);
    res.status(500).json({ error: "Unable to list tickets" });
  }
});

// 6. Demo Upload helper (uses bundled sample file)
app.post('/api/demo-upload', async (_req, res) => {
  try {
    if (!fs.existsSync(DEMO_FILE_PATH)) {
      return res.status(500).json({ error: "Demo file not found on server" });
    }
    const fileContent = fs.readFileSync(DEMO_FILE_PATH);
    const key = `uploads/demo_${Date.now()}.txt`;
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: fileContent
    });
    await s3Client.send(command);
    res.json({ message: "Demo file uploaded. Ticket generation in progress." });
  } catch (error) {
    console.error("Demo upload error:", error);
    res.status(500).json({ error: "Demo upload failed" });
  }
});

// 7. Aggregate service status
app.get('/api/status', async (_req, res) => {
  const services = [
    { name: 'booking', url: `${BOOKING_SERVICE_URL}/health` },
    { name: 'event', url: `${EVENT_SERVICE_URL}/health` },
    { name: 'user', url: `${USER_SERVICE_URL}/health` }
  ];

  const results = await Promise.all(services.map(async svc => {
    try {
      const response = await axios.get(svc.url, { timeout: 2000 });
      return { name: svc.name, ok: true, data: response.data };
    } catch (error) {
      return { name: svc.name, ok: false, error: error.message };
    }
  }));

  res.json(results);
});

app.get('/health', (req, res) => res.send('OK'));

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Frontend Proxy running on port ${PORT}`);
});