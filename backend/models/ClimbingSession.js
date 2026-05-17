const mongoose = require("mongoose");
const Review = require("./Review");

const baseTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

const climbingSessionSchema = new mongoose.Schema(
    {
        climber_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Climber",
            required: true,
        },
        wall_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Wall",
            required: true,
        },
        date: { type: Date, required: true },
        time: {
            type: Number,
            required: true,
            min: [0, "Time must be a positive number"],
        },
        is_private: {
            type: Boolean,
            default: false,
        },
        review_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Review",
            default: null,
        },
        isSend: {
            type: Boolean,
            default: false,
        },
    },
    {
        toJSON: {
            transform: baseTransform,
        },
    },
);

climbingSessionSchema.methods.addReview = async function (rating, body) {
    const review = new Review({
        climbing_session_id: this._id,
        rating,
        body,
    });
    await review.save();

    this.review_id = review._id;
    await this.save();

    const Wall = mongoose.models.Wall || require("./Wall").Wall;
    const wall = await Wall.findById(this.wall_id);
    if (wall) {
        await wall.computeRating();
    }

    return review;
};

climbingSessionSchema.methods.removeReview = async function () {
    if (!this.review_id) return;

    await Review.findByIdAndDelete(this.review_id);
    this.review_id = null;
    await this.save();
};

module.exports = mongoose.model("ClimbingSession", climbingSessionSchema);
