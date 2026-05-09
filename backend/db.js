const { MongoClient } = require('mongodb');

const uri = 'mongodb://127.0.0.1:27017';
const client = new MongoClient(uri);

let db;

// Connect to MongoDB and initialize database schema
// Reuses cached connection if already established (returns early if db exists)
async function connectDB() {
  if (db) return db;

  await client.connect();

  console.log('Connected to MongoDB');

  db = client.db('hookd');

  // Create indexes on refresh_tokens collection for performance and auto-cleanup
  await db.collection('refresh_tokens').createIndexes([
    {
      // Unique index on tokenId: prevents duplicate token IDs and speeds up token lookups
      key: { tokenId: 1 },
      name: 'refresh_tokens_tokenId_unique',
      unique: true
    },
    {
      // TTL index on expiresAt: automatically deletes expired tokens after their timestamp
      // expireAfterSeconds: 0 means documents expire exactly at the expiresAt field value
      key: { expiresAt: 1 },
      name: 'refresh_tokens_expiresAt_ttl',
      expireAfterSeconds: 0
    }
  ]);

  return db;
}

module.exports = connectDB;