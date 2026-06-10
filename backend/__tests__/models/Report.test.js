const mongoose = require("mongoose");
const { BaseReport } = require("../../models/Report");
const { Wall, IndoorWall } = require("../../models/Wall");
const Facility = require("../../models/Facility");
const { FacilityOwner } = require("../../models/User");

describe("Report model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
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

    it("should create a report with the required fields", async () => {
        const owner = await FacilityOwner.create({
            email: "facility-report@example.com",
            username: "facilityreport",
            password: "password123",
        });

        const facility = await Facility.create({
            name: "Report Facility",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            ownerAccount: owner._id,
        });

        const wall = await IndoorWall.create({
            name: "Report Wall",
            difficulty: "BEGINNER",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            facility: facility._id,
        });

        const report = await BaseReport.create({
            owner_id: owner._id, // Reports are linked to the User (FacilityOwner)
            wall_id: wall._id,
            title: "Monthly Report",
            notes: "Snapshot for the month",
        });

        expect(report.title).toBe("Monthly Report");
        expect(report.notes).toBe("Snapshot for the month");
        expect(report.owner_id.toString()).toBe(owner._id.toString());
        expect(report.wall_id.toString()).toBe(wall._id.toString());
        expect(report.toJSON().id).toBeDefined();
        expect(report.toJSON()._id).toBeUndefined();
        expect(report.toJSON().__v).toBeUndefined();
    });

    it("should fail validation when title is missing", async () => {
        const owner = await FacilityOwner.create({
            email: "facility-report-missing@example.com",
            username: "facilityreportmissing",
            password: "password123",
        });

        const facility = await Facility.create({
            name: "Report Facility Missing",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            ownerAccount: owner._id,
        });

        const wall = await IndoorWall.create({
            name: "Missing Title Wall",
            difficulty: "BEGINNER",
            location: { type: "Point", coordinates: [12.34, 56.78] },
            facility: facility._id,
        });

        await expect(
            BaseReport.create({
                owner_id: owner._id,
                wall_id: wall._id,
                notes: "Missing title",
            }),
        ).rejects.toThrow(mongoose.Error.ValidationError);
    });

    it("should fail validation when title or notes exceed max length", async () => {
        const owner = await FacilityOwner.create({
            email: "facility-length@example.com",
            username: "facilitylength",
            password: "password123",
        });

        const facility = await Facility.create({
            name: "Length Facility",
            location: { type: "Point", coordinates: [0, 0] },
            ownerAccount: owner._id,
        });

        const wall = await IndoorWall.create({
            name: "Length Wall",
            difficulty: "BEGINNER",
            location: { type: "Point", coordinates: [0, 0] },
            facility: facility._id,
        });

        // Generate a 101 character string
        const longTitle = "a".repeat(101);
        // Generate a 501 character string
        const longNotes = "b".repeat(501);

        // Test long title
        await expect(
            BaseReport.create({
                owner_id: owner._id,
                wall_id: wall._id,
                title: longTitle,
            }),
        ).rejects.toThrow(mongoose.Error.ValidationError);

        // Test long notes
        await expect(
            BaseReport.create({
                owner_id: owner._id,
                wall_id: wall._id,
                title: "Valid Title",
                notes: longNotes,
            }),
        ).rejects.toThrow(mongoose.Error.ValidationError);
    });
});
