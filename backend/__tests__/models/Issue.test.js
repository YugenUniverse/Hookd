const mongoose = require("mongoose");
const { Issue } = require("../../models/Issue");

jest.setTimeout(30000);

describe("Issue model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Issue.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a report with valid data", async () => {
        const reportBody = "Example report body";

        const issue = new Issue({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            body: reportBody,
        });

        await issue.save();

        const foundIssue = await Issue.findById(issue._id);

        expect(foundIssue).not.toBeNull();
        expect(foundIssue.climber_id.toString()).toBe(
            issue.climber_id.toString(),
        );
        expect(foundIssue.wall_id.toString()).toBe(issue.wall_id.toString());
        expect(foundIssue.body).toBe(reportBody);
        expect(foundIssue.submitted_at).toBeInstanceOf(Date);
    });

    it("requires climber_id, wall_id, and body", async () => {
        const issue = new Issue();

        let error = null;
        try {
            await issue.save();
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
        const issue = new Issue({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            body: longBody,
        });

        let error = null;
        try {
            await issue.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.body).toBeDefined();
    });
});
