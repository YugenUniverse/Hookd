const mongoose = require("mongoose");
const User = require("../../models/User");
const RefreshToken = require("../../models/RefreshToken");

jest.setTimeout(30000);

describe("RefreshToken model", () => {
    let testUser;

    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    beforeEach(async () => {
        testUser = await User.create({
            email: "test@example.com",
            username: "testuser",
            password: "TestPassword123!",
        });
    });

    afterEach(async () => {
        await RefreshToken.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a valid refresh token", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = await RefreshToken.create({
            tokenId: "unique-token-id-123",
            userId: testUser._id,
            expiresAt,
        });

        expect(token).toBeDefined();
        expect(token.tokenId).toBe("unique-token-id-123");
        expect(token.userId.toString()).toBe(testUser._id.toString());
        expect(token.expiresAt).toEqual(expiresAt);
        expect(token.revokedAt).toBeNull();
        expect(token.createdAt).toBeDefined();
        expect(token.updatedAt).toBeDefined();
    });

    it("enforces unique tokenId constraint", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await RefreshToken.create({
            tokenId: "duplicate-token-id",
            userId: testUser._id,
            expiresAt,
        });

        await expect(
            RefreshToken.create({
                tokenId: "duplicate-token-id",
                userId: testUser._id,
                expiresAt,
            }),
        ).rejects.toThrow();
    });

    it("requires tokenId", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = new RefreshToken({
            userId: testUser._id,
            expiresAt,
        });

        await expect(token.save()).rejects.toThrow();
    });

    it("requires userId", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = new RefreshToken({
            tokenId: "token-id-no-user",
            expiresAt,
        });

        await expect(token.save()).rejects.toThrow();
    });

    it("requires expiresAt", async () => {
        const token = new RefreshToken({
            tokenId: "token-id-no-expiry",
            userId: testUser._id,
        });

        await expect(token.save()).rejects.toThrow();
    });

    it("defaults revokedAt to null", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = await RefreshToken.create({
            tokenId: "test-token-revoke",
            userId: testUser._id,
            expiresAt,
        });

        expect(token.revokedAt).toBeNull();
    });

    it("can update revokedAt", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = await RefreshToken.create({
            tokenId: "test-token-to-revoke",
            userId: testUser._id,
            expiresAt,
        });

        const revokedAt = new Date();
        token.revokedAt = revokedAt;
        await token.save();

        const updatedToken = await RefreshToken.findById(token._id);
        expect(updatedToken.revokedAt).toBeDefined();
        expect(updatedToken.revokedAt.getTime()).toBeCloseTo(
            revokedAt.getTime(),
            -2,
        );
    });

    it("finds refresh token by tokenId", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const tokenId = "findable-token-id";
        await RefreshToken.create({
            tokenId,
            userId: testUser._id,
            expiresAt,
        });

        const found = await RefreshToken.findOne({ tokenId });
        expect(found).toBeDefined();
        expect(found.tokenId).toBe(tokenId);
        expect(found.userId.toString()).toBe(testUser._id.toString());
    });

    it("populates userId reference", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await RefreshToken.create({
            tokenId: "token-with-populated-user",
            userId: testUser._id,
            expiresAt,
        });

        const token = await RefreshToken.findOne({
            tokenId: "token-with-populated-user",
        }).populate("userId");

        expect(token.userId).toBeDefined();
        expect(token.userId.email).toBe("test@example.com");
        expect(token.userId.username).toBe("testuser");
    });

    it("finds non-revoked tokens", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const activeToken = await RefreshToken.create({
            tokenId: "active-token",
            userId: testUser._id,
            expiresAt,
        });

        const revokedToken = await RefreshToken.create({
            tokenId: "revoked-token",
            userId: testUser._id,
            expiresAt,
            revokedAt: new Date(),
        });

        const nonRevokedTokens = await RefreshToken.find({
            revokedAt: null,
        });

        expect(nonRevokedTokens.length).toBe(1);
        expect(nonRevokedTokens[0].tokenId).toBe("active-token");
    });

    it("finds non-expired tokens", async () => {
        const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const pastDate = new Date(Date.now() - 1000);

        const validToken = await RefreshToken.create({
            tokenId: "valid-expiry-token",
            userId: testUser._id,
            expiresAt: futureDate,
        });

        const expiredToken = await RefreshToken.create({
            tokenId: "expired-token",
            userId: testUser._id,
            expiresAt: pastDate,
        });

        const nonExpiredTokens = await RefreshToken.find({
            expiresAt: { $gt: new Date() },
        });

        expect(nonExpiredTokens.length).toBe(1);
        expect(nonExpiredTokens[0].tokenId).toBe("valid-expiry-token");
    });

    it("can update a token with multiple conditions", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const token = await RefreshToken.create({
            tokenId: "multi-condition-token",
            userId: testUser._id,
            expiresAt,
        });

        const updated = await RefreshToken.updateOne(
            { tokenId: "multi-condition-token", revokedAt: null },
            { $set: { revokedAt: new Date() } },
        );

        expect(updated.modifiedCount).toBe(1);

        const revokedToken = await RefreshToken.findOne({
            tokenId: "multi-condition-token",
        });
        expect(revokedToken.revokedAt).toBeTruthy();
    });

    it("does not update already revoked tokens", async () => {
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        const revokedDate = new Date();
        await RefreshToken.create({
            tokenId: "already-revoked-token",
            userId: testUser._id,
            expiresAt,
            revokedAt: revokedDate,
        });

        const updated = await RefreshToken.updateOne(
            { tokenId: "already-revoked-token", revokedAt: null },
            { $set: { revokedAt: new Date() } },
        );

        expect(updated.modifiedCount).toBe(0);
    });
});
