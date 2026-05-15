const mongoose = require("mongoose");
const { Wall, IndoorWall, OutdoorWall } = require("../../models/Wall");
require("../../models/ClimbingSession");

jest.setTimeout(30000);

describe("Wall model suite", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    afterEach(async () => {
        await Wall.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    describe("Base Wall Schema", () => {
        it("requires a name, coordinates, and valid difficulty", async () => {
            const wall = new Wall({
                name: "The Great Wall",
                location: {
                    coordinates: [11.1211, 46.0679], // [Lng, Lat]
                },
                difficulty: "INTERMEDIATE",
            });

            await wall.save();
            expect(wall.id).toBeDefined();
            expect(wall.status).toBe("OPEN"); // Default value
        });

        it("fails if difficulty is not in enum", async () => {
            const wall = new Wall({
                name: "Invalid Wall",
                location: { coordinates: [0, 0] },
                difficulty: "SUPER_HARD", // Not in enum
            });
            await expect(wall.save()).rejects.toThrow();
        });

        it("fails if name is missing", async () => {
            const wall = new Wall({
                location: { coordinates: [0, 0] },
                difficulty: "BEGINNER",
            });
            await expect(wall.save()).rejects.toThrow();
        });

        it("enforces description character limit", async () => {
            const wall = new Wall({
                name: "Too Wordy",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
                description: "a".repeat(1001),
            });
            await expect(wall.save()).rejects.toThrow(
                /Description cannot be more than 1000 characters/,
            );
        });

        it("transforms _id to id and removes __v in JSON", async () => {
            const wall = await Wall.create({
                name: "Transform Test",
                difficulty: "BEGINNER",
                location: { coordinates: [1, 1] },
            });

            const json = wall.toJSON();
            expect(json.id).toBeDefined();
            expect(json._id).toBeUndefined();
            expect(json.__v).toBeUndefined();
        });
    });

    describe("IndoorWall Discriminator", () => {
        it("creates an indoor wall with a facility reference", async () => {
            const facilityId = new mongoose.Types.ObjectId();
            const indoorWall = await IndoorWall.create({
                name: "Urban Climb",
                difficulty: "ADVANCED",
                location: { coordinates: [10, 10] },
                facility: facilityId,
            });

            expect(indoorWall.wallType).toBe("IndoorWall");
            expect(indoorWall.facility).toEqual(facilityId);
        });

        it("fails if facility reference is missing", async () => {
            const indoorWall = new IndoorWall({
                name: "Homeless Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [10, 10] },
                // Missing facility
            });
            await expect(indoorWall.save()).rejects.toThrow();
        });
    });

    describe("OutdoorWall Discriminator", () => {
        it("creates an outdoor wall with a publicBody reference", async () => {
            const bodyId = new mongoose.Types.ObjectId();
            const outdoorWall = await OutdoorWall.create({
                name: "Mountain Peak",
                difficulty: "EXPERT",
                location: { coordinates: [12.5, 42.1] },
                publicBody: bodyId,
            });

            expect(outdoorWall.wallType).toBe("OutdoorWall");
            expect(outdoorWall.publicBody).toEqual(bodyId);
        });

        it("fails if publicBody reference is missing", async () => {
            const outdoorWall = new OutdoorWall({
                name: "Wild Wall",
                difficulty: "INTERMEDIATE",
                location: { coordinates: [0, 0] },
                // Missing publicBody
            });
            await expect(outdoorWall.save()).rejects.toThrow();
        });
    });

    describe("Geospatial & Search Functionality", () => {
        it("successfully saves valid 2dsphere coordinates", async () => {
            const wall = await Wall.create({
                name: "Map Wall",
                difficulty: "UNKNOWN",
                location: {
                    type: "Point",
                    coordinates: [-122.4194, 37.7749],
                },
            });
            expect(wall.location.coordinates[0]).toBe(-122.4194);
        });
    });

    describe("Methods & Virtuals", () => {
        it("computes rating correctly when no sessions exist", async () => {
            const wall = await Wall.create({
                name: "New Wall",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
            });

            const rating = await wall.computeRating();
            expect(rating).toBe(0);
        });

        it("virtual totalSessions returns 0 by default", async () => {
            const wall = await Wall.create({
                name: "Virtual Test",
                difficulty: "BEGINNER",
                location: { coordinates: [0, 0] },
            });
            expect(wall.totalSessions).toBe(0);
        });
    });
});
