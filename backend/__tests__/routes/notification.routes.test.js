const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const notificationRoutes = require("../../routes/notification.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User, Climber } = require("../../models/User");
const Notification = require("../../models/Notification");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/notifications", notificationRoutes);
app.use(errorMiddleware);

const makeToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

describe("notification.routes", () => {
    let alice, bob;
    let tokenAlice, tokenBob;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    beforeEach(async () => {
        alice = await Climber.create({ email: "alice@test.com", username: "alice" });
        bob = await Climber.create({ email: "bob@test.com", username: "bob" });
        tokenAlice = makeToken(alice);
        tokenBob = makeToken(bob);
    });

    afterEach(async () => {
        await Notification.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    describe("GET /notifications", () => {
        it("returns empty array when user has no notifications", async () => {
            const res = await request(app)
                .get("/notifications")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.notifications).toEqual([]);
        });

        it("returns only the current user's notifications", async () => {
            await Notification.create({ recipient: alice._id, type: "new_follower", payload: {} });
            await Notification.create({ recipient: bob._id, type: "new_event", payload: {} });

            const res = await request(app)
                .get("/notifications")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.notifications).toHaveLength(1);
            expect(res.body.notifications[0].type).toBe("new_follower");
        });

        it("returns notifications newest first", async () => {
            const t = Date.now();
            await Notification.create({ recipient: alice._id, type: "new_follower", payload: {}, createdAt: new Date(t) });
            await Notification.create({ recipient: alice._id, type: "new_event", payload: {}, createdAt: new Date(t + 1000) });

            const res = await request(app)
                .get("/notifications")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.notifications[0].type).toBe("new_event");
        });

        it("respects limit query param", async () => {
            for (let i = 0; i < 5; i++) {
                await Notification.create({ recipient: alice._id, type: "new_follower", payload: {} });
            }

            const res = await request(app)
                .get("/notifications?limit=2")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.notifications).toHaveLength(2);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get("/notifications");
            expect(res.status).toBe(401);
        });
    });

    describe("PATCH /notifications/:id/read", () => {
        it("marks a notification as read and returns 200", async () => {
            const notif = await Notification.create({
                recipient: alice._id,
                type: "new_follower",
                payload: {},
                read: false,
            });

            const res = await request(app)
                .patch(`/notifications/${notif._id}/read`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.notification.read).toBe(true);

            const updated = await Notification.findById(notif._id);
            expect(updated.read).toBe(true);
        });

        it("returns 403 when another user tries to mark it read", async () => {
            const notif = await Notification.create({
                recipient: alice._id,
                type: "new_follower",
                payload: {},
            });

            const res = await request(app)
                .patch(`/notifications/${notif._id}/read`)
                .set("Authorization", `Bearer ${tokenBob}`);

            expect(res.status).toBe(403);
        });

        it("returns 404 for a non-existent notification id", async () => {
            const fakeId = new mongoose.Types.ObjectId();
            const res = await request(app)
                .patch(`/notifications/${fakeId}/read`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(404);
        });

        it("returns 401 without a JWT", async () => {
            const notif = await Notification.create({
                recipient: alice._id,
                type: "new_follower",
                payload: {},
            });

            const res = await request(app).patch(`/notifications/${notif._id}/read`);
            expect(res.status).toBe(401);
        });
    });

    describe("PATCH /notifications/read-all", () => {
        it("marks all notifications as read and returns 204", async () => {
            await Notification.create({ recipient: alice._id, type: "new_follower", payload: {}, read: false });
            await Notification.create({ recipient: alice._id, type: "new_event", payload: {}, read: false });
            // Bob's notification should not be affected
            await Notification.create({ recipient: bob._id, type: "new_follower", payload: {}, read: false });

            const res = await request(app)
                .patch("/notifications/read-all")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(204);

            const aliceUnread = await Notification.countDocuments({ recipient: alice._id, read: false });
            expect(aliceUnread).toBe(0);
            const bobUnread = await Notification.countDocuments({ recipient: bob._id, read: false });
            expect(bobUnread).toBe(1);
        });

        it("returns 204 even when there are no unread notifications", async () => {
            const res = await request(app)
                .patch("/notifications/read-all")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(204);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).patch("/notifications/read-all");
            expect(res.status).toBe(401);
        });
    });

    describe("GET /notifications/unread-count", () => {
        it("returns the correct unread count", async () => {
            await Notification.create({ recipient: alice._id, type: "new_follower", payload: {}, read: false });
            await Notification.create({ recipient: alice._id, type: "new_event", payload: {}, read: false });
            await Notification.create({ recipient: alice._id, type: "badge_awarded", payload: {}, read: true });

            const res = await request(app)
                .get("/notifications/unread-count")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.count).toBe(2);
        });

        it("returns 0 when all notifications are read", async () => {
            await Notification.create({ recipient: alice._id, type: "new_follower", payload: {}, read: true });

            const res = await request(app)
                .get("/notifications/unread-count")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.count).toBe(0);
        });

        it("returns 0 when user has no notifications", async () => {
            const res = await request(app)
                .get("/notifications/unread-count")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.count).toBe(0);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get("/notifications/unread-count");
            expect(res.status).toBe(401);
        });
    });
});
