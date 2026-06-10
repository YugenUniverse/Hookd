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
        expect(response.body).toMatchObject({
            id: climber.id,
            username: "publicclimber",
            avatar: "https://example.com/avatar.png",
            userType: "Climber",
            name: "Public",
            surname: "Climber",
            sessionCount: 0,
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

        // Sensitive fields must never be exposed
        expect(response.body.email).toBeUndefined();
        expect(response.body.password).toBeUndefined();
        expect(response.body.googleId).toBeUndefined();
        expect(response.body.authMethods).toBeUndefined();
        expect(response.body.fcmTokens).toBeUndefined();
        // name/surname are at top level, not nested inside profile
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
                username: "privateclimber",
                userType: "Climber",
                name: "Private",
                surname: "Climber",
                bio: "Projecting steep routes",
                avatar: "https://example.com/private-avatar.png",
            }),
        );
        expect(response.body.password).toBeUndefined();
        expect(response.body.fcmTokens).toBeUndefined();
    });

    it("PATCH /users/me requires authentication", async () => {
        const response = await request(app)
            .patch("/users/me")
            .send({ username: "newname" });

        expect(response.status).toBe(401);
    });

    it("PATCH /users/me updates username", async () => {
        const climber = await Climber.create({
            email: "update.climber@example.com",
            username: "oldName",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ username: "newName" });

        expect(response.status).toBe(200);
        expect(response.body.username).toBe("newname");

        const reloaded = await Climber.findById(climber._id);
        expect(reloaded.username).toBe("newname");
    });

    it("PATCH /users/me updates avatar URL", async () => {
        const climber = await Climber.create({
            email: "avatar.climber@example.com",
            username: "avatarUser",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ avatar: "https://example.com/new-avatar.png" });

        expect(response.status).toBe(200);
        expect(response.body.avatar).toBe("https://example.com/new-avatar.png");
    });

    it("PATCH /users/me accepts base64 data URI as avatar", async () => {
        const climber = await Climber.create({
            email: "avatar.base64@example.com",
            username: "base64User",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);
        const dataUri = "data:image/jpeg;base64,/9j/4AAQSkZJRgAB";

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ avatar: dataUri });

        expect(response.status).toBe(200);
        expect(response.body.avatar).toBe(dataUri);

        const reloaded = await Climber.findById(climber._id);
        expect(reloaded.avatar).toBe(dataUri);
    });

    it("PATCH /users/me updates climber-specific fields", async () => {
        const climber = await Climber.create({
            email: "fields.climber@example.com",
            username: "fieldsUser",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({
                name: "Mario",
                surname: "Rossi",
                bio: "Loves bouldering",
                birthdate: "1995-06-15",
            });

        expect(response.status).toBe(200);
        expect(response.body).toMatchObject({
            name: "Mario",
            surname: "Rossi",
            bio: "Loves bouldering",
        });
        expect(new Date(response.body.birthdate).getFullYear()).toBe(1995);
    });

    it("PATCH /users/me returns 400 for username shorter than 3 characters", async () => {
        const climber = await Climber.create({
            email: "short.username@example.com",
            username: "validName",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ username: "ab" });

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(/Username must be between/);
    });

    it("PATCH /users/me returns 400 for username longer than 30 characters", async () => {
        const climber = await Climber.create({
            email: "long.username@example.com",
            username: "validName",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ username: "a".repeat(31) });

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(/Username must be between/);
    });

    it("PATCH /users/me returns 400 for bio exceeding 200 characters", async () => {
        const climber = await Climber.create({
            email: "bio.climber@example.com",
            username: "bioUser",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ bio: "x".repeat(201) });

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(/Bio cannot exceed 200 characters/);
    });

    it("PATCH /users/me returns 400 for invalid birthdate", async () => {
        const climber = await Climber.create({
            email: "date.climber@example.com",
            username: "dateUser",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ birthdate: "not-a-date" });

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(/Invalid birthdate/);
    });

    it("PATCH /users/me returns 400 when no valid fields are provided", async () => {
        const climber = await Climber.create({
            email: "empty.climber@example.com",
            username: "emptyUser",
            password: "Secret123!",
        });
        const token = createAuthToken(climber);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({});

        expect(response.status).toBe(400);
        expect(response.body.error).toMatch(/No valid fields to update/);
    });

    it("PATCH /users/me updates personal fields for FacilityOwner", async () => {
        const owner = await FacilityOwner.create({
            email: "owner.patch@example.com",
            username: "facilityPatch",
            password: "Secret123!",
        });
        const token = createAuthToken(owner);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({
                username: "updatedOwner",
                name: "Anna",
                surname: "Verdi",
                bio: "Manages a climbing gym",
            });

        expect(response.status).toBe(200);
        expect(response.body.username).toBe("updatedowner");
        expect(response.body.name).toBe("Anna");
        expect(response.body.surname).toBe("Verdi");
        expect(response.body.bio).toBe("Manages a climbing gym");
        expect(response.body.birthdate).toBeUndefined();
    });

    it("PATCH /users/me updates bio for PublicBody", async () => {
        const { PublicBody } = require("../../models/User");
        const body = await PublicBody.create({
            email: "publicbody.patch@example.com",
            username: "publicBodyPatch",
            name: "City Council",
            location: { type: "Point", coordinates: [11.0, 46.0] },
            password: "Secret123!",
        });
        const token = createAuthToken(body);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ bio: "Official municipality climbing spots" });

        expect(response.status).toBe(200);
        expect(response.body.bio).toBe("Official municipality climbing spots");
        expect(response.body.surname).toBeUndefined();
        expect(response.body.birthdate).toBeUndefined();
    });

    it("PATCH /users/me does not apply name/surname/birthdate to PublicBody", async () => {
        const { PublicBody } = require("../../models/User");
        const body = await PublicBody.create({
            email: "publicbody.ignored@example.com",
            username: "publicBodyIgnored",
            name: "City Hall",
            location: { type: "Point", coordinates: [11.0, 46.0] },
            password: "Secret123!",
        });
        const token = createAuthToken(body);

        const response = await request(app)
            .patch("/users/me")
            .set("Authorization", `Bearer ${token}`)
            .send({ username: "updatedBody", surname: "ignored", birthdate: "1990-01-01" });

        expect(response.status).toBe(200);
        expect(response.body.username).toBe("updatedbody");
        expect(response.body.surname).toBeUndefined();
        expect(response.body.birthdate).toBeUndefined();
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

describe("POST /users/fcm-token", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    afterEach(async () => {
        await User.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });
    it("returns 204 and stores the token", async () => {
        const climber = await Climber.create({
            email: "fcm@example.com",
            username: "fcmuser",
            userType: "Climber",
            password: "Secret123!",
        });
        const token = createAuthToken({
            _id: { toString: () => climber.id },
            email: climber.email,
            userType: climber.userType,
        });

        const res = await request(app)
            .post("/users/fcm-token")
            .set("Authorization", `Bearer ${token}`)
            .send({ token: "test-fcm-token-abc" });

        expect(res.status).toBe(204);

        const updated = await Climber.findById(climber._id).select("+fcmTokens");
        expect(updated.fcmTokens).toContain("test-fcm-token-abc");
    });

    it("is idempotent — registering the same token twice stores it only once", async () => {
        const climber = await Climber.create({
            email: "fcm2@example.com",
            username: "fcmuser2",
            userType: "Climber",
            password: "Secret123!",
        });
        const token = createAuthToken({
            _id: { toString: () => climber.id },
            email: climber.email,
            userType: climber.userType,
        });

        await request(app)
            .post("/users/fcm-token")
            .set("Authorization", `Bearer ${token}`)
            .send({ token: "dup-token" });

        await request(app)
            .post("/users/fcm-token")
            .set("Authorization", `Bearer ${token}`)
            .send({ token: "dup-token" });

        const updated = await Climber.findById(climber._id).select("+fcmTokens");
        expect(updated.fcmTokens.filter((t) => t === "dup-token")).toHaveLength(1);
    });

    it("returns 400 when token field is missing", async () => {
        const climber = await Climber.create({
            email: "fcm3@example.com",
            username: "fcmuser3",
            userType: "Climber",
            password: "Secret123!",
        });
        const token = createAuthToken({
            _id: { toString: () => climber.id },
            email: climber.email,
            userType: climber.userType,
        });

        const res = await request(app)
            .post("/users/fcm-token")
            .set("Authorization", `Bearer ${token}`)
            .send({});

        expect(res.status).toBe(400);
    });

    it("returns 401 without a JWT", async () => {
        const res = await request(app)
            .post("/users/fcm-token")
            .send({ token: "some-token" });

        expect(res.status).toBe(401);
    });
});
