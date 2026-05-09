const { MongoClient } = require('mongodb');
const uri = 'mongodb://127.0.0.1:27017';
const client = new MongoClient(uri);

let db;

async function connectDB() {
  if (db) return db;

  await client.connect();

  console.log('Connected to MongoDB');

  db = client.db('hookd');

  return db;
}

module.exports = connectDB;