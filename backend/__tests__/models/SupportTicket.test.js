const mongoose = require("mongoose");
const { SupportTicket } = require("../../models/SupportTicket");

jest.setTimeout(30000);

describe("SupportTicket model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    afterEach(async () => {
        await SupportTicket.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a ticket with valid data", async () => {
        const userId = new mongoose.Types.ObjectId();
        const ticket = new SupportTicket({
            user_id: userId,
            subject: "Cannot login",
            body: "I am unable to login with my credentials",
        });

        await ticket.save();

        const found = await SupportTicket.findById(ticket._id);
        expect(found).not.toBeNull();
        expect(found.user_id.toString()).toBe(userId.toString());
        expect(found.subject).toBe("Cannot login");
        expect(found.body).toBe("I am unable to login with my credentials");
        expect(found.status).toBe("OPEN");
        expect(found.category).toBe("OTHER");
        expect(found.admin_reply).toBeNull();
        expect(found.replied_at).toBeNull();
        expect(found.replied_by).toBeNull();
    });

    it("requires user_id, subject, and body", async () => {
        const ticket = new SupportTicket();

        let error = null;
        try {
            await ticket.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.user_id).toBeDefined();
        expect(error.errors.subject).toBeDefined();
        expect(error.errors.body).toBeDefined();
    });

    it("rejects invalid category", async () => {
        const ticket = new SupportTicket({
            user_id: new mongoose.Types.ObjectId(),
            subject: "Test",
            body: "Test body",
            category: "INVALID",
        });

        let error = null;
        try {
            await ticket.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.category).toBeDefined();
    });

    it("rejects invalid status", async () => {
        const ticket = new SupportTicket({
            user_id: new mongoose.Types.ObjectId(),
            subject: "Test",
            body: "Test body",
            status: "INVALID",
        });

        let error = null;
        try {
            await ticket.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.status).toBeDefined();
    });

    it("enforces subject max length", async () => {
        const ticket = new SupportTicket({
            user_id: new mongoose.Types.ObjectId(),
            subject: "a".repeat(201),
            body: "Valid body",
        });

        let error = null;
        try {
            await ticket.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.subject).toBeDefined();
    });

    it("enforces body max length", async () => {
        const ticket = new SupportTicket({
            user_id: new mongoose.Types.ObjectId(),
            subject: "Valid subject",
            body: "a".repeat(2001),
        });

        let error = null;
        try {
            await ticket.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.body).toBeDefined();
    });

    it("stores all valid categories", async () => {
        const categories = ["ACCOUNT", "BUG", "CONTENT", "OTHER"];
        for (const category of categories) {
            const ticket = new SupportTicket({
                user_id: new mongoose.Types.ObjectId(),
                subject: `Test ${category}`,
                body: "Test body",
                category,
            });
            await ticket.save();
            const found = await SupportTicket.findById(ticket._id);
            expect(found.category).toBe(category);
        }
    });

    it("toJSON transform removes _id and __v, adds id", async () => {
        const ticket = await SupportTicket.create({
            user_id: new mongoose.Types.ObjectId(),
            subject: "Test",
            body: "Test body",
        });

        const json = ticket.toJSON();
        expect(json.id).toBeDefined();
        expect(json._id).toBeUndefined();
        expect(json.__v).toBeUndefined();
    });
});
