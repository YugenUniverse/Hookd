const request = require("supertest");
const express = require("express");
const mongoose = require("mongoose");
const wallRoutes = require("../../routes/wall.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Wall, IndoorWall } = require("../../models/Wall");
const { User } = require("../../models/User");
const Facility = require("../../models/Facility");
const ClimbingSession = require("../../models/ClimbingSession");

jest.setTimeout(30000);

const MOCK_USER_ID = "60d5ecdec021f13528e01369";

jest.mock("../../middleware/auth.middleware", () => ({
    authenticateJwt: (req, res, next) => {
        req.user = {
            id: MOCK_USER_ID,
            userType: "FacilityOwner",
        };
        next();
    },
    restrictTo:
        (...roles) =>
        (req, res, next) =>
            next(),
}));

const app = express();
app.use(express.json());
app.use("/walls", wallRoutes);
app.use(errorMiddleware);

describe("Wall Routes", () => {
    let testFacility;

    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    beforeEach(async () => {
        testFacility = await Facility.create({
            name: "Test Gym",
            location: { coordinates: [11.12, 46.06] },
            ownerAccount: MOCK_USER_ID,
        });
    });

    afterEach(async () => {
        await Wall.deleteMany({});
        await Facility.deleteMany({});
        await User.deleteMany({});
        await ClimbingSession.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    describe("GET /walls", () => {
        it("should return all walls", async () => {
            await IndoorWall.create({
                name: "Wall 1",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });

            const res = await request(app).get("/walls");
            expect(res.status).toBe(200);
            expect(Array.isArray(res.body)).toBe(true);
            expect(res.body.length).toBe(1);
        });
    });

    describe("GET /walls/search", () => {
        it("should return walls matching query", async () => {
            await IndoorWall.create({
                name: "Everest Indoor",
                difficulty: "ADVANCED",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });

            const res = await request(app).get("/walls/search?q=Everest");
            expect(res.status).toBe(200);
            expect(res.body[0].name).toBe("Everest Indoor");
        });

        it("should return 400 if query is missing", async () => {
            const res = await request(app).get("/walls/search");
            expect(res.status).toBe(400);
        });
    });

    describe("GET /walls/nearby", () => {
        it("should return walls within radius", async () => {
            await IndoorWall.create({
                name: "Nearby Wall",
                difficulty: "INTERMEDIATE",
                location: { type: "Point", coordinates: [11.12, 46.06] },
                facility: testFacility._id,
            });

            const res = await request(app).get(
                "/walls/nearby?lng=11.12&lat=46.06&radius=5000",
            );
            expect(res.status).toBe(200);
            expect(res.body.length).toBe(1);
        });
    });

    describe("POST /walls", () => {
        it("should create a new wall and add it to the facility's walls array", async () => {
            const wallData = {
                name: "New Gym Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [12, 45], address: "123 Street" },
            };

            const res = await request(app).post("/walls").send(wallData);

            expect(res.status).toBe(201);
            expect(res.body.wall.name).toBe("New Gym Wall");

            const updatedFacility = await Facility.findById(testFacility._id);
            expect(updatedFacility.walls.length).toBe(1);
        });
    });

    describe("GET /walls/:id/leaderboard", () => {
        it("should return leaderboard data structure", async () => {
            const wall = await IndoorWall.create({
                name: "Leaderboard Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });

            const res = await request(app).get(
                `/walls/${wall._id}/leaderboard`,
            );
            expect(res.status).toBe(200);
            expect(res.body).toHaveProperty("seasonName");
            expect(res.body).toHaveProperty("leaderboard");
        });

        it("should return 400 for invalid offset", async () => {
            const wall = await IndoorWall.create({
                name: "Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });
            const res = await request(app).get(
                `/walls/${wall._id}/leaderboard?offset=1`,
            );
            expect(res.status).toBe(400);
        });
    });

    describe("DELETE /walls/:id", () => {
        it("should delete the wall and remove it from the facility's walls array", async () => {
            const wall = await IndoorWall.create({
                name: "Wall to Delete",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });
            await Facility.findByIdAndUpdate(testFacility._id, { $push: { walls: wall._id } });

            const res = await request(app).delete(`/walls/${wall._id}`);
            expect(res.status).toBe(200);

            const deletedWall = await Wall.findById(wall._id);
            expect(deletedWall).toBeNull();

            const updatedFacility = await Facility.findById(testFacility._id);
            expect(updatedFacility.walls).not.toContainEqual(wall._id);
        });
    });
});
