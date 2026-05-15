const mongoose = require("mongoose");

const reportSchema = new mongoose.Schema(
    {
        facility_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User", // Facility or PublicBody
            required: true,
        },
        wall_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Wall", // IndoorWall for Facility or OutdoorWall for PublicBody
            required: true,
        },
        title: {
            type: String,
            required: [true, "A saved report must have a title"],
            trim: true,
            maxlength: [100, "Report title cannot exceed 100 characters"],
        },
        notes: {
            type: String,
            trim: true,
            maxlength: [500, "Notes cannot exceed 500 characters"],
            default: "",
        },
        reportData: {
            engagement: {
                totalSessions: Number, // Total number of climbing sessions logged on this wall.
                uniqueClimbers: Number, // Total number of unique users who have climbed this wall.
                retentionRate: Number, // The average number of times a unique user climbs this wall.
                avgTimeMins: Number, // The average time (in minutes) spent on this wall per session.
                fastestTimeMins: Number, // The absolute fastest time (in minutes) recorded on this wall.
            },
            quality: {
                avgRating: Number, // The mathematical average of all star ratings (1.0 to 5.0) left on this wall.

                totalReviews: Number, // The total number of reviews left.
                // A breakdown of how many 1, 2, 3, 4, and 5-star reviews were given.
                distribution: [
                    new mongoose.Schema(
                        {
                            stars: Number,
                            count: Number,
                        },
                        { _id: false },
                    ),
                ],
            },
            trends: {
                // A time-series array tracking the number of sessions per day for the last 30 days.
                last30Days: [
                    new mongoose.Schema(
                        {
                            date: String,
                            sessions: Number,
                        },
                        { _id: false },
                    ),
                ],
            },
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

// Indexes to make fetching a facility's history lightning fast
reportSchema.index({ facility_id: 1, createdAt: -1 });
reportSchema.index({ wall_id: 1 });

module.exports = mongoose.model("Report", reportSchema);
