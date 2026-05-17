const mongoose = require("mongoose");

const reportSchema = new mongoose.Schema(
    {
        facility_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User", // FacilityOwner or PublicBody
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
                totalSessions: Number,
                uniqueClimbers: Number,
                retentionRate: Number,
                avgTimeMins: Number,
                fastestTimeMins: Number,
                totalSends: Number,
                totalAttempts: Number,
            },
            quality: {
                avgRating: Number,
                totalReviews: Number,
                distribution: [
                    new mongoose.Schema(
                        { stars: Number, count: Number },
                        { _id: false },
                    ),
                ],
            },
            trends: {
                last30Days: [
                    new mongoose.Schema(
                        { date: String, sessions: Number },
                        { _id: false },
                    ),
                ],
                byDayOfWeek: [
                    new mongoose.Schema(
                        { day: Number, count: Number },
                        { _id: false },
                    ),
                ],
                byHourOfDay: [
                    new mongoose.Schema(
                        { hour: Number, count: Number },
                        { _id: false },
                    ),
                ],
            },
            // Qualitative feedback (Reviews)
            recentFeedback: [
                new mongoose.Schema(
                    { rating: Number, body: String, date: String },
                    { _id: false },
                ),
            ],
            // Qualitative feedback (Issues)
            recentIssues: [
                new mongoose.Schema(
                    { body: String, status: String, date: String },
                    { _id: false },
                ),
            ],
            // Demographic breakdown of climbers
            demographics: [
                new mongoose.Schema(
                    { bracket: String, count: Number },
                    { _id: false },
                ),
            ],
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

reportSchema.index({ facility_id: 1, createdAt: -1 });
reportSchema.index({ wall_id: 1 });

module.exports = mongoose.model("Report", reportSchema);
