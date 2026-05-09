// controllers/auth.controller.js

const authService = require('../services/auth.service');

exports.register = async (req, res, next) => {
  try {
    const user = await authService.register(req.body);

    res.status(201).json({
      message: 'User created',
      user
    });

  } catch (err) {
    next(err);
  }
};