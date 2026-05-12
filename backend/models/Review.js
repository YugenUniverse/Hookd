const mongoose = require("mongoose");

const baseTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

const reviewSchema = new mongoose.Schema(
    {
        climbing_session_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "ClimbingSession",
            required: true,
        },
        rating: {
            type: Number,
            required: true,
            min: [1, "Rating must be at least 1"],
            max: [5, "Rating cannot exceed 5"],
        },
        body: {
            type: String,
            default: "",
            trim: true,
            maxlength: [500, "Review body cannot exceed 500 characters"],
        },
    },
    {
        toJSON: {
            transform: baseTransform,
        },
    },
);

reviewSchema.methods.editReview = async function (newRating, newBody) {
    this.rating = newRating;
    this.body = newBody;
    await this.save();
};

module.exports = mongoose.model("Review", reviewSchema);
