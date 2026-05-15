const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const SavedReport = require("../models/Report");

exports.getWallReport = async (wallId) => {
    if (!mongoose.Types.ObjectId.isValid(wallId)) {
        const error = new Error("Invalid wall id");
        error.statusCode = 400;
        throw error;
    }

    const objectId = new mongoose.Types.ObjectId(wallId);

    // --- PIPELINE 1: Engagement & Benchmark Stats ---
    const sessionStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: objectId } },
        {
            $group: {
                _id: null,
                totalSessions: { $sum: 1 },
                uniqueClimbers: { $addToSet: "$climber_id" },
                avgTime: { $avg: "$time" },
                fastestTime: { $min: "$time" },
            },
        },
        {
            $project: {
                _id: 0,
                totalSessions: 1,
                uniqueClimbersCount: { $size: "$uniqueClimbers" },
                avgTime: { $round: ["$avgTime", 1] },
                fastestTime: 1,
            },
        },
    ]);

    // --- PIPELINE 2: Temporal Trends (Last 30 Days) ---
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const temporalStatsPromise = ClimbingSession.aggregate([
        {
            $match: {
                wall_id: objectId,
                date: { $gte: thirtyDaysAgo },
            },
        },
        {
            $group: {
                _id: { $dateToString: { format: "%Y-%m-%d", date: "$date" } },
                count: { $sum: 1 },
            },
        },
        { $sort: { _id: 1 } }, // Sort oldest to newest for charts
    ]);

    // --- PIPELINE 3: Quality & Sentiment Matrix ---
    const reviewStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: objectId } },
        {
            $lookup: {
                from: "reviews", // Assumes your Review model exports as "reviews"
                localField: "_id",
                foreignField: "climbing_session_id",
                as: "review",
            },
        },
        { $unwind: "$review" },
        {
            $facet: {
                overall: [
                    {
                        $group: {
                            _id: null,
                            avgRating: { $avg: "$review.rating" },
                            totalReviews: { $sum: 1 },
                        },
                    },
                ],
                distribution: [
                    {
                        $group: {
                            _id: "$review.rating",
                            count: { $sum: 1 },
                        },
                    },
                    { $sort: { _id: 1 } },
                ],
            },
        },
    ]);

    const [sessionStats, temporalStats, reviewStats] = await Promise.all([
        sessionStatsPromise,
        temporalStatsPromise,
        reviewStatsPromise,
    ]);

    const stats = sessionStats[0] || {
        totalSessions: 0,
        uniqueClimbersCount: 0,
        avgTime: 0,
        fastestTime: null,
    };
    const reviews = reviewStats[0] || { overall: [], distribution: [] };
    const overallReviews = reviews.overall[0] || {
        avgRating: 0,
        totalReviews: 0,
    };

    const retentionRate =
        stats.uniqueClimbersCount > 0
            ? parseFloat(
                  (stats.totalSessions / stats.uniqueClimbersCount).toFixed(2),
              )
            : 0;

    return {
        engagement: {
            totalSessions: stats.totalSessions,
            uniqueClimbers: stats.uniqueClimbersCount,
            retentionRate: retentionRate,
            avgTimeMins: stats.avgTime,
            fastestTimeMins: stats.fastestTime,
        },
        quality: {
            avgRating: overallReviews.avgRating
                ? parseFloat(overallReviews.avgRating.toFixed(1))
                : 0,
            totalReviews: overallReviews.totalReviews,
            distribution: reviews.distribution.map((d) => ({
                stars: d._id,
                count: d.count,
            })),
        },
        trends: {
            last30Days: temporalStats.map((t) => ({
                date: t._id,
                sessions: t.count,
            })),
        },
    };
};

exports.saveReport = async (facilityId, wallId, title, notes) => {
    const reportData = await exports.getWallReport(wallId);

    const newReport = await SavedReport.create({
        facility_id: facilityId,
        wall_id: wallId,
        title: title,
        notes: notes || "",
        reportData: reportData,
    });

    return newReport;
};

exports.getReportsList = async (facilityId) => {
    return await SavedReport.find({ facility_id: facilityId })
        .select("-reportData -quality -trends")
        .populate("wall_id", "name difficulty")
        .sort({ createdAt: -1 });
};

exports.getReportById = async (reportId, facilityId) => {
    const report = await SavedReport.findOne({
        _id: reportId,
        facility_id: facilityId,
    }).populate("wall_id", "name difficulty location");

    if (!report) {
        const error = new Error("Report not found");
        error.statusCode = 404;
        throw error;
    }
    return report;
};

exports.deleteReport = async (reportId, facilityId) => {
    const report = await SavedReport.findOneAndDelete({
        _id: reportId,
        facility_id: facilityId,
    });

    if (!report) {
        const error = new Error(
            "Report not found or you do not have permission to delete it.",
        );
        error.statusCode = 404;
        throw error;
    }
    return report;
};
