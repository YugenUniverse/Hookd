const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const { Climber } = require("../models/User");
const Follow = require("../models/Follow");
const PlannedClimb = require("../models/PlannedClimb");
require("../models/Group"); // ensure Group schema is registered for population

const err = (msg, code) => Object.assign(new Error(msg), { statusCode: code });

// Check whether requesterId is allowed to DM targetId based on target's privacy setting
exports.checkDmPermission = async (requesterId, targetId) => {
    if (requesterId.toString() === targetId.toString()) {
        throw err("Cannot DM yourself", 400);
    }
    const target = await Climber.findById(targetId, "allowDmsFrom");
    if (!target) throw err("User not found", 404);

    if (target.allowDmsFrom === "nobody") throw err("This user does not accept DMs", 403);

    if (target.allowDmsFrom === "followers") {
        const follows = await Follow.exists({ follower: targetId, following: requesterId });
        if (!follows) throw err("This user only accepts DMs from people they follow", 403);
    }
};

// Get or create the DM conversation between two users
exports.getOrCreateDm = async (userId, targetId) => {
    const existing = await Conversation.findOne({
        type: "dm",
        participants: { $all: [userId, targetId], $size: 2 },
    })
        .populate("lastMessage")
        .populate("participants", "username avatar");

    if (existing) return existing;

    return Conversation.create({ type: "dm", participants: [userId, targetId] });
};

// Create the group conversation (called when a group is created)
exports.createGroupConversation = async (groupId, memberIds) => {
    return Conversation.create({
        type: "group",
        group: groupId,
        participants: memberIds,
    });
};

// Add a participant to a group conversation
exports.addParticipant = async (groupId, userId) => {
    await Conversation.updateOne(
        { group: groupId },
        { $addToSet: { participants: userId } },
    );
};

// Remove a participant from a group conversation
exports.removeParticipant = async (groupId, userId) => {
    await Conversation.updateOne(
        { group: groupId },
        { $pull: { participants: userId } },
    );
};

// Delete group conversation and all its messages
exports.deleteGroupConversation = async (groupId) => {
    const conv = await Conversation.findOne({ group: groupId });
    if (!conv) return;
    await Message.deleteMany({ conversation: conv._id });
    await conv.deleteOne();
};

// List all conversations for a user (DMs + groups), sorted by latest activity
exports.getConversationsForUser = async (userId) => {
    const conversations = await Conversation.find({ participants: userId })
        .populate("participants", "username avatar")
        .populate("group", "name")
        .populate({
            path: "lastMessage",
            populate: { path: "sender", select: "username" },
        })
        .sort({ lastActivity: -1 })
        .limit(50);

    // Collect group IDs to check for upcoming planned climbs in one query
    const groupIds = conversations
        .filter((c) => c.type === "group" && c.group)
        .map((c) => c.group._id ?? c.group);

    const now = new Date();
    const upcomingGroupIds = new Set(
        groupIds.length > 0
            ? (await PlannedClimb.distinct("group", {
                  group: { $in: groupIds },
                  date: { $gte: now },
              })).map((id) => id.toString())
            : [],
    );

    return conversations.map((c) => {
        const unread = c.lastMessage
            ? !c.lastMessage.readBy.some((r) => r.user.toString() === userId.toString())
            : false;
        const groupId = c.group ? (c.group._id ?? c.group).toString() : null;
        const hasUpcomingEvent = groupId ? upcomingGroupIds.has(groupId) : false;
        return { ...c.toJSON(), hasUnread: unread, hasUpcomingEvent };
    });
};

// Get messages for a conversation (cursor-based pagination, newest first)
exports.getMessages = async (conversationId, userId, { limit = 30, before } = {}) => {
    const conv = await Conversation.findById(conversationId);
    if (!conv) throw err("Conversation not found", 404);
    if (!conv.participants.some((p) => p.toString() === userId.toString())) {
        throw err("Forbidden", 403);
    }

    const query = { conversation: conversationId };
    if (before) query.createdAt = { $lt: new Date(before) };

    const messages = await Message.find(query)
        .populate("sender", "username avatar")
        .sort({ createdAt: -1 })
        .limit(limit);

    return messages.reverse();
};

// Save a message to DB and update conversation lastMessage/lastActivity
exports.saveMessage = async (conversationId, senderId, content) => {
    const conv = await Conversation.findById(conversationId);
    if (!conv) throw err("Conversation not found", 404);
    if (!conv.participants.some((p) => p.toString() === senderId.toString())) {
        throw err("Forbidden", 403);
    }

    const message = await Message.create({
        conversation: conversationId,
        sender: senderId,
        content,
        readBy: [{ user: senderId, readAt: new Date() }],
    });

    await Message.populate(message, { path: "sender", select: "username avatar" });

    conv.lastMessage = message._id;
    conv.lastActivity = new Date();
    await conv.save();

    return message;
};

// Mark all unread messages in a conversation as read for userId
exports.markRead = async (conversationId, userId) => {
    await Message.updateMany(
        {
            conversation: conversationId,
            "readBy.user": { $ne: userId },
        },
        { $push: { readBy: { user: userId, readAt: new Date() } } },
    );
};

exports.assertMember = async (conversationId, userId) => {
    const conv = await Conversation.findById(conversationId, "participants");
    if (!conv) throw err("Conversation not found", 404);
    if (!conv.participants.some((p) => p.toString() === userId.toString())) {
        throw err("Forbidden", 403);
    }
    return conv;
};
