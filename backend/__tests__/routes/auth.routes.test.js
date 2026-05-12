const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const authRoutes = require("../../routes/auth.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User } = require("../../models/User");
const RefreshToken = require("../../models/RefreshToken");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";
process.env.REFRESH_TOKEN_SECRET =
    process.env.REFRESH_TOKEN_SECRET || process.env.JWT_SECRET;

const app = express();
app.use(express.json());
app.use("/auth", authRoutes);
app.use(errorMiddleware);

const registerPayload = {
    email: "celli@example.com",
    username: "celli",
    password: "Celli123!",
};

describe("auth.routes", () => {
    beforeAll(async () => {
        // Suppress expected error logs during testing
        jest.spyOn(console, "error").mockImplementation(() => {});

        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await User.deleteMany({});
        await RefreshToken.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    it("POST /auth/register creates a new user", async () => {
        const response = await request(app)
            .post("/auth/register")
            .send(registerPayload);

        expect(response.status).toBe(201);
        expect(response.body).toEqual({
            message: "User created",
            user: expect.objectContaining({
                id: expect.any(String),
                email: "celli@example.com",
            }),
        });
    });

    it("POST /auth/login returns access and refresh tokens", async () => {
        await request(app).post("/auth/register").send(registerPayload);

        const response = await request(app).post("/auth/login").send({
            email: registerPayload.email,
            password: registerPayload.password,
        });

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            message: "Login successful",
            accessToken: expect.any(String),
            refreshToken: expect.any(String),
        });
    });

    it("POST /auth/refresh returns new tokens using a valid refresh token", async () => {
        await request(app).post("/auth/register").send(registerPayload);
        const loginResponse = await request(app).post("/auth/login").send({
            email: registerPayload.email,
            password: registerPayload.password,
        });

        const response = await request(app)
            .post("/auth/refresh")
            .send({ refreshToken: loginResponse.body.refreshToken });

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            message: "Token refreshed",
            accessToken: expect.any(String),
            refreshToken: expect.any(String),
        });
        expect(response.body.refreshToken).not.toBe(
            loginResponse.body.refreshToken,
        );
    });

    it("POST /auth/logout revokes the provided refresh token", async () => {
        await request(app).post("/auth/register").send(registerPayload);
        const loginResponse = await request(app).post("/auth/login").send({
            email: registerPayload.email,
            password: registerPayload.password,
        });

        const response = await request(app)
            .post("/auth/logout")
            .send({ refreshToken: loginResponse.body.refreshToken });

        expect(response.status).toBe(200);
        expect(response.body).toEqual({ message: "Logged out" });

        const payload = jwt.verify(
            loginResponse.body.refreshToken,
            process.env.REFRESH_TOKEN_SECRET,
            {
                issuer: "hookd",
                ignoreExpiration: true,
            },
        );

        const revokedToken = await RefreshToken.findOne({
            tokenId: payload.jti,
        });
        expect(revokedToken).toBeTruthy();
        expect(revokedToken.revokedAt).toBeTruthy();
    });

    it("GET /auth/me returns the authenticated user", async () => {
        await request(app).post("/auth/register").send(registerPayload);
        const loginResponse = await request(app).post("/auth/login").send({
            email: registerPayload.email,
            password: registerPayload.password,
        });

        const response = await request(app)
            .get("/auth/me")
            .set("Authorization", `Bearer ${loginResponse.body.accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            user: expect.objectContaining({
                id: expect.any(String),
                email: registerPayload.email,
            }),
        });
    });

    /** VALIDATION TESTS **/
    describe("Register validation", () => {
        it("POST /auth/register fails when email is missing", async () => {
            const response = await request(app)
                .post("/auth/register")
                .send({ username: "celli", password: "Celli123!" });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing fields"),
            });
        });

        it("POST /auth/register fails when password is missing", async () => {
            const response = await request(app)
                .post("/auth/register")
                .send({ email: "test@example.com", username: "tester" });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing fields"),
            });
        });

        it("POST /auth/register fails when username is missing", async () => {
            const response = await request(app).post("/auth/register").send({
                email: "test@example.com",
                password: "Celli123!",
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing fields"),
            });
        });

        it("POST /auth/register fails when email already exists", async () => {
            await request(app).post("/auth/register").send(registerPayload);

            const response = await request(app)
                .post("/auth/register")
                .send(registerPayload);

            expect(response.status).toBe(409);
            expect(response.body).toEqual({
                error: expect.stringContaining("User already exists"),
            });
        });
    });

    describe("Login validation", () => {
        it("POST /auth/login fails when email is missing", async () => {
            const response = await request(app)
                .post("/auth/login")
                .send({ password: "Celli123!" });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing fields"),
            });
        });

        it("POST /auth/login fails when password is missing", async () => {
            const response = await request(app)
                .post("/auth/login")
                .send({ email: "celli@example.com" });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing fields"),
            });
        });

        it("POST /auth/login fails when user does not exist", async () => {
            const response = await request(app).post("/auth/login").send({
                email: "nonexistent@example.com",
                password: "Celli123!",
            });

            expect(response.status).toBe(401);
            expect(response.body).toEqual({
                error: expect.stringContaining("Invalid credentials"),
            });
        });

        it("POST /auth/login fails when password is wrong", async () => {
            await request(app).post("/auth/register").send(registerPayload);

            const response = await request(app).post("/auth/login").send({
                email: registerPayload.email,
                password: "WrongPassword123!",
            });

            expect(response.status).toBe(401);
            expect(response.body).toEqual({
                error: expect.stringContaining("Invalid credentials"),
            });
        });
    });

    describe("Refresh token validation", () => {
        it("POST /auth/refresh fails when refreshToken is missing", async () => {
            const response = await request(app).post("/auth/refresh").send({});

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: expect.stringContaining("Refresh token is required"),
            });
        });

        it("POST /auth/refresh fails when refreshToken is invalid", async () => {
            const response = await request(app)
                .post("/auth/refresh")
                .send({ refreshToken: "invalid-token" });

            expect(response.status).toBe(401);
        });
    });

    describe("GET /auth/me validation", () => {
        it("GET /auth/me fails without Authorization header", async () => {
            const response = await request(app).get("/auth/me");

            expect(response.status).toBe(401);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing or invalid"),
            });
        });

        it("GET /auth/me fails with invalid token", async () => {
            const response = await request(app)
                .get("/auth/me")
                .set("Authorization", "Bearer invalid-token");

            expect(response.status).toBe(401);
        });

        it("GET /auth/me fails with missing Bearer prefix", async () => {
            const response = await request(app)
                .get("/auth/me")
                .set("Authorization", "InvalidToken");

            expect(response.status).toBe(401);
            expect(response.body).toEqual({
                error: expect.stringContaining("Missing or invalid"),
            });
        });
    });
});
