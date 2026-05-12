const mongoose = require("mongoose");
const Review = require("../../models/Review");

jest.setTimeout(30000);

describe("Review model", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await Review.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("creates a review with valid data", async () => {
        const reviewRating = 4;
        const reviewBody = "Example review body";

        const review = new Review({
            climbing_session_id: new mongoose.Types.ObjectId(),
            rating: reviewRating,
            body: reviewBody,
        });

        await review.save();

        const foundReview = await Review.findById(review._id);

        expect(foundReview).not.toBeNull();
        expect(foundReview.climbing_session_id.toString()).toBe(
            review.climbing_session_id.toString(),
        );
        expect(foundReview.rating).toBe(reviewRating);
        expect(foundReview.body).toBe(reviewBody);
    });

    it("editReview method updates the review", async () => {
        const review = new Review({
            climbing_session_id: new mongoose.Types.ObjectId(),
            rating: 3,
            body: "Initial review",
        });
        await review.save();

        const reviewRating = 5;
        const reviewBody = "Updated review";
        await review.editReview(reviewRating, reviewBody);

        const foundReview = await Review.findById(review._id);
        expect(foundReview.rating).toBe(reviewRating);
        expect(foundReview.body).toBe(reviewBody);
    });

    it("requires climbing_session_id and rating", async () => {
        const review = new Review({
            body: "Missing climbing_session_id and rating",
        });
        await expect(review.save()).rejects.toThrow();
    });

    it("rating must be between 1 and 5", async () => {
        const review = new Review({
            climbing_session_id: new mongoose.Types.ObjectId(),
            rating: 7,
            body: "Invalid rating",
        });
        await expect(review.save()).rejects.toThrow();
    });

    it("body is optional and defaults to an empty string", async () => {
        const review = new Review({
            climbing_session_id: new mongoose.Types.ObjectId(),
            rating: 4,
        });
        await review.save();

        const foundReview = await Review.findById(review._id);
        expect(foundReview.body).toBe("");
    });
});
