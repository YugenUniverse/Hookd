var express = require('express');
var router = express.Router();

const connectDB = require('../db');

/* GET home page */
router.get('/', async function(req, res, next) {
  try {
    const db = await connectDB();

    const users = await db
      .collection('users')
      .find()
      .toArray();

    res.json(users);

  } catch (err) {
    next(err);
  }
});

/* POST user */
router.post('/users', async function(req, res, next) {
  try {
    const db = await connectDB();

    const result = await db
      .collection('users')
      .insertOne({
        name: req.body.name
      });

    res.json(result);

  } catch (err) {
    next(err);
  }
});

module.exports = router;