const mongoose = require("mongoose");
const Notification = require("../models/Notification");
const { User } = require("../models/User");
const pushService = require("./push.service");

exports.createBulk = async (recipientIds, type, payload) => {
    if (!recipientIds.length) return;
    const docs = recipientIds.map((id) => ({ recipient: id, type, payload }));
    await Notification.insertMany(docs);

    // Fire push notifications — fire-and-forget, never block the caller
    User.find({ _id: { $in: recipientIds }, fcmTokens: { $exists: true, $ne: [] } }, "fcmTokens")
        .then((users) => {
            const tokens = users.flatMap((u) => u.fcmTokens);
            if (tokens.length) return pushService.sendToTokens(tokens, type, payload);
        })
        .catch((err) => console.error("notification.service: push delivery error:", err.message));
};

exports.getForUser = async (userId, { limit = 50, skip = 0 } = {}) => {
    return Notification.find({ recipient: userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);
};

exports.markRead = async (notificationId, userId) => {
    const notification = await Notification.findById(notificationId);
    if (!notification) {
        const err = new Error("Notification not found");
        err.statusCode = 404;
        throw err;
    }
    if (notification.recipient.toString() !== userId.toString()) {
        const err = new Error("Forbidden");
        err.statusCode = 403;
        throw err;
    }
    notification.read = true;
    return notification.save();
};

exports.markAllRead = async (userId) => {
    await Notification.updateMany({ recipient: userId, read: false }, { read: true });
};

exports.getUnreadCount = async (userId) => {
    const count = await Notification.countDocuments({
        recipient: userId,
        read: false,
    });
    return count;
};
