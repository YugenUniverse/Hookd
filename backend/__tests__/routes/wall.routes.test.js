const express = require("express");
const request = require("supertest");
const mongoose = require("mongoose");

const wallRoutes = require("../../routes/wall.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Wall } = require("../../models/Wall");
const ClimbingSession = require("../../models/ClimbingSession");
const { User } = require("../../models/User");

const app = express();
app.use(express.json());
app.use("/walls", wallRoutes);
app.use(errorMiddleware);

describe("wall.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await ClimbingSession.deleteMany({});
        await Wall.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    // Deprecated sessions-count endpoint tests removed; rely on GET /walls/:id

    it("GET /walls/:id returns the updated mean rating after new reviews are added", async () => {
        const wall = await Wall.create({
            name: "Rated Wall",
            description: "Wall for rating aggregation",
            location: {
                type: "Point",
                coordinates: [11.12, 46.08],
            },
            difficulty: "INTERMEDIATE",
        });

        const user = await User.create({
            email: "rating@example.com",
            username: "rater",
            userType: "Climber",
            name: "Rate",
            surname: "User",
            birthdate: new Date("1990-01-01"),
            authMethods: ["local"],
        });

        const firstSession = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: wall._id,
            date: new Date("2026-05-12"),
            time: 60,
        });
        const secondSession = await ClimbingSession.create({
            climber_id: user._id,
            wall_id: wall._id,
            date: new Date("2026-05-13"),
            time: 75,
        });

        await firstSession.addReview(5, "Excellent route");
        await secondSession.addReview(3, "Good but harder");

        const response = await request(app).get(`/walls/${wall._id.toString()}`);

        expect(response.status).toBe(200);
        expect(response.body.rating).toBe(4);
        expect(response.body.totalSessions).toBe(2);
    });
});
