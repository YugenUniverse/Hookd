const mongoose = require("mongoose");
const Notification = require("../models/Notification");

exports.createBulk = async (recipientIds, type, payload) => {
    if (!recipientIds.length) return;
    const docs = recipientIds.map((id) => ({ recipient: id, type, payload }));
    await Notification.insertMany(docs);
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
