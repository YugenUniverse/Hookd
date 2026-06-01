const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const followRoutes = require("../../routes/follow.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User, Climber } = require("../../models/User");
const Follow = require("../../models/Follow");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/follows", followRoutes);
app.use(errorMiddleware);

const makeToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

describe("follow.routes", () => {
    let alice, bob, carol;
    let tokenAlice, tokenBob;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    beforeEach(async () => {
        alice = await Climber.create({ email: "alice@test.com", username: "alice" });
        bob = await Climber.create({ email: "bob@test.com", username: "bob" });
        carol = await Climber.create({ email: "carol@test.com", username: "carol" });
        tokenAlice = makeToken(alice);
        tokenBob = makeToken(bob);
    });

    afterEach(async () => {
        await Follow.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    describe("POST /follows/:targetId", () => {
        it("follows a user and returns 200", async () => {
            const res = await request(app)
                .post(`/follows/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.message).toBe("Followed");
            const doc = await Follow.findOne({ follower: alice._id, following: bob._id });
            expect(doc).not.toBeNull();
        });

        it("is idempotent — following twice does not error", async () => {
            await request(app)
                .post(`/follows/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);
            const res = await request(app)
                .post(`/follows/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            const count = await Follow.countDocuments({ follower: alice._id, following: bob._id });
            expect(count).toBe(1);
        });

        it("returns 400 when trying to follow yourself", async () => {
            const res = await request(app)
                .post(`/follows/${alice._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(400);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).post(`/follows/${bob._id}`);
            expect(res.status).toBe(401);
        });
    });

    describe("DELETE /follows/:targetId", () => {
        it("unfollows a user and returns 200", async () => {
            await Follow.create({ follower: alice._id, following: bob._id });

            const res = await request(app)
                .delete(`/follows/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.message).toBe("Unfollowed");
            const doc = await Follow.findOne({ follower: alice._id, following: bob._id });
            expect(doc).toBeNull();
        });

        it("is idempotent — unfollowing a non-followed user does not error", async () => {
            const res = await request(app)
                .delete(`/follows/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).delete(`/follows/${bob._id}`);
            expect(res.status).toBe(401);
        });
    });

    describe("GET /follows/check/:targetId", () => {
        it("returns {following: true} when alice follows bob", async () => {
            await Follow.create({ follower: alice._id, following: bob._id });

            const res = await request(app)
                .get(`/follows/check/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.following).toBe(true);
        });

        it("returns {following: false} when alice does not follow bob", async () => {
            const res = await request(app)
                .get(`/follows/check/${bob._id}`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.following).toBe(false);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get(`/follows/check/${bob._id}`);
            expect(res.status).toBe(401);
        });
    });

    describe("GET /follows/me", () => {
        it("returns users that the current user follows", async () => {
            await Follow.create({ follower: alice._id, following: bob._id });
            await Follow.create({ follower: alice._id, following: carol._id });

            const res = await request(app)
                .get("/follows/me")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.following).toHaveLength(2);
            const ids = res.body.following.map((u) => u.id);
            expect(ids).toContain(bob.id);
            expect(ids).toContain(carol.id);
        });

        it("returns empty array when not following anyone", async () => {
            const res = await request(app)
                .get("/follows/me")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.following).toEqual([]);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get("/follows/me");
            expect(res.status).toBe(401);
        });
    });

    describe("GET /follows/me/followers", () => {
        it("returns followers of the current user", async () => {
            await Follow.create({ follower: bob._id, following: alice._id });
            await Follow.create({ follower: carol._id, following: alice._id });

            const res = await request(app)
                .get("/follows/me/followers")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.followers).toHaveLength(2);
        });

        it("returns empty array when user has no followers", async () => {
            const res = await request(app)
                .get("/follows/me/followers")
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.followers).toEqual([]);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get("/follows/me/followers");
            expect(res.status).toBe(401);
        });
    });

    describe("GET /follows/:userId/followers", () => {
        it("returns followers of a given user", async () => {
            await Follow.create({ follower: alice._id, following: bob._id });

            const res = await request(app)
                .get(`/follows/${bob._id}/followers`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.followers).toHaveLength(1);
            expect(res.body.followers[0].id).toBe(alice.id);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get(`/follows/${bob._id}/followers`);
            expect(res.status).toBe(401);
        });
    });

    describe("GET /follows/:userId/following", () => {
        it("returns users that a given user follows", async () => {
            await Follow.create({ follower: alice._id, following: bob._id });
            await Follow.create({ follower: alice._id, following: carol._id });

            const res = await request(app)
                .get(`/follows/${alice._id}/following`)
                .set("Authorization", `Bearer ${tokenAlice}`);

            expect(res.status).toBe(200);
            expect(res.body.following).toHaveLength(2);
        });

        it("returns 401 without a JWT", async () => {
            const res = await request(app).get(`/follows/${alice._id}/following`);
            expect(res.status).toBe(401);
        });
    });
});
