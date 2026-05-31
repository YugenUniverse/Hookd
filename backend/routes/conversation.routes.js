const express = require("express");
const router = express.Router();
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");
const conversationService = require("../services/conversation.service");
const Conversation = require("../models/Conversation");
const PlannedClimb = require("../models/PlannedClimb");

router.use(authenticateJwt);

// List all conversations for the current user
router.get("/", async (req, res, next) => {
    try {
        const conversations = await conversationService.getConversationsForUser(req.user.id);
        res.json({ conversations });
    } catch (err) {
        next(err);
    }
});

// Get or create a DM conversation with another user (Climber only)
router.post("/dm/:userId", restrictTo("Climber"), async (req, res, next) => {
    try {
        await conversationService.checkDmPermission(req.user.id, req.params.userId);
        const conversation = await conversationService.getOrCreateDm(
            req.user.id,
            req.params.userId,
        );
        res.json({ conversation });
    } catch (err) {
        if (err.statusCode) return res.status(err.statusCode).json({ error: err.message });
        next(err);
    }
});

// Get (or lazily create) the conversation for a specific group
router.get("/group/:groupId", async (req, res, next) => {
    try {
        let conv = await Conversation.findOne({ group: req.params.groupId })
            .populate("participants", "username avatar")
            .populate("group", "name")
            .populate({ path: "lastMessage", populate: { path: "sender", select: "username" } });

        if (!conv) {
            // Group existed before the chat feature — create the conversation lazily
            const Group = require("../models/Group");
            const group = await Group.findById(req.params.groupId);
            if (!group) return res.status(404).json({ error: "Group not found" });
            const isMember = group.members.some((m) => m.user.toString() === req.user.id);
            if (!isMember) return res.status(403).json({ error: "Forbidden" });
            await conversationService.createGroupConversation(
                req.params.groupId,
                group.members.map((m) => m.user),
            );
            // Re-fetch with full population so the client gets the same shape
            conv = await Conversation.findOne({ group: req.params.groupId })
                .populate("participants", "username avatar")
                .populate("group", "name")
                .populate({ path: "lastMessage", populate: { path: "sender", select: "username" } });
        } else {
            const isMember = conv.participants.some(
                (p) => p._id.toString() === req.user.id || p.toString() === req.user.id,
            );
            if (!isMember) return res.status(403).json({ error: "Forbidden" });
        }

        const hasUpcomingEvent = !!(await PlannedClimb.exists({
            group: req.params.groupId,
            date: { $gte: new Date() },
        }));
        res.json({ conversation: { ...conv.toJSON(), hasUpcomingEvent } });
    } catch (err) {
        next(err);
    }
});

// Get messages for a conversation (paginated via ?before=<ISO date>)
router.get("/:id/messages", async (req, res, next) => {
    try {
        const messages = await conversationService.getMessages(
            req.params.id,
            req.user.id,
            { before: req.query.before, limit: Number(req.query.limit) || 30 },
        );
        res.json({ messages });
    } catch (err) {
        if (err.statusCode) return res.status(err.statusCode).json({ error: err.message });
        next(err);
    }
});

// Send a message via REST (alternative to Socket.IO)
router.post("/:id/messages", async (req, res, next) => {
    try {
        const { content } = req.body;
        if (!content?.trim()) {
            return res.status(400).json({ error: "content is required" });
        }
        const message = await conversationService.saveMessage(
            req.params.id,
            req.user.id,
            content.trim(),
        );

        // Broadcast to others in the room (sender already has the message from the REST response)
        try {
            const { getIo } = require("../socket");
            const io = getIo();
            const room = `conv:${req.params.id}`;
            const senderId = req.user.id;
            const sockets = await io.in(room).fetchSockets();
            const payload = message.toJSON();
            for (const s of sockets) {
                if (s.user?.sub !== senderId) s.emit("new_message", payload);
            }
        } catch {
            // Socket.IO not initialized in test environment — ignore
        }

        res.status(201).json({ message });
    } catch (err) {
        if (err.statusCode) return res.status(err.statusCode).json({ error: err.message });
        next(err);
    }
});

// Mark all messages in a conversation as read
router.patch("/:id/read", async (req, res, next) => {
    try {
        await conversationService.markRead(req.params.id, req.user.id);
        res.json({ ok: true });
    } catch (err) {
        if (err.statusCode) return res.status(err.statusCode).json({ error: err.message });
        next(err);
    }
});

module.exports = router;
