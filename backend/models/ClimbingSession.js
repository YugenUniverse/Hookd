const mongoose = require("mongoose");

const climbingSessionSchema = new mongoose.Schema({
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
    time: { type: Number, required: true },
    review_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Review",
    },
});

climbingSessionSchema.methods.addReview = async function (rating, body) {
    const review = new Review({
        climb_id: this._id,
        rating,
        body,
    });
    await review.save();

    this.review_id = review._id;
    await this.save();
};

climbingSessionSchema.methods.removeReview = async function () {
    if (!this.review_id) return;

    await Review.findByIdAndDelete(this.review_id);
    this.review_id = null;
    await this.save();
};

module.exports = mongoose.model("ClimbingSession", climbingSessionSchema);
