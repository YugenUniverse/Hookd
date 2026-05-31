const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const eventRoutes = require("../../routes/event.routes");
const notificationRoutes = require("../../routes/notification.routes");
const followRoutes = require("../../routes/follow.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Climber, FacilityOwner, User } = require("../../models/User");
const Facility = require("../../models/Facility");
const Event = require("../../models/Event");
const Notification = require("../../models/Notification");
const Follow = require("../../models/Follow");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/events", eventRoutes);
app.use("/notifications", notificationRoutes);
app.use("/follows", followRoutes);
app.use(errorMiddleware);

const createAuthToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

describe("event & notification routes", () => {
    let facility, owner, ownerToken, climber, climberToken;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });

        facility = await Facility.create({
            name: "Test Gym",
            description: "A test gym",
            location: { type: "Point", coordinates: [11.1, 46.1] },
        });

        owner = await FacilityOwner.create({
            email: "owner@gym.com",
            username: "gymOwner",
            userType: "FacilityOwner",
            facility: facility._id,
            password: "Secret123!",
        });
        facility.ownerAccount = owner._id;
        await facility.save();

        ownerToken = createAuthToken(owner);

        climber = await Climber.create({
            email: "climber@test.com",
            username: "testClimber",
            userType: "Climber",
            password: "Secret123!",
        });
        climberToken = createAuthToken(climber);
    });

    afterEach(async () => {
        await Event.deleteMany({});
        await Notification.deleteMany({});
        await Follow.deleteMany({});
    });

    afterAll(async () => {
        await User.deleteMany({});
        await Facility.deleteMany({});
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    // --- Events ---

    it("POST /events requires authentication", async () => {
        const res = await request(app).post("/events").send({ title: "Test" });
        expect(res.status).toBe(401);
    });

    it("POST /events returns 403 for Climbers", async () => {
        const res = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${climberToken}`)
            .send({ title: "Comp", startDate: new Date().toISOString() });
        expect(res.status).toBe(403);
    });

    it("POST /events creates an event for a FacilityOwner", async () => {
        const startDate = new Date("2026-07-01").toISOString();
        const res = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send({ title: "Summer Comp", description: "Fun competition", startDate });

        expect(res.status).toBe(201);
        expect(res.body.event).toMatchObject({
            title: "Summer Comp",
            description: "Fun competition",
        });
        expect(res.body.event.facility).toBe(facility._id.toString());
    });

    it("POST /events returns 400 when title is missing", async () => {
        const res = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send({ startDate: new Date().toISOString() });
        expect(res.status).toBe(400);
    });

    it("POST /events returns 403 when FacilityOwner has no linked facility", async () => {
        const unlinkedOwner = await FacilityOwner.create({
            email: "unlinked@gym.com",
            username: "unlinkedOwner",
            userType: "FacilityOwner",
            password: "Secret123!",
        });
        const token = createAuthToken(unlinkedOwner);
        const res = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${token}`)
            .send({ title: "Event", startDate: new Date().toISOString() });
        expect(res.status).toBe(403);
    });

    it("GET /events returns events for a facility", async () => {
        await Event.create({
            title: "Event A",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .get(`/events?facilityId=${facility._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(res.body.events).toHaveLength(1);
        expect(res.body.events[0].title).toBe("Event A");
    });

    it("GET /events returns 400 without facilityId", async () => {
        const res = await request(app)
            .get("/events")
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(400);
    });

    it("GET /events/:id returns a single event", async () => {
        const event = await Event.create({
            title: "Single Event",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-08-01"),
        });
        const res = await request(app)
            .get(`/events/${event._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(res.body.event.title).toBe("Single Event");
    });

    it("PATCH /events/:id updates an event for its creator", async () => {
        const event = await Event.create({
            title: "Original",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .patch(`/events/${event._id}`)
            .set("Authorization", `Bearer ${ownerToken}`)
            .send({ title: "Updated Title", description: "New desc" });
        expect(res.status).toBe(200);
        expect(res.body.event.title).toBe("Updated Title");
        expect(res.body.event.description).toBe("New desc");
    });

    it("PATCH /events/:id returns 403 for a different owner", async () => {
        const other = await FacilityOwner.create({
            email: "other@gym.com",
            username: "otherOwner",
            userType: "FacilityOwner",
            password: "Secret123!",
        });
        const event = await Event.create({
            title: "Mine",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .patch(`/events/${event._id}`)
            .set("Authorization", `Bearer ${createAuthToken(other)}`)
            .send({ title: "Stolen" });
        expect(res.status).toBe(403);
    });

    it("PATCH /events/:id returns 403 for Climbers", async () => {
        const event = await Event.create({
            title: "Mine",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .patch(`/events/${event._id}`)
            .set("Authorization", `Bearer ${climberToken}`)
            .send({ title: "Stolen" });
        expect(res.status).toBe(403);
    });

    it("DELETE /events/:id deletes the event for its creator", async () => {
        const event = await Event.create({
            title: "To Delete",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-09-01"),
        });
        const res = await request(app)
            .delete(`/events/${event._id}`)
            .set("Authorization", `Bearer ${ownerToken}`);
        expect(res.status).toBe(204);
        expect(await Event.findById(event._id)).toBeNull();
    });

    it("DELETE /events/:id returns 403 for a different owner", async () => {
        const other = await FacilityOwner.create({
            email: "other2@gym.com",
            username: "otherOwner2",
            userType: "FacilityOwner",
            password: "Secret123!",
        });
        const event = await Event.create({
            title: "Mine",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .delete(`/events/${event._id}`)
            .set("Authorization", `Bearer ${createAuthToken(other)}`);
        expect(res.status).toBe(403);
    });

    it("DELETE /events/:id returns 403 for Climbers", async () => {
        const event = await Event.create({
            title: "Mine",
            facility: facility._id,
            createdBy: owner._id,
            startDate: new Date("2026-07-01"),
        });
        const res = await request(app)
            .delete(`/events/${event._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(403);
    });

    it("GET /events/:id returns 404 for a non-existent event", async () => {
        const fakeId = new mongoose.Types.ObjectId();
        const res = await request(app)
            .get(`/events/${fakeId}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(404);
    });

    // --- Follows ---

    it("POST /follows/:targetId follows a user", async () => {
        const res = await request(app)
            .post(`/follows/${owner._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(await Follow.exists({ follower: climber._id, following: owner._id })).toBeTruthy();
    });

    it("POST /follows/:targetId is idempotent", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        const res = await request(app)
            .post(`/follows/${owner._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(await Follow.countDocuments({ follower: climber._id, following: owner._id })).toBe(1);
    });

    it("POST /follows/:targetId returns 400 when following yourself", async () => {
        const res = await request(app)
            .post(`/follows/${climber._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(400);
    });

    it("DELETE /follows/:targetId unfollows a user", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        const res = await request(app)
            .delete(`/follows/${owner._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(await Follow.exists({ follower: climber._id, following: owner._id })).toBeFalsy();
    });

    it("GET /follows/me returns the list of followed users", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        const res = await request(app)
            .get("/follows/me")
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(res.body.following).toHaveLength(1);
        expect(res.body.following[0].id).toBe(owner._id.toString());
    });

    it("GET /follows/check/:targetId returns following status", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        const yes = await request(app)
            .get(`/follows/check/${owner._id}`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(yes.body.following).toBe(true);

        const no = await request(app)
            .get(`/follows/check/${climber._id}`)
            .set("Authorization", `Bearer ${ownerToken}`);
        expect(no.body.following).toBe(false);
    });

    // --- Notifications ---

    it("POST /events creates notifications for followers of the owner", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send({ title: "Notify Me", startDate: new Date("2026-10-01").toISOString() });

        const notifications = await Notification.find({ recipient: climber._id });
        expect(notifications).toHaveLength(1);
        expect(notifications[0].type).toBe("new_event");
        expect(notifications[0].payload.eventTitle).toBe("Notify Me");
    });

    it("POST /events does not create notifications for non-followers", async () => {
        await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send({ title: "No Notify", startDate: new Date("2026-10-01").toISOString() });

        const notifications = await Notification.find({ recipient: climber._id });
        expect(notifications).toHaveLength(0);
    });

    it("GET /notifications returns notifications for the current user", async () => {
        await Notification.create({
            recipient: climber._id,
            type: "new_event",
            payload: { eventTitle: "Test" },
        });
        const res = await request(app)
            .get("/notifications")
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(res.body.notifications).toHaveLength(1);
        expect(res.body.notifications[0].read).toBe(false);
    });

    it("PATCH /notifications/:id/read marks a notification as read", async () => {
        const notif = await Notification.create({
            recipient: climber._id,
            type: "new_event",
            payload: {},
        });
        const res = await request(app)
            .patch(`/notifications/${notif._id}/read`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(200);
        expect(res.body.notification.read).toBe(true);
    });

    it("PATCH /notifications/:id/read returns 403 for wrong user", async () => {
        const other = await Climber.create({
            email: "other@test.com",
            username: "other",
            userType: "Climber",
            password: "Secret123!",
        });
        const notif = await Notification.create({
            recipient: other._id,
            type: "new_event",
            payload: {},
        });
        const res = await request(app)
            .patch(`/notifications/${notif._id}/read`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(403);
    });

    it("PATCH /notifications/read-all marks all notifications as read", async () => {
        await Notification.insertMany([
            { recipient: climber._id, type: "new_event", payload: { eventTitle: "A" } },
            { recipient: climber._id, type: "new_event", payload: { eventTitle: "B" } },
        ]);
        const res = await request(app)
            .patch("/notifications/read-all")
            .set("Authorization", `Bearer ${climberToken}`);
        expect(res.status).toBe(204);
        const remaining = await Notification.find({ recipient: climber._id, read: false });
        expect(remaining).toHaveLength(0);
    });

    // --- Followers ---

    it("GET /follows/:userId/followers returns followers of a user", async () => {
        await Follow.create({ follower: climber._id, following: owner._id });
        const res = await request(app)
            .get(`/follows/${owner._id}/followers`)
            .set("Authorization", `Bearer ${ownerToken}`);
        expect(res.status).toBe(200);
        expect(res.body.followers).toHaveLength(1);
        expect(res.body.followers[0].id).toBe(climber._id.toString());
    });

    it("GET /follows/:userId/followers returns empty array for a user with no followers", async () => {
        const response = await request(app)
            .get(`/follows/${climber._id}/followers`)
            .set("Authorization", `Bearer ${climberToken}`);
        expect(response.status).toBe(200);
        expect(response.body.followers).toHaveLength(0);
    });

    it("POST /events/:id/close closes an event and distributes badges", async () => {
        const payload = {
            title: "Closing Event",
            description: "An event to be closed",
            startDate: new Date(),
            endDate: new Date(Date.now() + 86400000), // tomorrow
        };

        const createRes = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send(payload);

        const eventId = createRes.body.event.id;

        const closeRes = await request(app)
            .post(`/events/${eventId}/close`)
            .set("Authorization", `Bearer ${ownerToken}`);

        expect(closeRes.status).toBe(200);
        expect(closeRes.body.message).toBe("Event closed and badges distributed successfully");
        expect(closeRes.body.event.status).toBe("closed");
    });

    it("POST /events/:id/close returns 400 if already closed", async () => {
        const payload = {
            title: "Already Closed Event",
            description: "An event",
            startDate: new Date(),
        };

        const createRes = await request(app)
            .post("/events")
            .set("Authorization", `Bearer ${ownerToken}`)
            .send(payload);

        const eventId = createRes.body.event.id;

        await request(app)
            .post(`/events/${eventId}/close`)
            .set("Authorization", `Bearer ${ownerToken}`);

        const duplicateCloseRes = await request(app)
            .post(`/events/${eventId}/close`)
            .set("Authorization", `Bearer ${ownerToken}`);

        expect(duplicateCloseRes.status).toBe(400);
    });
});
