const mongoose = require("mongoose");
const { Climber } = require("../models/User");
const { Wall } = require("../models/Wall");

const STATUS_ENUM = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];

const baseTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

const issueSchema = new mongoose.Schema(
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
        body: {
            type: String,
            required: true,
            trim: true,
            maxlength: [500, "Issue body cannot exceed 500 characters"],
        },
        status: {
            type: String,
            enum: STATUS_ENUM,
            default: "OPEN",
        },
    },
    {
        timestamps: {
            createdAt: "submitted_at",
            updatedAt: false,
        },
        toJSON: {
            transform: baseTransform,
        },
    },
);

const Issue = mongoose.model("Issue", issueSchema);

module.exports = { Issue };
