const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const groupInvitationSchema = new Schema(
    {
        group: { type: ObjectId, ref: "Group", required: true },
        invitee: { type: ObjectId, ref: "User", required: true },
        invitedBy: { type: ObjectId, ref: "User", required: true },
        status: {
            type: String,
            enum: ["pending", "accepted", "declined"],
            default: "pending",
        },
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

// Prevent duplicate pending invites for the same group+invitee pair
groupInvitationSchema.index({ group: 1, invitee: 1 }, { unique: true });
groupInvitationSchema.index({ invitee: 1, status: 1 });

module.exports = mongoose.model("GroupInvitation", groupInvitationSchema);
