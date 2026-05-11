const mongoose = require("mongoose");

const reviewSchema = new mongoose.Schema({
    climbing_session_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "ClimbingSession",
        required: true,
    },
    rating: { type: Number, required: true, min: 1, max: 5 },
    body: { type: String, default: "" },
});

reviewSchema.methods.editReview = async function (newRating, newBody) {
    this.rating = newRating;
    this.body = newBody;
    await this.save();
};

module.exports = mongoose.model("Review", reviewSchema);
