// Load environment variables from parent directory
require('dotenv').config({ path: '../.env' });

const express = require('express');
const app = express();

// Use environment variables
const port = process.env.PORT || 3000;
const appName = process.env.APP_NAME || 'secure-supply-chain';
const nodeEnv = process.env.NODE_ENV || 'development';

// Middleware for JSON parsing
app.use(express.json());

// Main route
app.get('/', (req, res) => {
  res.json({
    message: `Hello from ${appName}! 🚀`,
    environment: nodeEnv,
    version: process.env.APP_VERSION || '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint (required by your deployment)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    app: appName,
    uptime: process.uptime()
  });
});

// Readiness check endpoint (required by your deployment)
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    app: appName,
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`${appName} listening on port ${port} in ${nodeEnv} mode`);
});
