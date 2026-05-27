const express = require("express");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const request = require("supertest");

const userRoutes = require("../../routes/user.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User, Climber, FacilityOwner } = require("../../models/User");
const Facility = require("../../models/Facility");
const { IndoorWall } = require("../../models/Wall");
require("../../models/Badge");

const app = express();
app.use(express.json());
app.use("/users", userRoutes);
app.use(errorMiddleware);

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

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

describe("user.routes", () => {
    beforeAll(async () => {
        // Suppress expected error logs during testing.
        jest.spyOn(console, "error").mockImplementation(() => {});

        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await User.deleteMany({});
        await Facility.deleteMany({});
        await IndoorWall.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    it("GET /users/:id returns 404 for malformed user id", async () => {
        const response = await request(app).get("/users/not-a-valid-id");

        expect(response.status).toBe(404);
    });

    it("GET /users/:id returns 404 when user does not exist", async () => {
        const missingId = new mongoose.Types.ObjectId().toString();

        const response = await request(app).get(`/users/${missingId}`);

        expect(response.status).toBe(404);
        expect(response.body).toEqual({
            error: expect.stringContaining("User not found"),
        });
    });

    it("GET /users/:id returns public user info without authentication", async () => {
        const climber = await Climber.create({
            email: "public.climber@example.com",
            username: "publicClimber",
            userType: "Climber",
            name: "Public",
            surname: "Climber",
            birthdate: "1990-01-01",
            bio: "Loves overhang routes",
            avatar: "https://example.com/avatar.png",
            password: "SuperSecret123!",
        });

        const response = await request(app).get(`/users/${climber.id}`);
        if (response.status === 500) {
            console.log("500 ERROR BODY:", response.body);
        }

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            id: climber.id,
            username: "publicClimber",
            avatar: "https://example.com/avatar.png",
            userType: "Climber",
            profile: {
                bio: "Loves overhang routes",
                description: "",
                location: null,
            },
            wallet: {
                score: 0,
                badges: [],
            },
        });

        expect(response.body.email).toBeUndefined();
        expect(response.body.password).toBeUndefined();
        expect(response.body.googleId).toBeUndefined();
        expect(response.body.authMethods).toBeUndefined();
        expect(response.body.profile.name).toBeUndefined();
        expect(response.body.profile.surname).toBeUndefined();
    });

    it("GET /users/me requires authentication", async () => {
        const response = await request(app).get("/users/me");

        expect(response.status).toBe(401);
        expect(response.body).toEqual({
            error: expect.stringContaining("Missing or invalid Authorization header"),
        });
    });

    it("GET /users/me returns current logged user with private info", async () => {
        const climber = await Climber.create({
            email: "private.climber@example.com",
            username: "privateClimber",
            userType: "Climber",
            name: "Private",
            surname: "Climber",
            birthdate: "1992-05-10",
            bio: "Projecting steep routes",
            avatar: "https://example.com/private-avatar.png",
            password: "VerySecret123!",
        });

        const token = createAuthToken({
            _id: { toString: () => climber.id },
            email: climber.email,
            userType: climber.userType,
        });

        const response = await request(app)
            .get("/users/me")
            .set("Authorization", `Bearer ${token}`);

        expect(response.status).toBe(200);
        expect(response.body).toEqual(
            expect.objectContaining({
                id: climber.id,
                email: "private.climber@example.com",
                username: "privateClimber",
                userType: "Climber",
                name: "Private",
                surname: "Climber",
                bio: "Projecting steep routes",
                avatar: "https://example.com/private-avatar.png",
            }),
        );
        expect(response.body.password).toBeUndefined();
    });

    it("GET /users/me returns facility wall descriptions for facility owners", async () => {
        const facility = await Facility.create({
            name: "Private Gym",
            description: "A testing gym",
            location: { type: "Point", coordinates: [11.1, 46.1] },
        });

        const wall = await IndoorWall.create({
            name: "Overhang 1",
            description: "Steep training wall",
            difficulty: "INTERMEDIATE",
            location: { type: "Point", coordinates: [11.1, 46.1] },
            facility: facility._id,
        });

        facility.walls = [wall._id];
        await facility.save();

        const owner = await FacilityOwner.create({
            email: "owner@example.com",
            username: "facilityOwner",
            userType: "FacilityOwner",
            facility: facility._id,
            password: "VerySecret123!",
        });

        facility.ownerAccount = owner._id;
        await facility.save();

        const token = createAuthToken({
            _id: { toString: () => owner.id },
            email: owner.email,
            userType: owner.userType,
        });

        const response = await request(app)
            .get("/users/me")
            .set("Authorization", `Bearer ${token}`);

        expect(response.status).toBe(200);
        expect(response.body.facility).toBeDefined();
        expect(response.body.facility.walls).toHaveLength(1);
        expect(response.body.facility.walls[0].description).toBe("Steep training wall");
    });
});
