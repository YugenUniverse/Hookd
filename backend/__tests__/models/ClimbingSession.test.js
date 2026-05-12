const mongoose = require("mongoose");
const ClimbingSession = require("../../models/ClimbingSession");
const Review = require("../../models/Review");

jest.setTimeout(30000);

describe("ClimbingSession model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await ClimbingSession.deleteMany({});
        await Review.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a climbing session with valid data", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: 90,
        });

        await climbingSession.save();

        const foundClimbingSession = await ClimbingSession.findById(
            climbingSession._id,
        );

        expect(foundClimbingSession).not.toBeNull();
        expect(foundClimbingSession.climber_id.toString()).toBe(
            climbingSession.climber_id.toString(),
        );
        expect(foundClimbingSession.wall_id.toString()).toBe(
            climbingSession.wall_id.toString(),
        );
        expect(foundClimbingSession.time).toBe(90);
    });

    it("addReview creates a review and associates it with the session", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: 120,
        });
        await climbingSession.save();

        await climbingSession.addReview(5, "Great climb");

        const updatedSession = await ClimbingSession.findById(
            climbingSession._id,
        );
        const review = await Review.findById(updatedSession.review_id);

        expect(updatedSession.review_id).toBeDefined();
        expect(review).not.toBeNull();
        expect(review.rating).toBe(5);
        expect(review.body).toBe("Great climb");
        expect(review.climbing_session_id.toString()).toBe(
            climbingSession._id.toString(),
        );
    });

    it("removeReview deletes the associated review and clears review_id", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: 75,
        });
        await climbingSession.save();

        await climbingSession.addReview(4, "Nice route");
        await climbingSession.removeReview();

        const updatedSession = await ClimbingSession.findById(
            climbingSession._id,
        );
        const deletedReview = await Review.findOne({
            climbing_session_id: climbingSession._id,
        });

        expect(updatedSession.review_id).toBeNull();
        expect(deletedReview).toBeNull();
    });

    it("removeReview does nothing when no review is attached", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: 60,
        });
        await climbingSession.save();

        await expect(climbingSession.removeReview()).resolves.not.toThrow();
        expect(climbingSession.review_id).toBeNull();
    });

    it("requires climber_id, wall_id, date, and time", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: 45,
        });

        await expect(climbingSession.save()).rejects.toThrow();
    });

    it("time must be a positive number", async () => {
        const climbingSession = new ClimbingSession({
            climber_id: new mongoose.Types.ObjectId(),
            wall_id: new mongoose.Types.ObjectId(),
            date: new Date(),
            time: -30,
        });

        await expect(climbingSession.save()).rejects.toThrow();
    });
});
