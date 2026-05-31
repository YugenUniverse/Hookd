const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const messageSchema = new Schema(
    {
        conversation: { type: ObjectId, ref: "Conversation", required: true },
        sender: { type: ObjectId, ref: "User", required: true },
        content: {
            type: String,
            required: true,
            trim: true,
            maxlength: [2000, "Message cannot exceed 2000 characters"],
        },
        readBy: [
            {
                user: { type: ObjectId, ref: "User" },
                readAt: { type: Date, default: Date.now },
                _id: false,
            },
        ],
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

messageSchema.index({ conversation: 1, createdAt: -1 });

module.exports = mongoose.model("Message", messageSchema);
