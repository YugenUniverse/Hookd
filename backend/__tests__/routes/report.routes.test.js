const express = require("express");
const request = require("supertest");
const mongoose = require("mongoose");

const reportRoutes = require("../../routes/report.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { BaseReport } = require("../../models/Report");
const { Wall, IndoorWall } = require("../../models/Wall");
const Facility = require("../../models/Facility");
const { FacilityOwner } = require("../../models/User");

jest.mock("../../middleware/auth.middleware", () => ({
    authenticateJwt: (req, res, next) => {
        req.user = {
            id: "60d5ecdec021f13528e01369",
            userType: "FacilityOwner",
        };
        next();
    },
    restrictTo:
        (...roles) =>
        (req, res, next) =>
            next(),
}));

const app = express();
app.use(express.json());
app.use("/reports", reportRoutes);
app.use(errorMiddleware);

describe("Report Routes", () => {
    let owner;
    let facility;
    let wall;

    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    beforeEach(async () => {
        // 👇 UPDATE 2: Create the User document with the mocked ID
        owner = await FacilityOwner.create({
            _id: "60d5ecdec021f13528e01369",
            email: "report-facility@example.com",
            username: "reportfacility",
            password: "password123",
        });

        // 👇 UPDATE 3: Create the Facility profile linked to the User
        facility = await Facility.create({
            name: "Report Facility",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            ownerAccount: owner._id,
        });

        // The wall attaches to the Facility profile
        wall = await IndoorWall.create({
            name: "Report Wall",
            difficulty: "BEGINNER",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            facility: facility._id,
        });
    });

    afterEach(async () => {
        await BaseReport.deleteMany({});
        await Wall.deleteMany({});
        await Facility.deleteMany({});
        await FacilityOwner.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("GET /reports/wall/:wallId returns report data structure for an existing wall", async () => {
        const response = await request(app).get(`/reports/wall/${wall._id}`);

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty("engagement");
        expect(response.body).toHaveProperty("quality");
        expect(response.body.engagement.totalSessions).toBe(0);
        expect(response.body.quality.avgRating).toBe(0);
    });

    it("POST /reports/wall/:wallId/save should create a saved report", async () => {
        const response = await request(app)
            .post(`/reports/wall/${wall._id}/save`)
            .send({ title: "Monthly Snapshot", notes: "Monthly report save" });

        expect(response.status).toBe(201);
        expect(response.body).toHaveProperty("report");
        expect(response.body.report.title).toBe("Monthly Snapshot");
    });

    it("POST /reports/walls/save should create a group saved report for multiple walls", async () => {
        const wall2 = await IndoorWall.create({
            name: "Report Wall 2",
            difficulty: "INTERMEDIATE",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            facility: facility._id,
        });

        const response = await request(app)
            .post("/reports/walls/save")
            .send({
                wallIds: [wall._id.toString(), wall2._id.toString()],
                title: "Group Snapshot",
                notes: "Multiple wall group report",
            });

        expect(response.status).toBe(201);
        expect(response.body).toHaveProperty("report");
        expect(response.body.report.title).toBe("Group Snapshot");
        expect(response.body.report.wall_ids).toHaveLength(2);
        expect(response.body.report.reportData.wallComparisons).toHaveLength(2);
        expect(
            response.body.report.reportData.wallComparisons[0],
        ).toHaveProperty("wallName");
    });

    it("GET /reports/saved should return saved reports list", async () => {
        const saved = await BaseReport.create({
            owner_id: owner._id, // Reports belong to the User
            wall_id: wall._id,
            title: "Saved Report",
            notes: "Report notes",
        });

        const response = await request(app).get("/reports/saved");

        expect(response.status).toBe(200);
        expect(Array.isArray(response.body)).toBe(true);
        expect(response.body[0].id).toBe(saved._id.toString());
    });

    it("GET /reports/saved/:id should return a report with wall details", async () => {
        const saved = await BaseReport.create({
            owner_id: owner._id,
            wall_id: wall._id,
            title: "Saved Report",
            notes: "Report notes",
        });

        const response = await request(app).get(`/reports/saved/${saved._id}`);

        expect(response.status).toBe(200);
        expect(response.body.id).toBe(saved._id.toString());
        expect(response.body.wall_id).toHaveProperty("name", "Report Wall");
    });

    it("DELETE /reports/saved/:id should remove the saved report", async () => {
        const saved = await BaseReport.create({
            owner_id: owner._id,
            wall_id: wall._id,
            title: "Saved Report",
            notes: "Report notes",
        });

        const response = await request(app).delete(
            `/reports/saved/${saved._id}`,
        );

        expect(response.status).toBe(200);
        expect(response.body.message).toBe("Report deleted successfully");

        const missing = await BaseReport.findById(saved._id);
        expect(missing).toBeNull();
    });

    it("POST /reports/wall/:wallId/save returns 400 when title is missing", async () => {
        const response = await request(app)
            .post(`/reports/wall/${wall._id}/save`)
            .send({ notes: "No title" });

        expect(response.status).toBe(400);
        expect(response.body.message).toBe(
            "A title is required to save a report.",
        );
    });

    it("GET /reports/wall/:wallId returns 403 if FacilityOwner does not own the wall", async () => {
        // Create an entirely separate owner, facility, and wall
        const otherOwner = await FacilityOwner.create({
            email: "other@example.com",
            username: "other",
            password: "password123",
        });

        const otherFacility = await Facility.create({
            name: "Other Facility",
            location: { type: "Point", coordinates: [0, 0] },
            ownerAccount: otherOwner._id,
        });

        const otherWall = await IndoorWall.create({
            name: "Someone Else's Wall",
            difficulty: "ADVANCED",
            location: { type: "Point", coordinates: [0, 0] },
            facility: otherFacility._id,
        });

        // The mocked user tries to fetch someone else's wall
        const response = await request(app).get(
            `/reports/wall/${otherWall._id}`,
        );

        expect(response.status).toBe(403);
        expect(response.body.message).toBe(
            "You do not have permission to view reports for this wall.",
        );
    });

    it("POST /reports/wall/:wallId/save returns 403 if FacilityOwner does not own the wall", async () => {
        const otherOwner = await FacilityOwner.create({
            email: "other2@example.com",
            username: "other2",
            password: "password123",
        });

        const otherFacility = await Facility.create({
            name: "Other Facility 2",
            location: { type: "Point", coordinates: [0, 0] },
            ownerAccount: otherOwner._id,
        });

        const otherWall = await IndoorWall.create({
            name: "Someone Else's Wall 2",
            difficulty: "ADVANCED",
            location: { type: "Point", coordinates: [0, 0] },
            facility: otherFacility._id,
        });

        const response = await request(app)
            .post(`/reports/wall/${otherWall._id}/save`)
            .send({ title: "Stealing Data" });

        expect(response.status).toBe(403);
    });

    it("GET /reports/wall/:wallId returns 404 for a non-existent wall", async () => {
        const fakeId = new mongoose.Types.ObjectId();
        const response = await request(app).get(`/reports/wall/${fakeId}`);

        expect(response.status).toBe(404);
        expect(response.body.message).toBe("Wall not found");
    });

    it("DELETE /reports/saved/:id returns 404 for a non-existent report", async () => {
        const fakeReportId = new mongoose.Types.ObjectId();
        const response = await request(app).delete(
            `/reports/saved/${fakeReportId}`,
        );

        expect(response.status).toBe(404);
    });
});
