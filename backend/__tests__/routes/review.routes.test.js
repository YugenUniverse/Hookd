const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const reviewRoutes = require("../../routes/review.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const Review = require("../../models/Review");
const ClimbingSession = require("../../models/ClimbingSession");
const { Wall } = require("../../models/Wall");
const { User } = require("../../models/User");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/reviews", reviewRoutes);
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

describe("review.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Review.deleteMany({});
        await ClimbingSession.deleteMany({});
        await Wall.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    it("GET /reviews/wall/:wallId returns only public reviews for guests", async () => {
        const climberOne = await User.create({
            email: "review-one@example.com",
            username: "reviewone",
            userType: "Climber",
            name: "Review",
            surname: "One",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });
        const climberTwo = await User.create({
            email: "review-two@example.com",
            username: "reviewtwo",
            userType: "Climber",
            name: "Review",
            surname: "Two",
            birthdate: new Date("1991-01-01"),
            authMethods: ["local"],
        });

        const wallOne = await Wall.create({
            name: "Wall One",
            description: "Test wall one",
            location: {
                type: "Point",
                coordinates: [11.11, 46.07],
            },
            difficulty: "BEGINNER",
        });
        const wallTwo = await Wall.create({
            name: "Wall Two",
            description: "Test wall two",
            location: {
                type: "Point",
                coordinates: [11.12, 46.08],
            },
            difficulty: "INTERMEDIATE",
        });

        const sessionOne = await ClimbingSession.create({
            climber_id: climberOne._id,
            wall_id: wallOne._id,
            date: new Date("2026-05-12"),
            time: 90,
        });
        const sessionTwo = await ClimbingSession.create({
            climber_id: climberTwo._id,
            wall_id: wallOne._id,
            date: new Date("2026-05-13"),
            time: 75,
            is_private: true,
        });
        const sessionThree = await ClimbingSession.create({
            climber_id: climberOne._id,
            wall_id: wallTwo._id,
            date: new Date("2026-05-14"),
            time: 60,
        });

        await sessionOne.addReview(5, "Great route");
        await sessionTwo.addReview(4, "Solid climb");
        await sessionThree.addReview(3, "Different wall");

        const token = createAuthToken(climberTwo);

        const response = await request(app)
            .get(`/reviews/wall/${wallOne._id.toString()}`)
            ;

        expect(response.status).toBe(200);
        expect(response.body.reviews).toHaveLength(1);
        expect(
            response.body.reviews.every(
                (review) =>
                    review.climbing_session_id.wall_id.id ===
                    wallOne._id.toString(),
            ),
        ).toBe(true);

        const ownerResponse = await request(app)
            .get(`/reviews/wall/${wallOne._id.toString()}`)
            .set("Authorization", `Bearer ${token}`);

        expect(ownerResponse.status).toBe(200);
        expect(ownerResponse.body.reviews).toHaveLength(2);
    });

    it("GET /reviews/user/:userId returns private reviews only to the owner", async () => {
        const climberOne = await User.create({
            email: "user-review-one@example.com",
            username: "userreviewone",
            userType: "Climber",
            name: "User",
            surname: "One",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });
        const climberTwo = await User.create({
            email: "user-review-two@example.com",
            username: "userreviewtwo",
            userType: "Climber",
            name: "User",
            surname: "Two",
            birthdate: new Date("1991-01-01"),
            authMethods: ["local"],
        });

        const wall = await Wall.create({
            name: "Review Wall",
            description: "Test wall",
            location: {
                type: "Point",
                coordinates: [11.13, 46.09],
            },
            difficulty: "ADVANCED",
        });

        const userOneSession = await ClimbingSession.create({
            climber_id: climberOne._id,
            wall_id: wall._id,
            date: new Date("2026-05-12"),
            time: 110,
            is_private: true,
        });
        const userTwoSession = await ClimbingSession.create({
            climber_id: climberTwo._id,
            wall_id: wall._id,
            date: new Date("2026-05-13"),
            time: 95,
        });

        await userOneSession.addReview(5, "Excellent");
        await userTwoSession.addReview(2, "Hard one");

        const guestResponse = await request(app)
            .get(`/reviews/user/${climberOne._id.toString()}`)
            ;

        expect(guestResponse.status).toBe(200);
        expect(guestResponse.body.reviews).toHaveLength(0);

        const ownerToken = createAuthToken(climberOne);
        const ownerResponse = await request(app)
            .get(`/reviews/user/${climberOne._id.toString()}`)
            .set("Authorization", `Bearer ${ownerToken}`);

        expect(ownerResponse.status).toBe(200);
        expect(ownerResponse.body.reviews).toHaveLength(1);
        expect(ownerResponse.body.reviews[0].climbing_session_id.climber_id.id).toBe(
            climberOne._id.toString(),
        );
    });

    it("GET /reviews/wall/:wallId ignores invalid ids", async () => {
        const response = await request(app).get("/reviews/wall/123");

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            error: "Invalid wall id",
        });
    });
});