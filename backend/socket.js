const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const conversationService = require("./services/conversation.service");
const Conversation = require("./models/Conversation");
const { User } = require("./models/User");
const pushService = require("./services/push.service");

let io;

// userId (string) -> Set<socketId>  — tracks currently connected users
const onlineUsers = new Map();

async function _pushNewMessage(conversationId, senderId, savedMessage) {
    try {
        const conv = await Conversation.findById(conversationId, "participants").lean();
        if (!conv) return;

        const recipientIds = conv.participants
            .map((id) => id.toString())
            .filter((id) => id !== senderId);

        if (recipientIds.length === 0) return;

        // Skip users who are connected right now — they receive it via socket
        const offlineIds = recipientIds.filter((id) => !onlineUsers.has(id));
        if (offlineIds.length === 0) return;

        const users = await User.find(
            { _id: { $in: offlineIds }, fcmTokens: { $exists: true, $ne: [] } },
            "fcmTokens",
        );
        const tokens = users.flatMap((u) => u.fcmTokens);
        if (tokens.length === 0) return;

        const senderName = savedMessage.sender?.username || "Someone";
        const content = savedMessage.content || "";
        const preview = content.length > 80 ? `${content.substring(0, 80)}…` : content;

        await pushService.sendToTokens(tokens, "new_message", {
            conversationId,
            senderId,
            senderName,
            messagePreview: preview,
        });
    } catch (err) {
        console.error("socket: push for new_message failed:", err.message);
    }
}

exports.init = (httpServer) => {
    io = new Server(httpServer, {
        cors: {
            origin: process.env.NODE_ENV === "production" ? false : "*",
            methods: ["GET", "POST"],
        },
    });

    io.use((socket, next) => {
        const token = socket.handshake.auth?.token;
        if (!token) return next(new Error("unauthorized"));
        try {
            const payload = jwt.verify(token, process.env.JWT_SECRET, { issuer: "hookd" });
            socket.user = payload;
            next();
        } catch {
            next(new Error("unauthorized"));
        }
    });

    io.on("connection", (socket) => {
        const userId = socket.user.sub;

        // Track presence
        if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
        onlineUsers.get(userId).add(socket.id);

        socket.on("disconnect", () => {
            const sockets = onlineUsers.get(userId);
            if (sockets) {
                sockets.delete(socket.id);
                if (sockets.size === 0) onlineUsers.delete(userId);
            }
        });

        socket.on("join_conversation", (conversationId) => {
            socket.join(`conv:${conversationId}`);
        });

        socket.on("leave_conversation", (conversationId) => {
            socket.leave(`conv:${conversationId}`);
        });

        socket.on("send_message", async ({ conversationId, content }, ack) => {
            try {
                if (!conversationId || !content?.trim()) {
                    return ack?.({ error: "conversationId and content are required" });
                }
                const message = await conversationService.saveMessage(
                    conversationId,
                    userId,
                    content.trim(),
                );
                const payload = message.toJSON();
                socket.to(`conv:${conversationId}`).emit("new_message", payload);
                ack?.({ ok: true, message: payload });

                // Push to participants who are offline (fire-and-forget)
                _pushNewMessage(conversationId, userId, message);
            } catch (e) {
                ack?.({ error: e.message });
            }
        });

        socket.on("mark_read", async ({ conversationId }) => {
            try {
                await conversationService.markRead(conversationId, userId);
                socket.to(`conv:${conversationId}`).emit("messages_read", {
                    conversationId,
                    userId,
                });
            } catch {
                // silently ignore
            }
        });

        socket.on("typing", ({ conversationId }) => {
            socket.to(`conv:${conversationId}`).emit("user_typing", {
                conversationId,
                userId,
                username: socket.user.username,
            });
        });

        socket.on("stop_typing", ({ conversationId }) => {
            socket.to(`conv:${conversationId}`).emit("user_stop_typing", {
                conversationId,
                userId,
            });
        });
    });

    return io;
};

exports.getIo = () => {
    if (!io) throw new Error("Socket.IO not initialized");
    return io;
};
