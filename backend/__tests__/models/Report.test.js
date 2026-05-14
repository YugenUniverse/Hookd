const mongoose = require("mongoose");
const Report = require("../../models/Report");

jest.setTimeout(30000);

describe("Report model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Report.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a report with valid data", async () => {
        const reportBody = "Example report body";

        const report = new Report({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            body: reportBody,
        });

        await report.save();

        const foundReport = await Report.findById(report._id);

        expect(foundReport).not.toBeNull();
        expect(foundReport.climber_id.toString()).toBe(
            report.climber_id.toString(),
        );
        expect(foundReport.wall_id.toString()).toBe(report.wall_id.toString());
        expect(foundReport.body).toBe(reportBody);
    });

    it("requires climber_id, wall_id, and body", async () => {
        const report = new Report();

        let error = null;
        try {
            await report.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.climber_id).toBeDefined();
        expect(error.errors.wall_id).toBeDefined();
        expect(error.errors.body).toBeDefined();
    });

    it("trims body and enforces max length", async () => {
        const longBody = "a".repeat(501);
        const report = new Report({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            body: longBody,
        });

        let error = null;
        try {
            await report.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.body).toBeDefined();
    });
});
