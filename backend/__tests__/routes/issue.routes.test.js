const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const issueRoutes = require("../../routes/issue.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { Issue } = require("../../models/Issue");
const { User, Climber, Facility, PublicBody } = require("../../models/User");
const { Wall, IndoorWall, OutdoorWall } = require("../../models/Wall");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/issues", issueRoutes);
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

describe("issue.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Issue.deleteMany({});
        await Wall.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    describe("POST /issues - Create Issue", () => {
        it("should create an issue when climber provides wall_id and body", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wall._id.toString(),
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                issue: expect.objectContaining({
                    id: expect.any(String),
                    climber_id: climber._id.toString(),
                    wall_id: wall._id.toString(),
                    body: "This wall has a broken hold",
                }),
            });

            const stored = await Issue.findById(response.body.issue.id);
            expect(stored).not.toBeNull();
            expect(stored.climber_id.toString()).toBe(climber._id.toString());

            const updatedWall = await IndoorWall.findById(wall._id);
            expect(updatedWall).not.toBeNull();
            expect(
                updatedWall.issues.map((id) => id.toString()),
            ).toContain(response.body.issue.id);
        });

        it("should return 400 when wall_id is missing", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: "wall_id and body are required",
            });
        });

        it("should return 400 when body is missing", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const wallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wallId.toString(),
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: "wall_id and body are required",
            });
        });

        it("should return 400 when wall_id is not a valid ObjectId", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: "invalid-id",
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: "wall_id must be a valid ObjectId",
            });
        });

        it("should return 400 when body is empty", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const wallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wallId.toString(),
                    body: "   ",
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: "body cannot be empty",
            });
        });

        it("should return 400 when body exceeds 500 characters", async () => {
            const climber = await User.create({
                email: "celli@example.com",
                username: "celli",
                userType: "Climber",
                name: "Celli",
                surname: "Test",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const wallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(climber);
            const longBody = "a".repeat(501);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wallId.toString(),
                    body: longBody,
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                error: "body cannot exceed 500 characters",
            });
        });

        it("should return 403 when non-climber tries to create a report", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .post("/issues")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wallId.toString(),
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "Only climbers can create issues",
            });
        });

        it("should return 401 when no authentication token is provided", async () => {
            const wallId = new mongoose.Types.ObjectId();

            const response = await request(app).post("/issues").send({
                wall_id: wallId.toString(),
                body: "This wall has a broken hold",
            });

            expect(response.status).toBe(401);
        });
    });

    describe("GET /issues/walls/:wallId - Get Issues for Wall", () => {
        it("should return all issues for a wall when facility owner requests", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const climber1 = await User.create({
                email: "climber1@example.com",
                username: "climber1",
                userType: "Climber",
                name: "Climber",
                surname: "One",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const climber2 = await User.create({
                email: "climber2@example.com",
                username: "climber2",
                userType: "Climber",
                name: "Climber",
                surname: "Two",
                birthdate: new Date("1992-01-01"),
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: { $each: [wall._id] } },
            });

            await Issue.create({
                climber_id: climber1._id,
                wall_id: wall._id,
                body: "First report",
            });

            await Issue.create({
                climber_id: climber2._id,
                wall_id: wall._id,
                body: "Second report",
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get(`/issues/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                issues: expect.arrayContaining([
                    expect.objectContaining({
                        id: expect.any(String),
                        body: "First report",
                    }),
                    expect.objectContaining({
                        id: expect.any(String),
                        body: "Second report",
                    }),
                ]),
            });
            expect(response.body.issues).toHaveLength(2);
        });

        it("should return empty array when wall has no issues", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: { $each: [wall._id] } },
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get(`/issues/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({ issues: [] });
        });

        it("should return 403 when non-owner tries to access issues for a wall", async () => {
            const facility1 = await User.create({
                email: "facility1@example.com",
                username: "facility1user",
                userType: "Facility",
                name: "Test Facility 1",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const facility2 = await User.create({
                email: "facility2@example.com",
                username: "facility2user",
                userType: "Facility",
                name: "Test Facility 2",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility1._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility1._id, {
                $push: { walls: { $each: [wall._id] } },
            });

            const accessToken = createAuthToken(facility2);

            const response = await request(app)
                .get(`/issues/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "You can only access issues for walls you own",
            });
        });

        it("should return 403 when climber tries to access issues for a wall", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .get(`/issues/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
        });

        it("should return 404 when wall does not exist", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const nonExistentWallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get(`/issues/walls/${nonExistentWallId.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                error: "Wall not found",
            });
        });

        it("should return 400 when wallId is invalid ObjectId", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get("/issues/walls/invalid-id")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(400);
        });
    });

    describe("GET /issues/my-issues - Get Issues by Climber", () => {
        it("should return all issues created by the climber", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall1 = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall 1",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            const wall2 = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall 2",
                location: {
                    type: "Point",
                    coordinates: [11.5, 21.5],
                },
                difficulty: "ADVANCED",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: [wall1._id, wall2._id] },
            });

            await Issue.create({
                climber_id: climber._id,
                wall_id: wall1._id,
                body: "First report",
            });

            await Issue.create({
                climber_id: climber._id,
                wall_id: wall2._id,
                body: "Second report",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .get("/issues/my-issues")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                issues: expect.arrayContaining([
                    expect.objectContaining({
                        id: expect.any(String),
                        body: "First report",
                    }),
                    expect.objectContaining({
                        id: expect.any(String),
                        body: "Second report",
                    }),
                ]),
            });
            expect(response.body.issues).toHaveLength(2);
        });

        it("should return empty array when climber has no issues", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .get("/issues/my-issues")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({ issues: [] });
        });

        it("should return 401 when no authentication token is provided", async () => {
            const response = await request(app).get("/issues/my-issues");

            expect(response.status).toBe(401);
        });
    });

    describe("PATCH /issues/:issueId/status - Update Issue Status", () => {
        it("should update the issue status and return the updated issue in an issues array", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Facility",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                authMethods: ["local"],
            });

            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: wall._id },
            });

            const issue = await Issue.create({
                climber_id: climber._id,
                wall_id: wall._id,
                body: "This wall has a broken hold",
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .patch(`/issues/${issue._id.toString()}/status`)
                .set("Authorization", `Bearer ${accessToken}`)
                .send({ status: "IN_PROGRESS" });

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                issues: [
                    expect.objectContaining({
                        id: issue._id.toString(),
                        climber_id: climber._id.toString(),
                        wall_id: wall._id.toString(),
                        body: "This wall has a broken hold",
                        status: "IN_PROGRESS",
                    }),
                ],
            });
        });
    });

    describe("DELETE /issues/:issueId - Delete Issue", () => {
        it("should delete an issue when the climber who created it requests deletion", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: wall._id },
            });

            const report = await Issue.create({
                climber_id: climber._id,
                wall_id: wall._id,
                body: "Test report",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .delete(`/issues/${report._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(204);

            const deletedIssue = await Issue.findById(report._id);
            expect(deletedIssue).toBeNull();
        });

        it("should return 403 when a different climber tries to delete an issue", async () => {
            const climber1 = await User.create({
                email: "climber1@example.com",
                username: "climber1",
                userType: "Climber",
                name: "Climber",
                surname: "One",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const climber2 = await User.create({
                email: "climber2@example.com",
                username: "climber2",
                userType: "Climber",
                name: "Climber",
                surname: "Two",
                birthdate: new Date("1992-01-01"),
                authMethods: ["local"],
            });

            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                    location: {
                        type: "Point",
                        coordinates: [10.5, 20.5],
                    },
                authMethods: ["local"],
            });

            const wall = await IndoorWall.create({
                facility: facility._id,
                name: "Test Wall",
                location: {
                    type: "Point",
                    coordinates: [10.5, 20.5],
                },
                difficulty: "INTERMEDIATE",
            });

            await User.findByIdAndUpdate(facility._id, {
                $push: { walls: wall._id },
            });

            const report = await Issue.create({
                climber_id: climber1._id,
                wall_id: wall._id,
                body: "Test report",
            });

            const accessToken = createAuthToken(climber2);

            const response = await request(app)
                .delete(`/issues/${report._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "You can only delete your own issues",
            });

            const issueStillExists = await Issue.findById(report._id);
            expect(issueStillExists).not.toBeNull();
        });

        it("should return 404 when issue does not exist", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const nonExistentIssueId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .delete(`/issues/${nonExistentIssueId.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                error: "Issue not found",
            });
        });

        it("should return 400 when issueId is invalid ObjectId", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .delete("/issues/invalid-id")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(400);
        });

        it("should return 401 when no authentication token is provided", async () => {
            const issueId = new mongoose.Types.ObjectId();

            const response = await request(app).delete(
                `/issues/${issueId.toString()}`,
            );

            expect(response.status).toBe(401);
        });
    });
});
