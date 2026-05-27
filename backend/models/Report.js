const mongoose = require("mongoose");

const baseTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

const reportSchema = new mongoose.Schema(
    {
        owner_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User", // FacilityOwner or PublicBody
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
    },
    {
        timestamps: true,
        discriminatorKey: "reportType",
        toJSON: {
            transform: baseTransform,
        },
    },
);

reportSchema.index({ owner_id: 1, createdAt: -1 });
reportSchema.index({ wall_id: 1 });

const Report = mongoose.model("Report", reportSchema);

// --- BASE REPORT ---
const baseReportSchema = new mongoose.Schema(
    {
        wall_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Wall", // IndoorWall for Facility or OutdoorWall for PublicBody
            required: true,
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
        toJSON: {
            transform: baseTransform,
        },
    },
);

const BaseReport = Report.discriminator("BaseReport", baseReportSchema);

// --- GROUP REPORT ---
const groupReportSchema = new mongoose.Schema(
    {
        wall_ids: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: "Wall", // IndoorWall for Facility or OutdoorWall for PublicBody
                required: true,
            },
        ],
        reportData: {
            /*! TODO: define the structure of aggregated report data for multiple walls.
             *  This could include averages, totals, and comparisons across walls.
             */
            aggregatedEngagement: {
                totalSessions: Number,
                uniqueClimbers: Number,
                retentionRate: Number,
                avgTimeMins: Number,
                fastestTimeMins: Number,
                totalSends: Number,
                totalAttempts: Number,
            },
            aggregatedQuality: {
                avgRating: Number,
                totalReviews: Number,
                distribution: [
                    new mongoose.Schema(
                        { stars: Number, count: Number },
                        { _id: false },
                    ),
                ],
            },
            aggregatedTrends: {
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
            aggregatedFeedback: [
                new mongoose.Schema(
                    { rating: Number, body: String, date: String },
                    { _id: false },
                ),
            ],
            aggregatedIssues: [
                new mongoose.Schema(
                    { body: String, status: String, date: String },
                    { _id: false },
                ),
            ],

            aggregatedDemographics: [
                new mongoose.Schema(
                    { bracket: String, count: Number },
                    { _id: false },
                ),
            ],
            // Additional fields for group reports, such as comparisons between walls
            wallComparisons: [
                new mongoose.Schema(
                    {
                        wallId: {
                            type: mongoose.Schema.Types.ObjectId,
                            ref: "Wall",
                        },
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
                    },
                    { _id: false },
                ),
            ],
        },
    },
    {
        toJSON: {
            transform: baseTransform,
        },
    },
);

const GroupReport = Report.discriminator("GroupReport", groupReportSchema);

module.exports = {
    Report,
    BaseReport,
    GroupReport,
};
