const express = require("express");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const request = require("supertest");

const badgeRoutes = require("../../routes/badge.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const Badge = require("../../models/Badge");
const Event = require("../../models/Event");
const { User, FacilityOwner, PublicBody, Climber } = require("../../models/User");

const app = express();
app.use(express.json());
app.use("/badges", badgeRoutes);
app.use(errorMiddleware);

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const createAuthToken = (user, type) => {
    return jwt.sign(
        {
            sub: user._id.toString(),
            email: user.email,
            userType: type || user.userType,
        },
        process.env.JWT_SECRET,
        {
            expiresIn: "1h",
            issuer: "hookd",
        },
    );
};

describe("badge.routes", () => {
    let facilityOwner;
    let facilityOwnerToken;
    let climber;
    let climberToken;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});

        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });

        facilityOwner = await FacilityOwner.create({
            email: "owner@example.com",
            username: "facilityOwner",
            password: "Password123!",
            userType: "FacilityOwner",
        });
        facilityOwnerToken = createAuthToken(facilityOwner, "FacilityOwner");

        climber = await Climber.create({
            email: "climber@example.com",
            username: "climberUser",
            password: "Password123!",
            userType: "Climber",
        });
        climberToken = createAuthToken(climber, "Climber");

        testEvent = await Event.create({
            title: "Test Event",
            description: "A test event",
            facility: new mongoose.Types.ObjectId(),
            createdBy: facilityOwner._id,
            startDate: new Date(),
        });
    });

    afterEach(async () => {
        await Badge.deleteMany({});
    });

    afterAll(async () => {
        await User.deleteMany({});
        await Event.deleteMany({});
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    it("POST /badges creates a new badge if authenticated as FacilityOwner", async () => {
        const payload = {
            name: "Test Badge",
            description: "A test badge",
            score: 50,
            type: "event",
            eventId: testEvent._id.toString(),
            winningCondition: {
                metric: "rank",
                operator: "top",
                value: 3
            },
            level: 3
        };

        const response = await request(app)
            .post("/badges")
            .set("Authorization", `Bearer ${facilityOwnerToken}`)
            .send(payload);

        expect(response.status).toBe(201);
        expect(response.body.name).toBe("Test Badge");
        expect(response.body.score).toBe(50);
        expect(response.body.createdBy).toBe(facilityOwner._id.toString());
    });

    it("POST /badges denies creation if authenticated as Climber for system badge", async () => {
        const payload = { name: "Test Badge" };

        const response = await request(app)
            .post("/badges")
            .set("Authorization", `Bearer ${climberToken}`)
            .send(payload);

        expect(response.status).toBe(403);
    });

    it("POST /badges allows creation if authenticated as Climber who is group admin", async () => {
        const Group = require("../../models/Group");
        const group = await Group.create({
            name: "My Group",
            creator: climber._id,
            members: [{ user: climber._id, role: "admin" }],
        });

        const groupEvent = await Event.create({
            title: "Group Event",
            groupId: group._id,
            createdBy: climber._id,
            startDate: new Date(),
            isGlobal: false
        });

        const payload = {
            name: "Group Event Badge",
            description: "A test badge",
            score: 50,
            type: "event",
            eventId: groupEvent._id.toString(),
            winningCondition: {
                metric: "rank",
                operator: "top",
                value: 3
            },
            level: 3
        };

        const response = await request(app)
            .post("/badges")
            .set("Authorization", `Bearer ${climberToken}`)
            .send(payload);

        expect(response.status).toBe(201);
        expect(response.body.name).toBe("Group Event Badge");
    });

    it("GET /badges retrieves all badges", async () => {
        await Badge.create({ name: "Badge 1" });
        await Badge.create({ name: "Badge 2" });

        const response = await request(app).get("/badges");

        expect(response.status).toBe(200);
        expect(response.body).toHaveLength(2);
    });

    it("GET /badges/:id retrieves a specific badge", async () => {
        const badge = await Badge.create({ name: "Specific Badge" });

        const response = await request(app).get(`/badges/${badge._id}`);

        expect(response.status).toBe(200);
        expect(response.body.name).toBe("Specific Badge");
    });

    it("PUT /badges/:id updates a badge if authorized", async () => {
        const badge = await Badge.create({ 
            name: "Old Name", 
            type: "event", 
            eventId: testEvent._id,
            winningCondition: { metric: "rank", operator: "top", value: 3 },
            createdBy: facilityOwner._id 
        });

        const response = await request(app)
            .put(`/badges/${badge._id}`)
            .set("Authorization", `Bearer ${facilityOwnerToken}`)
            .send({ name: "New Name", score: 100 });

        expect(response.status).toBe(200);
        expect(response.body.name).toBe("New Name");
        expect(response.body.score).toBe(100);
    });

    it("DELETE /badges/:id deletes a badge if authorized", async () => {
        const badge = await Badge.create({ 
            name: "To Delete", 
            type: "event", 
            eventId: testEvent._id,
            winningCondition: { metric: "rank", operator: "top", value: 3 },
            createdBy: facilityOwner._id 
        });

        const response = await request(app)
            .delete(`/badges/${badge._id}`)
            .set("Authorization", `Bearer ${facilityOwnerToken}`);

        expect(response.status).toBe(200);

        const checkBadge = await Badge.findById(badge._id);
        expect(checkBadge).toBeNull();
    });
});
