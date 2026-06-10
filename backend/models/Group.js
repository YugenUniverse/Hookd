const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const memberSchema = new Schema(
    {
        user: { type: ObjectId, ref: "User", required: true },
        role: { type: String, enum: ["admin", "manager", "member"], default: "member" },
        joinedAt: { type: Date, default: Date.now },
        score: { type: Number, default: 0 },
    },
    { _id: false },
);

const groupSchema = new Schema(
    {
        name: { type: String, required: true, trim: true, maxlength: 100 },
        description: { type: String, trim: true, maxlength: 500 },
        visibility: { type: String, enum: ["public", "private"], default: "private" },
        creator: { type: ObjectId, ref: "User", required: true },
        members: { type: [memberSchema], default: [] },
    },
    {
        timestamps: true,
        toJSON: {
            transform: (doc, ret) => {
                ret.id = ret._id;
                delete ret._id;
                delete ret.__v;
                return ret;
            },
        },
    },
);

groupSchema.index({ "members.user": 1 });

module.exports = mongoose.model("Group", groupSchema);
