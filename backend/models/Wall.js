const mongoose = require("mongoose");

const STATUS_ENUM = [
    "OPEN",
    "CLOSED",
    "UNDER_MAINTAINANCE",
    "PERMANENTLY_CLOSED",
];
const DIFFICULTY_ENUM = [
    "UNKNOWN",
    "BEGINNER",
    "INTERMEDIATE",
    "ADVANCED",
    "EXPERT",
];

const baseWallTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

const wallSchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: true,
            trim: true,
        },
        description: {
            type: String,
            trim: true,
            maxLength: [
                1000,
                "Description cannot be more than 1000 characters",
            ],
        },
        location: {
            type: {
                type: String,
                enum: ["Point"],
                default: "Point",
            },
            coordinates: {
                type: [Number], // [Longitude, Latitude]
                required: true,
            },
            address: String,
        },
        rating: {
            type: Number,
            default: 0,
        },
        difficulty: {
            type: String,
            enum: DIFFICULTY_ENUM,
            required: true,
        },
        status: {
            type: String,
            enum: STATUS_ENUM,
            default: "OPEN",
        },
        sessions: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: "ClimbingSession",
            },
        ],
        issue_reports: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: "IssueReport",
            },
        ],
    },
    {
        timestamps: true,
        discriminatorKey: "wallType",
        toJSON: {
            transform: baseWallTransform,
        },
    },
);

wallSchema.index({ location: "2dsphere" });
wallSchema.index({ name: "text" });

wallSchema.methods.editWall = function (updates) {};

wallSchema.methods.computeRating = function () {};

wallSchema.methods.getLeadboard = function () {};

const Wall = mongoose.model("Wall", wallSchema);

// --- INDOOR WALL ---
const indoorSchema = new mongoose.Schema(
    {
        facility: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Facility",
            required: true,
        },
    },
    {
        toJSON: {
            transform: function (doc, ret) {
                baseWallTransform(doc, ret);
                return ret;
            },
        },
    },
);

indoorSchema.methods.editWall = function (updates) {};

const IndoorWall = Wall.discriminator("IndoorWall", indoorSchema);

// --- OUTDOOR WALL ---
const outdoorSchema = new mongoose.Schema(
    {
        publicBody: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "PublicBody",
            required: true,
        },
    },
    {
        toJSON: {
            transform: function (doc, ret) {
                baseWallTransform(doc, ret);
                return ret;
            },
        },
    },
);

outdoorSchema.methods.editWall = function (updates) {};

const OutdoorWall = Wall.discriminator("OutdoorWall", outdoorSchema);

module.exports = {
    Wall,
    IndoorWall,
    OutdoorWall,
};
