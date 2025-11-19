const express = require('express');
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

// Region defaults to us-east-1 if not set
const REGION = process.env.AWS_REGION || "us-east-1";
const TABLE_NAME = "ticket-booking-users"; // Must match Terraform!

// Initialize DynamoDB Client
// In EKS, this automatically picks up credentials from the Node IAM Role
const client = new DynamoDBClient({ region: REGION });
const docClient = DynamoDBDocumentClient.from(client);

// --- ROUTES ---

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Create a new User
app.post('/users', async (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: "Name and Email are required" });
  }

  const userId = uuidv4();
  const newUser = {
    userId: userId,
    name: name,
    email: email,
    createdAt: new Date().toISOString()
  };

  try {
    const command = new PutCommand({
      TableName: TABLE_NAME,
      Item: newUser
    });
    await docClient.send(command);
    res.status(201).json(newUser);
  } catch (error) {
    console.error("DynamoDB Error:", error);
    res.status(500).json({ error: "Could not create user" });
  }
});

// Get User by ID
app.get('/users/:id', async (req, res) => {
  try {
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: { userId: req.params.id }
    });
    const response = await docClient.send(command);

    if (response.Item) {
      res.json(response.Item);
    } else {
      res.status(404).json({ error: "User not found" });
    }
  } catch (error) {
    console.error("DynamoDB Error:", error);
    res.status(500).json({ error: "Could not fetch user" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`User Service running on port ${PORT}`);
});