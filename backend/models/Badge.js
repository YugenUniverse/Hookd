const mongoose = require("mongoose");

const badgeSchema = new mongoose.Schema(
    {
        name: { type: String, required: true, trim: true },
        description: { 
            type: String, 
            trim: true,
            maxLength: [1000, "Description cannot be more than 1000 characters"]
        },
        icon: { type: String }, // URL or path to the icon image
        score: { type: Number, default: 0 },
        type: {
            type: String,
            enum: ["system", "event"],
            default: "system",
        },
        eventId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Event",
            required: function () {
                return this.type === "event";
            },
        },
        winningCondition: {
            metric: {
                type: String,
                enum: ["rank", "score", "sessions"],
                required: function () {
                    return this.type === "event";
                },
            },
            operator: {
                type: String,
                enum: ["top", "gte"],
                required: function () {
                    return this.type === "event";
                },
            },
            value: {
                type: Number,
                required: function () {
                    return this.type === "event";
                },
            },
        },
        reEarnable: {
            type: Boolean,
            default: false,
        },
        level: {
            type: Number,
            enum: [1, 2, 3, 4], // 1: Gold, 2: Silver, 3: Bronze, 4: Standard
            default: 4,
        },
        createdBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
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
    }
);

module.exports = mongoose.model("Badge", badgeSchema);
