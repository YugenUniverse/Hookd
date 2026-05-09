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

exports.login = async (req, res, next) => {
  try {
    const tokens = await authService.login(req.body);
    
    res.status(200).json({
      message: 'Login successful',
      ...tokens
    });
  } catch (err) {
    next(err);
  }
};

exports.refresh = async (req, res, next) => {
  try {
    const tokens = await authService.refreshTokens(req.body);

    res.status(200).json({
      message: 'Token refreshed',
      ...tokens
    });
  } catch (err) {
    next(err);
  }
};

exports.logout = async (req, res, next) => {
  try {
    await authService.logout(req.body);

    res.status(200).json({
      message: 'Logged out'
    });
  } catch (err) {
    next(err);
  }
};

exports.me = async (req, res) => {
  res.status(200).json({
    user: req.user
  });
};

exports.googleLogin = async (req, res, next) => {
  try {
    const tokens = await authService.googleLogin(req.body);
    res.status.json({
      message: "Google login successful",
      ...tokens
    })
  } catch (err) {
    next(err);
  }
}