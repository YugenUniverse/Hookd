// services/auth.service.js

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { ObjectId } = require('mongodb');

const connectDB = require('../db');

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || '7d';
const ISSUER = 'hookd';

const getJwtSecret = () => {
  if (!process.env.JWT_SECRET) {
    const error = new Error('JWT_SECRET is not configured');
    error.statusCode = 500;
    throw error;
  }

  return process.env.JWT_SECRET;
};

const getRefreshTokenSecret = () => {
  return process.env.REFRESH_TOKEN_SECRET || getJwtSecret();
};

const parseExpiresInToDate = (expiresIn) => {
  if (typeof expiresIn === 'number') {
    return new Date(Date.now() + expiresIn * 1000);
  }

  const match = String(expiresIn).trim().match(/^(\d+)([smhd])$/i);

  if (!match) {
    throw new Error('Invalid token expiration format');
  }

  const amount = Number(match[1]);
  const unit = match[2].toLowerCase();

  const multipliers = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000
  };

  return new Date(Date.now() + (amount * multipliers[unit]));
};

const generateAccessToken = (user) => {
  return jwt.sign(
    {
      sub: user._id.toString(),
      email: user.email
    },
    getJwtSecret(),
    {
      expiresIn: JWT_EXPIRES_IN,
      issuer: ISSUER
    }
  );
};

const createRefreshToken = async (db, user) => {
  const tokenId = crypto.randomUUID();

  const refreshToken = jwt.sign(
    {
      sub: user._id.toString(),
      type: 'refresh',
      jti: tokenId
    },
    getRefreshTokenSecret(),
    {
      expiresIn: REFRESH_TOKEN_EXPIRES_IN,
      issuer: ISSUER
    }
  );

  await db.collection('refresh_tokens').insertOne({
    tokenId,
    userId: user._id,
    revokedAt: null,
    createdAt: new Date(),
    expiresAt: parseExpiresInToDate(REFRESH_TOKEN_EXPIRES_IN)
  });

  return refreshToken;
};

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

exports.login = async ({ email, password }) => {
  if (!email || !password) {
    throw new Error('Missing fields');
  }

  const db = await connectDB();

  const user = await db
    .collection('users')
    .findOne({ email });

  if (!user) {
    throw new Error('Invalid credentials');
  }

  const isMatch = await bcrypt.compare(password, user.password);

  if (!isMatch) {
    throw new Error('Invalid credentials');
  }

  const accessToken = generateAccessToken(user);
  const refreshToken = await createRefreshToken(db, user);

  return {
    accessToken,
    refreshToken
  };
};

exports.refreshTokens = async ({ refreshToken }) => {
  if (!refreshToken) {
    const error = new Error('Refresh token is required');
    error.statusCode = 400;
    throw error;
  }

  let payload;

  try {
    payload = jwt.verify(refreshToken, getRefreshTokenSecret(), {
      issuer: ISSUER
    });
  } catch (err) {
    err.statusCode = 401;
    err.message = 'Invalid or expired refresh token';
    throw err;
  }

  if (payload.type !== 'refresh' || !payload.jti || !payload.sub) {
    const error = new Error('Malformed refresh token');
    error.statusCode = 401;
    throw error;
  }

  const db = await connectDB();

  const refreshTokenDoc = await db.collection('refresh_tokens').findOne({
    tokenId: payload.jti,
    userId: new ObjectId(payload.sub),
    revokedAt: null,
    expiresAt: { $gt: new Date() }
  });

  if (!refreshTokenDoc) {
    const error = new Error('Refresh token has been revoked or expired');
    error.statusCode = 401;
    throw error;
  }

  await db.collection('refresh_tokens').updateOne(
    { _id: refreshTokenDoc._id },
    { $set: { revokedAt: new Date() } }
  );

  const user = await db.collection('users').findOne({ _id: refreshTokenDoc.userId });

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 401;
    throw error;
  }

  const accessToken = generateAccessToken(user);
  const newRefreshToken = await createRefreshToken(db, user);

  return {
    accessToken,
    refreshToken: newRefreshToken
  };
};

exports.logout = async ({ refreshToken }) => {
  if (!refreshToken) {
    return;
  }

  try {
    const payload = jwt.verify(refreshToken, getRefreshTokenSecret(), {
      issuer: ISSUER,
      ignoreExpiration: true
    });

    if (!payload.jti) {
      return;
    }

    const db = await connectDB();

    await db.collection('refresh_tokens').updateOne(
      { tokenId: payload.jti, revokedAt: null },
      { $set: { revokedAt: new Date() } }
    );
  } catch (err) {
    return;
  }
};