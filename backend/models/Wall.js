const mongoose = require("mongoose");

const STATUS_ENUM = [
    "OPEN",
    "CLOSED",
    "UNDER_MAINTAINANCE",
    "PERMANENTLY_CLOSED",
];
const DIFFICULTY_ENUM = ["BEGINNER", "INTERMEDIATE", "ADVANCED", "EXPERT"];

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

wallSchema.methods.getWall = function () {
    return this;
};

wallSchema.methods.editWall = function (updates) {
    Object.assign(this, updates);
    return this.save();
};

wallSchema.methods.computeRating = function () {
    console.log("Computing rating for", this.name);
};

wallSchema.methods.getLeadboard = function () {
    console.log("Fetching leaderboard for", this.name);
};

const Wall = mongoose.model("Wall", wallSchema);

// --- INDOOR WALL ---
const indoorSchema = new mongoose.Schema(
    {
        // Add any specific Indoor properties here
        hasAirConditioning: { type: Boolean, default: false },
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

indoorSchema.methods.editWall = function (updates) {
    Object.assign(this, updates);
    return this.save();
};

const IndoorWall = Wall.discriminator("IndoorWall", indoorSchema);

// --- OUTDOOR WALL ---
const outdoorSchema = new mongoose.Schema(
    {
        // Add any specific Outdoor properties here
        rockType: { type: String },
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

outdoorSchema.methods.editWall = function (updates) {
    Object.assign(this, updates);
    return this.save();
};

const OutdoorWall = Wall.discriminator("OutdoorWall", outdoorSchema);

module.exports = {
    Wall,
    IndoorWall,
    OutdoorWall,
};
