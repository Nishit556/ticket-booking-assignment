const express = require('express');
const axios = require('axios');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
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
const BUCKET_NAME = "ticket-booking-raw-data-YOUR_ID_HERE"; // <--- WE WILL FIX THIS LATER AUTOMATICALLY

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

app.get('/health', (req, res) => res.send('OK'));

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Frontend Proxy running on port ${PORT}`);
});