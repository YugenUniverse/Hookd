const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const conversationRoutes = require("../../routes/conversation.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const Conversation = require("../../models/Conversation");
const Message = require("../../models/Message");
const { User, Climber } = require("../../models/User");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/conversations", conversationRoutes);
app.use(errorMiddleware);

const makeToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

describe("conversation.routes", () => {
    let alice, bob, carol;
    let tokenAlice, tokenBob, tokenCarol;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    beforeEach(async () => {
        alice = await Climber.create({ email: "alice@test.com", username: "alice", allowDmsFrom: "everyone" });
        bob = await Climber.create({ email: "bob@test.com", username: "bob", allowDmsFrom: "everyone" });
        carol = await Climber.create({ email: "carol@test.com", username: "carol", allowDmsFrom: "nobody" });
        tokenAlice = makeToken(alice);
        tokenBob = makeToken(bob);
        tokenCarol = makeToken(carol);
    });

    afterEach(async () => {
        await Conversation.deleteMany({});
        await Message.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    describe("GET /conversations", () => {
        it("returns empty list when user has no conversations", async () => {
            const res = await request(app)
                .get("/conversations")
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            expect(res.body.conversations).toEqual([]);
        });

        it("returns conversations the user participates in", async () => {
            await Conversation.create({ type: "dm", participants: [alice._id, bob._id] });
            const res = await request(app)
                .get("/conversations")
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            expect(res.body.conversations).toHaveLength(1);
            expect(res.body.conversations[0].type).toBe("dm");
        });
    });

    describe("POST /conversations/dm/:userId", () => {
        it("creates a DM conversation between two climbers", async () => {
            const res = await request(app)
                .post(`/conversations/dm/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            expect(res.body.conversation.type).toBe("dm");
        });

        it("returns the existing conversation on second call (idempotent)", async () => {
            await request(app)
                .post(`/conversations/dm/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            const res = await request(app)
                .post(`/conversations/dm/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            const count = await Conversation.countDocuments({ type: "dm" });
            expect(count).toBe(1);
        });

        it("returns 403 when target does not accept DMs", async () => {
            const res = await request(app)
                .post(`/conversations/dm/${carol._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(403);
        });

        it("returns 400 when trying to DM yourself", async () => {
            const res = await request(app)
                .post(`/conversations/dm/${alice._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(400);
        });
    });

    describe("POST /conversations/:id/messages", () => {
        let conv;

        beforeEach(async () => {
            conv = await Conversation.create({
                type: "dm",
                participants: [alice._id, bob._id],
            });
        });

        it("sends a message and returns 201", async () => {
            const res = await request(app)
                .post(`/conversations/${conv._id}/messages`)
                .set("Authorization", `Bearer ${tokenAlice}`)
                .send({ content: "Hello Bob!" });
            expect(res.status).toBe(201);
            expect(res.body.message.content).toBe("Hello Bob!");
        });

        it("returns 400 when content is missing", async () => {
            const res = await request(app)
                .post(`/conversations/${conv._id}/messages`)
                .set("Authorization", `Bearer ${tokenAlice}`)
                .send({});
            expect(res.status).toBe(400);
        });

        it("returns 403 when sender is not a participant", async () => {
            const res = await request(app)
                .post(`/conversations/${conv._id}/messages`)
                .set("Authorization", `Bearer ${tokenCarol}`)
                .send({ content: "Intruder!" });
            expect(res.status).toBe(403);
        });
    });

    describe("GET /conversations/:id/messages", () => {
        let conv;

        beforeEach(async () => {
            conv = await Conversation.create({
                type: "dm",
                participants: [alice._id, bob._id],
            });
            await Message.create({ conversation: conv._id, sender: alice._id, content: "Hi" });
            await Message.create({ conversation: conv._id, sender: bob._id, content: "Hey" });
        });

        it("returns messages for a participant", async () => {
            const res = await request(app)
                .get(`/conversations/${conv._id}/messages`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            expect(res.body.messages).toHaveLength(2);
        });

        it("returns 403 for non-participants", async () => {
            const res = await request(app)
                .get(`/conversations/${conv._id}/messages`)
                .set("Authorization", `Bearer ${tokenCarol}`);
            expect(res.status).toBe(403);
        });
    });

    describe("PATCH /conversations/:id/read", () => {
        let conv;

        beforeEach(async () => {
            conv = await Conversation.create({
                type: "dm",
                participants: [alice._id, bob._id],
            });
            await Message.create({
                conversation: conv._id,
                sender: bob._id,
                content: "Read me",
                readBy: [{ user: bob._id }],
            });
        });

        it("marks messages as read for the current user", async () => {
            const res = await request(app)
                .patch(`/conversations/${conv._id}/read`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            expect(res.status).toBe(200);
            const msg = await Message.findOne({ conversation: conv._id });
            const aliceRead = msg.readBy.some((r) => r.user.toString() === alice._id.toString());
            expect(aliceRead).toBe(true);
        });
    });
});
