const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const sessionRoutes = require("../../routes/session.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User } = require("../../models/User");
const ClimbingSession = require("../../models/ClimbingSession");
const Review = require("../../models/Review");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/session", sessionRoutes);
app.use(errorMiddleware);

const createAuthToken = (user) => {
    return jwt.sign(
        {
            sub: user._id.toString(),
            email: user.email,
            userType: user.userType,
        },
        process.env.JWT_SECRET,
        {
            expiresIn: "1h",
            issuer: "hookd",
        },
    );
};

describe("session.routes", () => {
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

    it("POST /session creates a new climber session for the authenticated user", async () => {
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
            .post("/session")
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

    it("POST /session creates a new climber session with a review when review payload is provided", async () => {
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
            .post("/session")
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

    it("POST /session/:sessionId/review adds a review to an existing session", async () => {
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
            .post(`/session/${session._id.toString()}/review`)
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

    it("POST /session/:sessionId/review returns 409 when the session already has a review", async () => {
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
            .post(`/session/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 4, body: "First review" });

        const conflictResponse = await request(app)
            .post(`/session/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 3, body: "Second review" });

        expect(conflictResponse.status).toBe(409);
        expect(conflictResponse.body).toEqual({
            error: "Climbing session already has a review",
        });
    });

    it("GET /session returns only sessions belonging to the authenticated user", async () => {
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
            .get("/session")
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body.sessions).toHaveLength(1);
        expect(response.body.sessions[0].id).toBe(userSession._id.toString());
    });

    it("GET /session/:sessionId returns a specific session for the authenticated user", async () => {
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
            .get(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body.session.id).toBe(session._id.toString());
    });

    it("GET /session/:sessionId returns 403 if the session belongs to another user", async () => {
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
            .get(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(403);
        expect(response.body.error).toContain("do not own this session");
    });

    it("PUT /session/:sessionId updates a session for the authenticated user", async () => {
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
            .put(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ wall_id: newWallId.toString(), time: 75 });

        expect(response.status).toBe(200);
        expect(response.body.session.wall_id).toBe(newWallId.toString());
        expect(response.body.session.time).toBe(75);
    });

    it("DELETE /session/:sessionId removes a session for the authenticated user", async () => {
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
            .delete(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(204);

        const deleted = await ClimbingSession.findById(session._id);
        expect(deleted).toBeNull();
    });

    it("POST /session returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber@example.com",
            username: "nonclimber",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "2026-05-12",
                time: 90,
            });

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can create climbing sessions",
        });
    });

    it("POST /session returns 400 when wall_id is missing", async () => {
        const user = await User.create({
            email: "validation@example.com",
            username: "validation",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                date: "2026-05-12",
                time: 90,
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "wall_id, date, and time are required",
        });
    });

    it("POST /session returns 400 when date is missing", async () => {
        const user = await User.create({
            email: "validation2@example.com",
            username: "validation2",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                time: 90,
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "wall_id, date, and time are required",
        });
    });

    it("POST /session returns 400 when time is missing", async () => {
        const user = await User.create({
            email: "validation3@example.com",
            username: "validation3",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "2026-05-12",
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "wall_id, date, and time are required",
        });
    });

    it("POST /session returns 400 when wall_id is not a valid ObjectId", async () => {
        const user = await User.create({
            email: "validation4@example.com",
            username: "validation4",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: "invalid-id",
                date: "2026-05-12",
                time: 90,
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "wall_id must be a valid ObjectId",
        });
    });

    it("POST /session returns 400 when date is not a valid date string", async () => {
        const user = await User.create({
            email: "validation5@example.com",
            username: "validation5",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "invalid-date",
                time: 90,
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "date must be a valid date string",
        });
    });

    it("POST /session returns 400 when time is not a number", async () => {
        const user = await User.create({
            email: "validation6@example.com",
            username: "validation6",
            userType: "Climber",
            name: "Validation",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app)
            .post("/session")
            .set("Authorization", `Bearer ${accessToken}`)
            .send({
                wall_id: wallId.toString(),
                date: "2026-05-12",
                time: "ninety",
            });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "time must be a number",
        });
    });

    it("POST /session/:sessionId/review returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber2@example.com",
            username: "nonclimber2",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const climbingUser = await User.create({
            email: "climber@example.com",
            username: "climber",
            userType: "Climber",
            name: "Climbing",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: climbingUser._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 75,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .post(`/session/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: 4, body: "Solid climb" });

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can add reviews to climbing sessions",
        });
    });

    it("POST /session/:sessionId/review returns 400 when rating is missing", async () => {
        const user = await User.create({
            email: "validation7@example.com",
            username: "validation7",
            userType: "Climber",
            name: "Validation",
            surname: "User",
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
            .post(`/session/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ body: "Solid climb" });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "Review rating is required",
        });
    });

    it("POST /session/:sessionId/review returns 400 when rating is not a number", async () => {
        const user = await User.create({
            email: "validation8@example.com",
            username: "validation8",
            userType: "Climber",
            name: "Validation",
            surname: "User",
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
            .post(`/session/${session._id.toString()}/review`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ rating: "five", body: "Solid climb" });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "Review rating must be a number",
        });
    });

    it("GET /session returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber3@example.com",
            username: "nonclimber3",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .get("/session")
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can view climbing sessions",
        });
    });

    it("GET /session/:sessionId returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber4@example.com",
            username: "nonclimber4",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const climbingUser = await User.create({
            email: "climber2@example.com",
            username: "climber2",
            userType: "Climber",
            name: "Climbing",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: climbingUser._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 100,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .get(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can view climbing sessions",
        });
    });

    it("PUT /session/:sessionId returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber5@example.com",
            username: "nonclimber5",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const climbingUser = await User.create({
            email: "climber3@example.com",
            username: "climber3",
            userType: "Climber",
            name: "Climbing",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: climbingUser._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 60,
        });

        const newWallId = new mongoose.Types.ObjectId();
        const accessToken = createAuthToken(user);

        const response = await request(app)
            .put(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ wall_id: newWallId.toString(), time: 75 });

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can update climbing sessions",
        });
    });

    it("PUT /session/:sessionId returns 400 when no fields are provided", async () => {
        const user = await User.create({
            email: "validation9@example.com",
            username: "validation9",
            userType: "Climber",
            name: "Validation",
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

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .put(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({});

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "At least one field (wall_id, date, or time) must be provided to update",
        });
    });

    it("PUT /session/:sessionId returns 400 when wall_id is not a valid ObjectId", async () => {
        const user = await User.create({
            email: "validation10@example.com",
            username: "validation10",
            userType: "Climber",
            name: "Validation",
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

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .put(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`)
            .send({ wall_id: "invalid-id" });

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "wall_id must be a valid ObjectId",
        });
    });

    it("DELETE /session/:sessionId returns 403 when user type is not Climber", async () => {
        const user = await User.create({
            email: "nonclimber6@example.com",
            username: "nonclimber6",
            userType: "Facility",
            name: "Non",
            surname: "Climber",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const climbingUser = await User.create({
            email: "climber4@example.com",
            username: "climber4",
            userType: "Climber",
            name: "Climbing",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const session = await ClimbingSession.create({
            climber_id: climbingUser._id,
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date("2026-05-12"),
            time: 45,
        });

        const accessToken = createAuthToken(user);

        const response = await request(app)
            .delete(`/session/${session._id.toString()}`)
            .set("Authorization", `Bearer ${accessToken}`);

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            error: "Only climbers can delete climbing sessions",
        });
    });

    it("POST /session returns 401 when authentication is missing", async () => {
        const wallId = new mongoose.Types.ObjectId();

        const response = await request(app).post("/session").send({
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
