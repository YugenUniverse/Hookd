// services/auth.service.js

const bcrypt = require('bcrypt');

const connectDB = require('../db');

exports.register = async ({ email, password }) => {
  if (!email || !password) {
    throw new Error('Missing fields');
  }

  const db = await connectDB();

  const existingUser = await db
    .collection('users')
    .findOne({ email });

  if (existingUser) {
    throw new Error('User already exists');
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  const user = {
    email,
    password: hashedPassword,
    createdAt: new Date()
  };

  const result = await db
    .collection('users')
    .insertOne(user);

  return {
    id: result.insertedId,
    email: user.email
  };
};