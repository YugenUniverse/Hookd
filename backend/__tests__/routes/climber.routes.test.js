const request = require("supertest");
const express = require("express");
const mongoose = require("mongoose");
const climberRoutes = require("../../routes/climber.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User, Climber } = require("../../models/User");
const ClimbingSession = require("../../models/ClimbingSession");
const { Wall } = require("../../models/Wall");

const app = express();
app.use(express.json());
app.use("/climbers", climberRoutes);
app.use(errorMiddleware);

describe("Climber Routes", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd_test" });
    });

    afterEach(async () => {
        await User.deleteMany({});
        await ClimbingSession.deleteMany({});
        await Wall.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    describe("GET /climbers/leaderboard", () => {
        it("should return an empty array if no climbers exist", async () => {
            const res = await request(app).get("/climbers/leaderboard");
            expect(res.status).toBe(200);
            expect(Array.isArray(res.body)).toBe(true);
            expect(res.body.length).toBe(0);
        });

        it("should return climbers ranked by score (ascents * 50)", async () => {
            // Create a Wall
            const wall = await Wall.create({
                name: "Test Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
            });

            // Create Climber A (2 sessions = 100 points)
            const climberA = await Climber.create({
                email: "a@test.com",
                username: "climberA",
                name: "A",
                surname: "User",
                birthdate: new Date("2000-01-01"),
            });
            await ClimbingSession.create({
                climber_id: climberA._id,
                wall_id: wall._id,
                date: new Date(),
                time: 30,
            });
            await ClimbingSession.create({
                climber_id: climberA._id,
                wall_id: wall._id,
                date: new Date(),
                time: 40,
            });

            // Create Climber B (1 session = 50 points)
            const climberB = await Climber.create({
                email: "b@test.com",
                username: "climberB",
                name: "B",
                surname: "User",
                birthdate: new Date("2000-01-01"),
            });
            await ClimbingSession.create({
                climber_id: climberB._id,
                wall_id: wall._id,
                date: new Date(),
                time: 30,
            });

            // Update the Climber documents with session IDs (as the service might rely on sessions array)
            await Climber.findByIdAndUpdate(climberA._id, {
                $push: {
                    sessions: [
                        new mongoose.Types.ObjectId(),
                        new mongoose.Types.ObjectId(),
                    ],
                },
            });
            await Climber.findByIdAndUpdate(climberB._id, {
                $push: { sessions: [new mongoose.Types.ObjectId()] },
            });

            const res = await request(app).get("/climbers/leaderboard");

            expect(res.status).toBe(200);
            expect(res.body.length).toBe(2);

            // Rank #1 should be Climber A
            expect(res.body[0].username).toBe("climbera");
            expect(res.body[0].totalAscents).toBe(2);
            expect(res.body[0].score).toBe(100);

            // Rank #2 should be Climber B
            expect(res.body[1].username).toBe("climberb");
            expect(res.body[1].score).toBe(50);
        });

        it("should respect the limit parameter", async () => {
            // Create 3 climbers
            for (let i = 0; i < 3; i++) {
                await Climber.create({
                    email: `user${i}@test.com`,
                    username: `user${i}`,
                    name: "Test",
                    surname: "User",
                    birthdate: new Date(),
                });
            }

            const res = await request(app).get("/climbers/leaderboard?limit=2");
            expect(res.status).toBe(200);
            expect(res.body.length).toBe(2);
        });

        it("should return the correct data structure for the Flutter model", async () => {
            await Climber.create({
                email: "flutter@test.com",
                username: "flutter_tester",
                name: "Test",
                surname: "User",
                birthdate: new Date(),
            });

            const res = await request(app).get("/climbers/leaderboard");
            const entry = res.body[0];

            expect(entry).toHaveProperty("id");
            expect(entry).toHaveProperty("username");
            expect(entry).toHaveProperty("totalAscents");
            expect(entry).toHaveProperty("score");
            expect(entry).toHaveProperty("badges");
            expect(Array.isArray(entry.badges)).toBe(true);
        });
    });

    describe("POST /climbers/:id/badges", () => {
        let ownerToken;
        const jwt = require("jsonwebtoken");

        beforeAll(() => {
            process.env.JWT_SECRET = "test-jwt-secret";
            ownerToken = jwt.sign(
                { sub: new mongoose.Types.ObjectId().toString(), email: "owner@test.com", userType: "FacilityOwner" },
                process.env.JWT_SECRET,
                { expiresIn: "1h", issuer: "hookd" }
            );
        });

        it("awards a badge to a climber and updates wallet", async () => {
            const climber = await Climber.create({
                email: "badgeuser@test.com",
                username: "badgeUser",
                name: "Badge",
                surname: "User",
            });

            const Badge = require("../../models/Badge");
            const badge = await Badge.create({
                name: "Test Award Badge",
                score: 50
            });

            const res = await request(app)
                .post(`/climbers/${climber._id}/badges`)
                .set("Authorization", `Bearer ${ownerToken}`)
                .send({ badgeId: badge._id });

            expect(res.status).toBe(200);
            expect(res.body.score).toBe(50);
            expect(res.body.badges).toHaveLength(1);
            expect(res.body.badges[0].badge).toBe(badge._id.toString());
        });
    });
});
