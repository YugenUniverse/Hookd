const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const reportRoutes = require("../../routes/report.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { IssueReport } = require("../../models/IssueReport");
const { User, Climber, Facility, PublicBody } = require("../../models/User");
const { Wall, IndoorWall, OutdoorWall } = require("../../models/Wall");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/reports", reportRoutes);
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

describe("report.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await IssueReport.deleteMany({});
        await Wall.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    describe("POST /reports - Create Issue Report", () => {
        it("should create an issue report when climber provides wall_id and body", async () => {
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
                .post("/reports")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wall._id.toString(),
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                report: expect.objectContaining({
                    id: expect.any(String),
                    climber_id: climber._id.toString(),
                    wall_id: wall._id.toString(),
                    body: "This wall has a broken hold",
                }),
            });

            const stored = await IssueReport.findById(response.body.report.id);
            expect(stored).not.toBeNull();
            expect(stored.climber_id.toString()).toBe(climber._id.toString());
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
                .post("/reports")
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
                .post("/reports")
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
                .post("/reports")
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
                .post("/reports")
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
                .post("/reports")
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
                authMethods: ["local"],
            });

            const wallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .post("/reports")
                .set("Authorization", `Bearer ${accessToken}`)
                .send({
                    wall_id: wallId.toString(),
                    body: "This wall has a broken hold",
                });

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "Only climbers can create reports",
            });
        });

        it("should return 401 when no authentication token is provided", async () => {
            const wallId = new mongoose.Types.ObjectId();

            const response = await request(app).post("/reports").send({
                wall_id: wallId.toString(),
                body: "This wall has a broken hold",
            });

            expect(response.status).toBe(401);
        });
    });

    describe("GET /reports/walls/:wallId - Get Issue Reports for Wall", () => {
        it("should return all reports for a wall when facility owner requests", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
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

            await IssueReport.create({
                climber_id: climber1._id,
                wall_id: wall._id,
                body: "First report",
            });

            await IssueReport.create({
                climber_id: climber2._id,
                wall_id: wall._id,
                body: "Second report",
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get(`/reports/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                reports: expect.arrayContaining([
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
            expect(response.body.reports).toHaveLength(2);
        });

        it("should return empty array when wall has no reports", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
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
                .get(`/reports/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({ reports: [] });
        });

        it("should return 403 when non-owner tries to access reports for a wall", async () => {
            const facility1 = await User.create({
                email: "facility1@example.com",
                username: "facility1user",
                userType: "Facility",
                name: "Test Facility 1",
                authMethods: ["local"],
            });

            const facility2 = await User.create({
                email: "facility2@example.com",
                username: "facility2user",
                userType: "Facility",
                name: "Test Facility 2",
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
                .get(`/reports/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "You can only access reports for walls you own",
            });
        });

        it("should return 403 when climber tries to access reports for a wall", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
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
                .get(`/reports/walls/${wall._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
        });

        it("should return 404 when wall does not exist", async () => {
            const facility = await User.create({
                email: "facility@example.com",
                username: "facilityuser",
                userType: "Facility",
                name: "Test Facility",
                authMethods: ["local"],
            });

            const nonExistentWallId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get(`/reports/walls/${nonExistentWallId.toString()}`)
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
                authMethods: ["local"],
            });

            const accessToken = createAuthToken(facility);

            const response = await request(app)
                .get("/reports/walls/invalid-id")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(400);
        });
    });

    describe("GET /reports/my-reports - Get Issue Reports by Climber", () => {
        it("should return all reports created by the climber", async () => {
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

            await IssueReport.create({
                climber_id: climber._id,
                wall_id: wall1._id,
                body: "First report",
            });

            await IssueReport.create({
                climber_id: climber._id,
                wall_id: wall2._id,
                body: "Second report",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .get("/reports/my-reports")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                reports: expect.arrayContaining([
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
            expect(response.body.reports).toHaveLength(2);
        });

        it("should return empty array when climber has no reports", async () => {
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
                .get("/reports/my-reports")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual({ reports: [] });
        });

        it("should return 401 when no authentication token is provided", async () => {
            const response = await request(app).get("/reports/my-reports");

            expect(response.status).toBe(401);
        });
    });

    describe("DELETE /reports/:reportId - Delete Issue Report", () => {
        it("should delete a report when the climber who created it requests deletion", async () => {
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

            const report = await IssueReport.create({
                climber_id: climber._id,
                wall_id: wall._id,
                body: "Test report",
            });

            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .delete(`/reports/${report._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(204);

            const deletedReport = await IssueReport.findById(report._id);
            expect(deletedReport).toBeNull();
        });

        it("should return 403 when a different climber tries to delete a report", async () => {
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

            const report = await IssueReport.create({
                climber_id: climber1._id,
                wall_id: wall._id,
                body: "Test report",
            });

            const accessToken = createAuthToken(climber2);

            const response = await request(app)
                .delete(`/reports/${report._id.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                error: "You can only delete your own reports",
            });

            const reportStillExists = await IssueReport.findById(report._id);
            expect(reportStillExists).not.toBeNull();
        });

        it("should return 404 when report does not exist", async () => {
            const climber = await User.create({
                email: "climber@example.com",
                username: "climberuser",
                userType: "Climber",
                name: "Climber",
                surname: "User",
                birthdate: new Date("1990-01-01"),
                authMethods: ["local"],
            });

            const nonExistentReportId = new mongoose.Types.ObjectId();
            const accessToken = createAuthToken(climber);

            const response = await request(app)
                .delete(`/reports/${nonExistentReportId.toString()}`)
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                error: "IssueReport not found",
            });
        });

        it("should return 400 when reportId is invalid ObjectId", async () => {
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
                .delete("/reports/invalid-id")
                .set("Authorization", `Bearer ${accessToken}`);

            expect(response.status).toBe(400);
        });

        it("should return 401 when no authentication token is provided", async () => {
            const reportId = new mongoose.Types.ObjectId();

            const response = await request(app).delete(
                `/reports/${reportId.toString()}`,
            );

            expect(response.status).toBe(401);
        });
    });
});
