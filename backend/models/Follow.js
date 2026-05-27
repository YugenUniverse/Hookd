const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const followSchema = new Schema(
    {
        follower: { type: ObjectId, ref: "User", required: true },
        following: { type: ObjectId, ref: "User", required: true },
    },
    { timestamps: true },
);

followSchema.index({ follower: 1, following: 1 }, { unique: true });
followSchema.index({ following: 1 });

module.exports = mongoose.model("Follow", followSchema);
