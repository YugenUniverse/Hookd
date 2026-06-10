const mongoose = require("mongoose");
const { Climber } = require("../models/User");
const { Wall } = require("../models/Wall");

const STATUS_ENUM = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];
const SEVERITY_ENUM = ["LOW", "MEDIUM", "HIGH"];

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
        description: {
            type: String,
            trim: true,
            maxlength: [1000, "Issue description cannot exceed 1000 characters"],
            default: "",
        },
        location: {
            type: String,
            trim: true,
            maxlength: [200, "Location cannot exceed 200 characters"],
            default: "",
        },
        severity: {
            type: String,
            enum: SEVERITY_ENUM,
            default: "MEDIUM",
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

issueSchema.methods.updateStatus = function (newStatus) {
    if (!STATUS_ENUM.includes(newStatus)) {
        const error = new Error(`Invalid status: ${newStatus}`);
        error.statusCode = 400;
        throw error;
    }
    this.status = newStatus;
    return this.save();
};

const Issue = mongoose.model("Issue", issueSchema);

module.exports = { Issue, SEVERITY_ENUM };
