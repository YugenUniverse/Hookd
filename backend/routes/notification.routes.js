const express = require("express");
const router = express.Router();
const { authenticateJwt } = require("../middleware/auth.middleware");
const notificationService = require("../services/notification.service");

// All notification routes require authentication
router.use(authenticateJwt);

// Get notifications for the current user
router.get("/", async (req, res, next) => {
    try {
        const { limit, skip } = req.query;
        const notifications = await notificationService.getForUser(req.user.id, {
            limit: limit ? parseInt(limit) : undefined,
            skip: skip ? parseInt(skip) : undefined,
        });
        res.json({ notifications });
    } catch (err) {
        next(err);
    }
});

// Mark a single notification as read
router.patch("/:id/read", async (req, res, next) => {
    try {
        const notification = await notificationService.markRead(req.params.id, req.user.id);
        res.json({ notification });
    } catch (err) {
        next(err);
    }
});

// Mark all notifications as read
router.patch("/read-all", async (req, res, next) => {
    try {
        await notificationService.markAllRead(req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

// Get unread notification count
router.get("/unread-count", async (req, res, next) => {
    try {
        const count = await notificationService.getUnreadCount(req.user.id);
        res.json({ count });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
