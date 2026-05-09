var express = require('express');
var router = express.Router();

const connectDB = require('../db');

/* POST register */

router.post('/register', async function(req, res, next) {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const db = await connectDB();
    
    const existingUser = await db.collection('users').findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: 'Username already exists' });
    }

    const result = await db.collection('users').insertOne({ username, password });

    res.status(201).json({ message: 'User registered successfully', userId: result.insertedId });
  } catch (err) {
    next(err);
  }
});

module.exports = router;