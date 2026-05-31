const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const conversationSchema = new Schema(
    {
        type: { type: String, enum: ["dm", "group"], required: true },
        participants: [{ type: ObjectId, ref: "User" }],
        group: { type: ObjectId, ref: "Group", default: null },
        lastMessage: { type: ObjectId, ref: "Message", default: null },
        lastActivity: { type: Date, default: Date.now },
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

// One conversation per group
conversationSchema.index({ group: 1 }, { unique: true, sparse: true });
conversationSchema.index({ participants: 1, lastActivity: -1 });

module.exports = mongoose.model("Conversation", conversationSchema);
