const jwt = require('jsonwebtoken');

const getJwtSecret = () => {
  if (!process.env.JWT_SECRET) {
    const error = new Error('JWT_SECRET is not configured');
    error.statusCode = 500;
    throw error;
  }

  return process.env.JWT_SECRET;
};

const authenticateJwt = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || '';

    if (!authHeader.startsWith('Bearer ')) {
      const error = new Error('Missing or invalid Authorization header');
      error.statusCode = 401;
      throw error;
    }

    const token = authHeader.slice('Bearer '.length);

    const payload = jwt.verify(token, getJwtSecret(), {
      issuer: 'hookd'
    });

    req.user = {
      id: payload.sub,
      email: payload.email
    };

    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      err.statusCode = 401;
      err.message = 'Invalid or expired access token';
    }

    next(err);
  }
};

module.exports = {
  authenticateJwt
};