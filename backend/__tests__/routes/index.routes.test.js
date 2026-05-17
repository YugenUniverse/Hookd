const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");

const indexRoutes = require("../../routes/index");
const errorMiddleware = require("../../middleware/error.middleware");
const { User } = require("../../models/User");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/", indexRoutes);
app.use(errorMiddleware);

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

describe("index.routes", () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

    it("GET / requires authentication", async () => {
        const response = await request(app).get("/");

        expect(response.status).toBe(401);
        expect(response.body).toEqual({
            error: expect.stringContaining("Missing or invalid Authorization header"),
        });
    });

    it("GET / returns users when authenticated", async () => {
        const users = [
            {
                _id: "user-1",
                email: "protected@example.com",
            },
        ];
        jest.spyOn(User, "find").mockResolvedValue(users);

        const token = createAuthToken({
            _id: { toString: () => "user-1" },
            email: "protected@example.com",
            userType: "Climber",
        });

        const response = await request(app)
            .get("/")
            .set("Authorization", `Bearer ${token}`);

        expect(response.status).toBe(200);
        expect(response.body).toEqual(users);
    });
});
