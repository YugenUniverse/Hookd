const request = require("supertest");
const express = require("express");
const mongoose = require("mongoose");

const poiRoutes = require("../../routes/poi.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Wall, IndoorWall, OutdoorWall } = require("../../models/Wall");
const { User, PublicBody } = require("../../models/User");
const Facility = require("../../models/Facility");

jest.setTimeout(30000);

const app = express();
app.use(express.json());
app.use("/pois", poiRoutes);
app.use(errorMiddleware);

// Trento coordinates used throughout
const TRENTO = { lng: 11.1217, lat: 46.0667 };
// A point ~200 km away (Venice area)
const FAR_AWAY = { lng: 12.3326, lat: 45.4384 };

describe("POI Routes", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    afterEach(async () => {
        await Wall.deleteMany({});
        await Facility.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    // ─── GET /pois ──────────────────────────────────────────────────────────

    describe("GET /pois", () => {
        it("returns an empty array when there is no data", async () => {
            const res = await request(app).get("/pois");
            expect(res.status).toBe(200);
            expect(res.body).toEqual([]);
        });

        it("returns a FacilityPoi for each Facility user", async () => {
            const facility = await Facility.create({
                name: "Climb Gym Trento",
                description: "Best gym in town",
                location: {
                    type: "Point",
                    coordinates: [TRENTO.lng, TRENTO.lat],
                    address: "Via Roma 1, Trento",
                },
            });

            const wall = await IndoorWall.create({
                name: "Yellow Route",
                difficulty: "BEGINNER",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                facility: facility._id,
            });
            await Facility.findByIdAndUpdate(facility._id, {
                $push: { walls: wall._id },
            });

            const res = await request(app).get("/pois");

            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);

            const poi = res.body[0];
            expect(poi.poiType).toBe("Facility");
            expect(poi.name).toBe("Climb Gym Trento");
            expect(poi.description).toBe("Best gym in town");
            expect(poi.location.coordinates).toEqual([TRENTO.lng, TRENTO.lat]);
            expect(poi.address).toBe("Via Roma 1, Trento");
            expect(poi.walls).toHaveLength(1);
            expect(poi.walls[0].name).toBe("Yellow Route");
            expect(poi.walls[0].difficulty).toBe("BEGINNER");
        });

        it("returns an OutdoorWallPoi for each OutdoorWall", async () => {
            const publicBody = await PublicBody.create({
                email: "park@test.com",
                username: "naturereserve",
                name: "Dolomiti Park",
                description: "Nature reserve",
                location: {
                    type: "Point",
                    coordinates: [TRENTO.lng, TRENTO.lat],
                },
            });

            await OutdoorWall.create({
                name: "Falesie del Lago",
                difficulty: "ADVANCED",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                publicBody: publicBody._id,
            });

            const res = await request(app).get("/pois");

            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);

            const poi = res.body[0];
            expect(poi.poiType).toBe("OutdoorWall");
            expect(poi.name).toBe("Falesie del Lago");
            expect(poi.difficulty).toBe("ADVANCED");
            expect(poi.location.coordinates).toEqual([TRENTO.lng, TRENTO.lat]);
        });

        it("does NOT include IndoorWalls as top-level POIs", async () => {
            const facility = await Facility.create({
                name: "Gym 2",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await IndoorWall.create({
                name: "Indoor Only",
                difficulty: "BEGINNER",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                facility: facility._id,
            });

            const res = await request(app).get("/pois");
            expect(res.status).toBe(200);
            // Only the Facility POI; no separate IndoorWall POI
            expect(res.body).toHaveLength(1);
            expect(res.body[0].poiType).toBe("Facility");
        });

        it("returns both Facilities and OutdoorWalls together", async () => {
            const publicBody = await PublicBody.create({
                email: "body@test.com",
                username: "body",
                name: "Public Body",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await OutdoorWall.create({
                name: "Outdoor Crag",
                difficulty: "INTERMEDIATE",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                publicBody: publicBody._id,
            });

            const facility = await Facility.create({
                name: "Gym 3",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await IndoorWall.create({
                name: "Indoor Route",
                difficulty: "BEGINNER",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                facility: facility._id,
            });

            const res = await request(app).get("/pois");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(2);

            const types = res.body.map((p) => p.poiType).sort();
            expect(types).toEqual(["Facility", "OutdoorWall"]);
        });
    });

    // ─── GET /pois/search ───────────────────────────────────────────────────

    describe("GET /pois/search", () => {
        it("returns 400 when query is missing", async () => {
            const res = await request(app).get("/pois/search");
            expect(res.status).toBe(400);
        });

        it("returns 400 when query is shorter than 2 characters", async () => {
            const res = await request(app).get("/pois/search?q=a");
            expect(res.status).toBe(400);
        });

        it("returns matching Facility POIs by name", async () => {
            await Facility.create({
                name: "Climb Gym Trento",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await Facility.create({
                name: "Unrelated Gym",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });

            const res = await request(app).get("/pois/search?q=Climb");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].poiType).toBe("Facility");
            expect(res.body[0].name).toBe("Climb Gym Trento");
        });

        it("returns matching OutdoorWall POIs by name", async () => {
            const publicBody = await PublicBody.create({
                email: "pb@test.com",
                username: "pbody",
                name: "Parks Dept",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await OutdoorWall.create({
                name: "Falesie del Lago",
                difficulty: "ADVANCED",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                publicBody: publicBody._id,
            });

            const res = await request(app).get("/pois/search?q=Falesie");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].poiType).toBe("OutdoorWall");
            expect(res.body[0].name).toBe("Falesie del Lago");
        });

        it("does NOT return IndoorWalls as top-level results", async () => {
            const facility = await Facility.create({
                name: "Boulder Palace",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await IndoorWall.create({
                name: "The Slab",
                difficulty: "BEGINNER",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                facility: facility._id,
            });

            // Searching for the indoor wall name returns nothing
            const res = await request(app).get("/pois/search?q=Slab");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(0);
        });

        it("returns both Facilities and OutdoorWalls when both match", async () => {
            const publicBody = await PublicBody.create({
                email: "pb2@test.com",
                username: "pbody2",
                name: "Parks Dept 2",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await OutdoorWall.create({
                name: "Dolomiti Crag",
                difficulty: "EXPERT",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                publicBody: publicBody._id,
            });
            await Facility.create({
                name: "Dolomiti Gym",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });

            const res = await request(app).get("/pois/search?q=Dolomiti");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(2);
            const types = res.body.map((p) => p.poiType).sort();
            expect(types).toEqual(["Facility", "OutdoorWall"]);
        });

        it("is case-insensitive", async () => {
            await Facility.create({
                name: "Rock City Gym",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });

            const res = await request(app).get("/pois/search?q=rock city");
            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].name).toBe("Rock City Gym");
        });
    });

    // ─── GET /pois/nearby ───────────────────────────────────────────────────

    describe("GET /pois/nearby", () => {
        it("returns 400 when lng or lat are missing", async () => {
            const missingLat = await request(app).get("/pois/nearby?lng=11.12");
            expect(missingLat.status).toBe(400);

            const missingLng = await request(app).get("/pois/nearby?lat=46.06");
            expect(missingLng.status).toBe(400);

            const missingBoth = await request(app).get("/pois/nearby");
            expect(missingBoth.status).toBe(400);
        });

        it("returns a Facility POI within the radius", async () => {
            const facility = await Facility.create({
                name: "Nearby Gym",
                location: {
                    type: "Point",
                    coordinates: [TRENTO.lng, TRENTO.lat],
                },
            });
            const wall = await IndoorWall.create({
                name: "Route A",
                difficulty: "BEGINNER",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                facility: facility._id,
            });
            await Facility.findByIdAndUpdate(facility._id, {
                $push: { walls: wall._id },
            });

            const res = await request(app).get(
                `/pois/nearby?lng=${TRENTO.lng}&lat=${TRENTO.lat}&radius=5000`,
            );

            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].poiType).toBe("Facility");
            expect(res.body[0].name).toBe("Nearby Gym");
            expect(res.body[0].walls).toHaveLength(1);
        });

        it("returns an OutdoorWall POI within the radius", async () => {
            const publicBody = await PublicBody.create({
                email: "pb2@test.com",
                username: "pb2",
                name: "PB 2",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
            });
            await OutdoorWall.create({
                name: "Crag Nearby",
                difficulty: "EXPERT",
                location: { type: "Point", coordinates: [TRENTO.lng, TRENTO.lat] },
                publicBody: publicBody._id,
            });

            const res = await request(app).get(
                `/pois/nearby?lng=${TRENTO.lng}&lat=${TRENTO.lat}&radius=5000`,
            );

            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(1);
            expect(res.body[0].poiType).toBe("OutdoorWall");
            expect(res.body[0].name).toBe("Crag Nearby");
        });

        it("does not return POIs that are outside the radius", async () => {
            await Facility.create({
                name: "Far Gym",
                location: {
                    type: "Point",
                    coordinates: [TRENTO.lng, TRENTO.lat],
                },
            });

            // Query from Venice with a small radius — should find nothing
            const res = await request(app).get(
                `/pois/nearby?lng=${FAR_AWAY.lng}&lat=${FAR_AWAY.lat}&radius=1000`,
            );

            expect(res.status).toBe(200);
            expect(res.body).toHaveLength(0);
        });

        it("uses default radius of 30000 m when radius param is omitted", async () => {
            await Facility.create({
                name: "Default Radius Gym",
                location: {
                    type: "Point",
                    coordinates: [TRENTO.lng, TRENTO.lat],
                },
            });

            // Query from a point ~15 km away — within the 30 km default
            const nearby = await request(app).get(
                `/pois/nearby?lng=${TRENTO.lng + 0.1}&lat=${TRENTO.lat + 0.1}`,
            );
            expect(nearby.status).toBe(200);
            expect(nearby.body.length).toBeGreaterThan(0);
        });
    });
});
