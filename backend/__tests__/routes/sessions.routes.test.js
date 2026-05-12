const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const sessionRoutes = require("../../routes/sessions.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const User = require("../../models/User");
const ClimbingSession = require("../../models/ClimbingSession");
const Review = require("../../models/Review");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/sessions", sessionRoutes);
app.use(errorMiddleware);

const createAuthToken = (user) => {
    return jwt.sign(
        {
            sub: user._id.toString(),
            email: user.email,
        },
        process.env.JWT_SECRET,
        {
            expiresIn: "1h",
            issuer: "hookd",
        },
    );
};

describe("sessions.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await ClimbingSession.deleteMany({});
        await Review.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    it("POST /sessions creates a new climber session for the authenticated user", async () => {
        const user = await User.create({
            email: "session@example.com",
            username: "sessionuser",
            userType: "Climber",
            name: "Session",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/sessions")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "2026-05-12",
                time: 90,
            });

        expect(response.status).toBe(201);
        expect(response.body).toEqual({
            session: expect.objectContaining({
                id: expect.any(String),
                climber_id: user._id.toString(),
                wall_id: wallId.toString(),
                time: 90,
            }),
        });

        const stored = await ClimbingSession.findById(response.body.session.id);
        expect(stored).not.toBeNull();
        expect(stored.climber_id.toString()).toBe(user._id.toString());
    });

    it("POST /sessions creates a new climber session with a review when review payload is provided", async () => {
        const user = await User.create({
            email: "sessionreview@example.com",
            username: "sessionreview",
            userType: "Climber",
            name: "Session",
            surname: "Review",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/sessions")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "2026-05-12",
                time: 90,
                review: {
                    rating: 5,
                    body: "Excellent session",
                },
            });

        expect(response.status).toBe(201);
        expect(response.body).toEqual({
            session: expect.objectContaining({
                id: expect.any(String),
                climber_id: user._id.toString(),
                wall_id: wallId.toString(),
                time: 90,
                review_id: expect.any(String),
            }),
            review: expect.objectContaining({
                id: expect.any(String),
                rating: 5,
                body: "Excellent session",
            }),
        });

        const storedReview = await Review.findById(response.body.review.id);
        expect(storedReview).not.toBeNull();
        expect(storedReview.climbing_session_id.toString()).toBe(
            response.body.session.id,
        );
    });

    it("POST /sessions/:sessionId/review adds a review to an existing session", async () => {
        const user = await User.create({
            email: "addreview@example.com",
            username: "addreview",
            userType: "Climber",
            name: "Add",
            surname: "Review",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 75,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .post(`/sessions/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 4, body: "Solid climb" });

        expect(response.status).toBe(201);
        expect(response.body).toEqual({
            session: expect.objectContaining({
                id: session._id.toString(),
                review_id: expect.any(String),
            }),
            review: expect.objectContaining({
                id: expect.any(String),
                rating: 4,
                body: "Solid climb",
            }),
        });

        const updatedSession = await ClimbingSession.findById(session._id);
        expect(updatedSession.review_id).not.toBeNull();
    });

    it("POST /sessions/:sessionId/review returns 409 when the session already has a review", async () => {
        const user = await User.create({
            email: "conflict@example.com",
            username: "conflicter",
            userType: "Climber",
            name: "Conflict",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 55,
        });

        const accessToken = createAuthToken(user);

        await request(app)
            .post(`/sessions/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 4, body: "First review" });

        const conflictResponse = await request(app)
            .post(`/sessions/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 3, body: "Second review" });

        expect(conflictResponse.status).toBe(409);
        expect(conflictResponse.body).toEqual({
            error: "Climbing session already has a review",
        });
    });

    it("GET /sessions returns only sessions belonging to the authenticated user", async () => {
        const user = await User.create({
            email: "owner@example.com",
            username: "owner",
            userType: "Climber",
            name: "Owner",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const otherUser = await User.create({
            email: "other@example.com",
            username: "other",
            userType: "Climber",
            name: "Other",
            surname: "User",
            birthdate: new Date("1991-01-01"),
            authMethods: ["local"],
        });

        const [userSession, otherSession] = await Promise.all([
            ClimbingSession.create({
                climber_id: user._id,
                wall_id: new mongoose.Types.ObjectId(),
                date: new Date("2026-05-12"),
                time: 80,
            }),
            ClimbingSession.create({
                climber_id: otherUser._id,
                wall_id: new mongoose.Types.ObjectId(),
                date: new Date("2026-05-13"),
                time: 100,
            }),
        ]);

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .get("/sessions")
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body.sessions).toHaveLength(1);
        expect(response.body.sessions[0].id).toBe(userSession._id.toString());
    });

    it("GET /sessions/:sessionId returns a specific session for the authenticated user", async () => {
        const user = await User.create({
            email: "single@example.com",
            username: "single",
            userType: "Climber",
            name: "Single",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 120,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .get(`/sessions/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body.session.id).toBe(session._id.toString());
    });

    it("GET /sessions/:sessionId returns 403 if the session belongs to another user", async () => {
        const user = await User.create({
            email: "viewer@example.com",
            username: "viewer",
            userType: "Climber",
            name: "Viewer",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const otherUser = await User.create({
            email: "owner2@example.com",
            username: "owner2",
            userType: "Climber",
            name: "Owner2",
            surname: "User",
            birthdate: new Date("1991-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: otherUser._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 100,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .get(`/sessions/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(403);
        expect(response.body).toEqual({ error: "Forbidden" });
    });

    it("PUT /sessions/:sessionId updates a session for the authenticated user", async () => {
        const user = await User.create({
            email: "update@example.com",
            username: "updater",
            userType: "Climber",
            name: "Update",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 60,
        });

        const newWallId = new mongoose.Types.ObjectId();
        const accessToken = createAuthToken(user);

        const response = await request(app)
            .put(`/sessions/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ wall_id: newWallId.toString(), time: 75 });

        expect(response.status).toBe(200);
        expect(response.body.session.wall_id).toBe(newWallId.toString());
        expect(response.body.session.time).toBe(75);
    });

    it("DELETE /sessions/:sessionId removes a session for the authenticated user", async () => {
        const user = await User.create({
            email: "delete@example.com",
            username: "deleter",
            userType: "Climber",
            name: "Delete",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 45,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .delete(`/sessions/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(204);

        const deleted = await ClimbingSession.findById(session._id);
        expect(deleted).toBeNull();
    });

    it("POST /sessions returns 401 when authentication is missing", async () => {
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app).post("/sessions").send({
            wall_id: wallId.toString(),
            date: "2026-05-12",
            time: 90,
        });

        expect(response.status).toBe(401);
        expect(response.body).toEqual({
            error: "Missing or invalid Authorization header",
        });
    });
});
