// routes/auth.routes.js

const router = require('express').Router();

const authController = require('../controllers/auth.controller');
const { authenticateJwt } = require('../middleware/auth.middleware');

router.post('/register', authController.register);

router.post('/login', authController.login);

router.post('/refresh', authController.refresh);

router.post('/logout', authController.logout);

router.get('/me', authenticateJwt, authController.me);

module.exports = router;