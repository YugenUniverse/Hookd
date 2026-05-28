const mongoose = require("mongoose");
const Badge = require("../../models/Badge");

jest.setTimeout(30000);

describe("Badge model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Badge.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a badge with valid data", async () => {
        const badge = new Badge({
            name: "First Ascent",
            description: "Climb your first route",
            score: 10,
            type: "system",
            reEarnable: false,
            level: 4
        });

        await badge.save();
        const foundBadge = await Badge.findById(badge._id);

        expect(foundBadge).not.toBeNull();
        expect(foundBadge.name).toBe("First Ascent");
        expect(foundBadge.description).toBe("Climb your first route");
        expect(foundBadge.score).toBe(10);
        expect(foundBadge.type).toBe("system");
        expect(foundBadge.reEarnable).toBe(false);
        expect(foundBadge.level).toBe(4);
    });

    it("requires name", async () => {
        const badge = new Badge({ description: "No name badge" });
        let error = null;
        try {
            await badge.save();
        } catch (err) {
            error = err;
        }
        expect(error).not.toBeNull();
        expect(error.errors.name).toBeDefined();
    });

    it("enforces default values", async () => {
        const badge = new Badge({ name: "Default Badge" });
        await badge.save();
        
        const foundBadge = await Badge.findById(badge._id);
        expect(foundBadge.score).toBe(0);
        expect(foundBadge.type).toBe("system");
        expect(foundBadge.reEarnable).toBe(false);
        expect(foundBadge.level).toBe(4);
    });

    it("enforces valid type and level", async () => {
        const badge = new Badge({
            name: "Invalid Badge",
            type: "invalid_type",
            level: 10
        });

        let error = null;
        try {
            await badge.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.type).toBeDefined();
        expect(error.errors.level).toBeDefined();
    });

    it("requires eventId and winningCondition for event type badges", async () => {
        const badge = new Badge({
            name: "Event Badge",
            type: "event",
        });

        let error = null;
        try {
            await badge.save();
        } catch (err) {
            error = err;
        }

        expect(error).not.toBeNull();
        expect(error.errors.eventId).toBeDefined();
        expect(error.errors["winningCondition.metric"]).toBeDefined();
        expect(error.errors["winningCondition.operator"]).toBeDefined();
        expect(error.errors["winningCondition.value"]).toBeDefined();
    });

    it("creates an event badge successfully", async () => {
        const badge = new Badge({
            name: "Top 3 Event Badge",
            type: "event",
            eventId: new mongoose.Types.ObjectId(),
            winningCondition: {
                metric: "rank",
                operator: "top",
                value: 3
            }
        });

        await badge.save();
        const foundBadge = await Badge.findById(badge._id);

        expect(foundBadge.type).toBe("event");
        expect(foundBadge.eventId).toBeDefined();
        expect(foundBadge.winningCondition.metric).toBe("rank");
        expect(foundBadge.winningCondition.value).toBe(3);
    });
});
