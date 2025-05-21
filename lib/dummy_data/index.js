require('dotenv').config();
const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json'); // Path to your Firebase service account key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.DATABASE_URL
});

// Reference to the database
const db = admin.database();
const ref = db.ref('sensor_readings');

function randomValue(min, max) {
  return Math.random() * (max - min) + min;
}

function generateSensorData() {
  const data = {
    co2: randomValue(400, 1500).toFixed(1),           // CO2 in ppm (400-1500)
    humidity: randomValue(30, 80).toFixed(1),         // Humidity in % (30-80)
    temperature: randomValue(18, 32).toFixed(1),      // Temperature in °C (18-32)
    smoke: randomValue(10, 100).toFixed(1),            // smoke in µg/m³ (10-100)
    timestamp: admin.database.ServerValue.TIMESTAMP   // Current timestamp
  };
  
  return data;
}

// Function to push data to Firebase
function pushDataToFirebase() {
  const sensorData = generateSensorData();
  
  // Push data with auto-generated ID
  ref.push(sensorData)
    .then(() => {
      console.log('Data pushed successfully:', sensorData);
    })
    .catch((error) => {
      console.error('Error pushing data:', error);
    });
}

console.log('Starting to push random sensor data to Firebase every 3 seconds...');
setInterval(pushDataToFirebase, 3000);

// Push initial data immediately
pushDataToFirebase();