const mongoose = require("mongoose");
const { IssueReport } = require("../../models/IssueReport");

jest.setTimeout(30000);

describe("IssueReport model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await IssueReport.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a report with valid data", async () => {
        const reportBody = "Example report body";

        const report = new IssueReport({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            body: reportBody,
        });

        await report.save();

        const foundIssueReport = await IssueReport.findById(report._id);

        expect(foundIssueReport).not.toBeNull();
        expect(foundIssueReport.climber_id.toString()).toBe(
            report.climber_id.toString(),
        );
        expect(foundIssueReport.wall_id.toString()).toBe(
            report.wall_id.toString(),
        );
        expect(foundIssueReport.body).toBe(reportBody);
    });

    it("requires climber_id, wall_id, and body", async () => {
        const report = new IssueReport();

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
        const report = new IssueReport({
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
