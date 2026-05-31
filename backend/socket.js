const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const conversationService = require("./services/conversation.service");

let io;

exports.init = (httpServer) => {
    io = new Server(httpServer, {
        cors: {
            origin: process.env.NODE_ENV === "production" ? false : "*",
            methods: ["GET", "POST"],
        },
    });

    // Authenticate every socket connection via the JWT passed in handshake.auth.token
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

        // Client joins a conversation room to receive messages
        socket.on("join_conversation", (conversationId) => {
            socket.join(`conv:${conversationId}`);
        });

        socket.on("leave_conversation", (conversationId) => {
            socket.leave(`conv:${conversationId}`);
        });

        // Send a message via socket
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
                // Broadcast to everyone in the room except the sender.
                // The sender already gets the message via the ack callback.
                socket.to(`conv:${conversationId}`).emit("new_message", payload);
                ack?.({ ok: true, message: payload });
            } catch (e) {
                ack?.({ error: e.message });
            }
        });

        // Mark conversation as read
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

        // Typing indicators
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
