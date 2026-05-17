const request = require("supertest");
const express = require("express");
const mongoose = require("mongoose");
const wallRoutes = require("../../routes/wall.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Wall, IndoorWall, OutdoorWall } = require("../../models/Wall");
const { User, PublicBody } = require("../../models/User");
const Facility = require("../../models/Facility");
const ClimbingSession = require("../../models/ClimbingSession");

jest.setTimeout(30000);

const MOCK_FACILITY_OWNER_ID = "60d5ecdec021f13528e01369";
const MOCK_PUBLIC_BODY_ID = "60d5ecdec021f13528e01370";

// var (not const) so the jest.mock closure can read mutations set in beforeEach
var mockUserId = MOCK_FACILITY_OWNER_ID;
var mockUserType = "FacilityOwner";

jest.mock("../../middleware/auth.middleware", () => ({
    authenticateJwt: (req, res, next) => {
        req.user = { id: mockUserId, userType: mockUserType };
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
        mockUserId = MOCK_FACILITY_OWNER_ID;
        mockUserType = "FacilityOwner";

        testFacility = await Facility.create({
            name: "Test Gym",
            location: { coordinates: [11.12, 46.06] },
            ownerAccount: MOCK_FACILITY_OWNER_ID,
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

    describe("GET /walls/owned", () => {
        it("should return walls owned by the authenticated Facility", async () => {
            await IndoorWall.create({
                name: "Facility Wall",
                difficulty: "INTERMEDIATE",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });

            await IndoorWall.create({
                name: "Other Facility Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [1, 1] },
                facility: new mongoose.Types.ObjectId(),
            });

            const res = await request(app).get("/walls/owned");
            expect(res.status).toBe(200);
            expect(Array.isArray(res.body)).toBe(true);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].name).toBe("Facility Wall");
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

    // ── FacilityOwner operations ─────────────────────────────────────────────

    describe("POST /walls (FacilityOwner)", () => {
        it("creates a wall using the facility's location when none is provided", async () => {
            const res = await request(app).post("/walls").send({
                name: "New Gym Wall",
                difficulty: "BEGINNER",
            });

            expect(res.status).toBe(201);
            expect(res.body.wall.name).toBe("New Gym Wall");
            // Location should inherit from the facility
            expect(res.body.wall.location.coordinates).toEqual(
                testFacility.location.coordinates,
            );

            const updatedFacility = await Facility.findById(testFacility._id);
            expect(updatedFacility.walls.length).toBe(1);
        });

        it("uses a provided location when one is given", async () => {
            const res = await request(app).post("/walls").send({
                name: "Custom Loc Wall",
                difficulty: "ADVANCED",
                location: { coordinates: [12, 45] },
            });

            expect(res.status).toBe(201);
            expect(res.body.wall.location.coordinates).toEqual([12, 45]);
        });
    });

    describe("PUT /walls/:id (FacilityOwner)", () => {
        it("updates name, description, and difficulty", async () => {
            const wall = await IndoorWall.create({
                name: "Old Name",
                description: "Old desc",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });

            const res = await request(app).put(`/walls/${wall._id}`).send({
                name: "New Name",
                description: "New desc",
                difficulty: "ADVANCED",
            });

            expect(res.status).toBe(200);
            expect(res.body.wall.name).toBe("New Name");
            expect(res.body.wall.difficulty).toBe("ADVANCED");

            const updated = await Wall.findById(wall._id);
            expect(updated.name).toBe("New Name");
            expect(updated.difficulty).toBe("ADVANCED");
        });

        it("returns 403 when the wall belongs to a different facility", async () => {
            const otherFacility = await Facility.create({
                name: "Other Gym",
                location: { coordinates: [0, 0] },
                ownerAccount: new mongoose.Types.ObjectId(),
            });
            const wall = await IndoorWall.create({
                name: "Unowned Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: otherFacility._id,
            });

            const res = await request(app).put(`/walls/${wall._id}`).send({
                name: "Hacked",
                difficulty: "EXPERT",
            });

            expect(res.status).toBe(403);
        });

        it("returns 404 for a non-existent wall id", async () => {
            const fakeId = new mongoose.Types.ObjectId();
            const res = await request(app).put(`/walls/${fakeId}`).send({
                name: "Ghost",
                difficulty: "BEGINNER",
            });

            expect(res.status).toBe(404);
        });
    });

    describe("DELETE /walls/:id (FacilityOwner)", () => {
        it("deletes the wall and removes it from the facility's walls array", async () => {
            const wall = await IndoorWall.create({
                name: "Wall to Delete",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                facility: testFacility._id,
            });
            await Facility.findByIdAndUpdate(testFacility._id, {
                $push: { walls: wall._id },
            });

            const res = await request(app).delete(`/walls/${wall._id}`);
            expect(res.status).toBe(200);

            expect(await Wall.findById(wall._id)).toBeNull();

            const updatedFacility = await Facility.findById(testFacility._id);
            expect(updatedFacility.walls).not.toContainEqual(wall._id);
        });
    });

    // ── PublicBody operations ────────────────────────────────────────────────

    describe("PublicBody wall operations", () => {
        let publicBody;

        beforeEach(async () => {
            mockUserId = MOCK_PUBLIC_BODY_ID;
            mockUserType = "PublicBody";

            publicBody = await PublicBody.create({
                _id: MOCK_PUBLIC_BODY_ID,
                email: "parks@gov.example",
                username: "parks_dept",
                name: "Department of Parks",
                location: { coordinates: [11.12, 46.06] },
                authMethods: ["local"],
            });
        });

        it("creates an outdoor wall and adds it to the PublicBody's walls array", async () => {
            const res = await request(app).post("/walls").send({
                name: "Rock Face Alpha",
                difficulty: "INTERMEDIATE",
                location: {
                    type: "Point",
                    coordinates: [11.12, 46.06],
                    address: "Mountain Road 1",
                },
            });

            expect(res.status).toBe(201);
            expect(res.body.wall.name).toBe("Rock Face Alpha");

            const updatedPb = await PublicBody.findById(MOCK_PUBLIC_BODY_ID);
            expect(updatedPb.walls.length).toBe(1);
        });

        it("updates an outdoor wall owned by the PublicBody", async () => {
            const wall = await OutdoorWall.create({
                name: "Old Rock",
                difficulty: "BEGINNER",
                location: { coordinates: [11.12, 46.06] },
                publicBody: MOCK_PUBLIC_BODY_ID,
            });

            const res = await request(app).put(`/walls/${wall._id}`).send({
                name: "New Rock",
                difficulty: "EXPERT",
            });

            expect(res.status).toBe(200);
            expect(res.body.wall.name).toBe("New Rock");
            expect(res.body.wall.difficulty).toBe("EXPERT");
        });

        it("returns 403 when updating a wall owned by a different PublicBody", async () => {
            const wall = await OutdoorWall.create({
                name: "Someone Else's Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                publicBody: new mongoose.Types.ObjectId(),
            });

            const res = await request(app).put(`/walls/${wall._id}`).send({
                name: "Stolen",
                difficulty: "EXPERT",
            });

            expect(res.status).toBe(403);
        });

        it("deletes an outdoor wall and removes it from the PublicBody's walls array", async () => {
            const wall = await OutdoorWall.create({
                name: "Wall to Delete",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                publicBody: MOCK_PUBLIC_BODY_ID,
            });
            await PublicBody.findByIdAndUpdate(MOCK_PUBLIC_BODY_ID, {
                $push: { walls: wall._id },
            });

            const res = await request(app).delete(`/walls/${wall._id}`);
            expect(res.status).toBe(200);

            expect(await Wall.findById(wall._id)).toBeNull();

            const updatedPb = await PublicBody.findById(MOCK_PUBLIC_BODY_ID);
            expect(updatedPb.walls.length).toBe(0);
        });
    });
});
