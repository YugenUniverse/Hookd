const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const SavedReport = require("../models/Report");
const { User } = require("../models/User");

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
                totalSends: { $sum: { $cond: ["$isSend", 1, 0] } },
            },
        },
        {
            $project: {
                totalSessions: 1,
                uniqueClimbersCount: { $size: "$uniqueClimbers" },
                avgTime: { $round: ["$avgTime", 1] },
                fastestTime: 1,
                totalSends: 1,
                totalAttempts: { $subtract: ["$totalSessions", "$totalSends"] },
            },
        },
    ]);

    // --- PIPELINE 2: Temporal Trends (Last 30 Days) ---
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const temporalStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: objectId } },
        {
            $facet: {
                last30Days: [
                    { $match: { date: { $gte: thirtyDaysAgo } } },
                    {
                        $group: {
                            _id: {
                                $dateToString: {
                                    format: "%Y-%m-%d",
                                    date: "$date",
                                },
                            },
                            count: { $sum: 1 },
                        },
                    },
                    { $sort: { _id: 1 } },
                ],
                byDayOfWeek: [
                    {
                        $group: {
                            _id: { $dayOfWeek: "$date" },
                            count: { $sum: 1 },
                        },
                    },
                    { $sort: { _id: 1 } },
                ],
                byHourOfDay: [
                    { $group: { _id: { $hour: "$date" }, count: { $sum: 1 } } },
                    { $sort: { _id: 1 } },
                ],
            },
        },
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

    // --- PIPELINE 4: Climber Demographics ---
    const demographicsPromise = ClimbingSession.distinct("climber_id", {
        wall_id: objectId,
    }).then(async (userIds) => {
        // Fetch only the birthdate for these specific users
        const users = await User.find({ _id: { $in: userIds } }).select(
            "birthdate",
        );

        // Initialize our buckets
        const brackets = { "< 20": 0, "20-29": 0, "30-39": 0, "40+": 0 };
        const today = new Date();

        users.forEach((user) => {
            if (!user.birthdate) return; // Skip if user has no birthdate set

            const birthDate = new Date(user.birthdate);

            // Calculate precise age accounting for the current month/day
            let age = today.getFullYear() - birthDate.getFullYear();
            const m = today.getMonth() - birthDate.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
                age--;
            }

            // Sort into buckets
            if (age < 20) brackets["< 20"]++;
            else if (age <= 29) brackets["20-29"]++;
            else if (age <= 39) brackets["30-39"]++;
            else brackets["40+"]++;
        });

        // Convert the object into the array format our Flutter app expects
        return Object.keys(brackets).map((key) => ({
            bracket: key,
            count: brackets[key],
        }));
    });

    const Review = mongoose.model("Review");
    const { User } = require("../models/User");

        // Find sessions for this wall
    const sessionIds = await ClimbingSession.find({
        wall_id: objectId,
    }).distinct("_id");
    const recentFeedbackPromise = Review.find({
        climbing_session_id: { $in: sessionIds },
        body: { $ne: "", $exists: true },
    })
        .sort({ createdAt: -1 })
        .limit(3)
        .select("rating body createdAt");

    const [
        sessionStats,
        temporalStatsResult,
        reviewStats,
        recentFeedback,
        demographics,
    ] = await Promise.all([
        sessionStatsPromise,
        temporalStatsPromise,
        reviewStatsPromise,
        recentFeedbackPromise,
        demographicsPromise,
    ]);

    const stats = sessionStats[0] || {
        totalSessions: 0,
        uniqueClimbersCount: 0,
        avgTime: 0,
        fastestTime: null,
    };

    const temporalData = temporalStatsResult[0];
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
            totalSends: stats.totalSends || 0,
            totalAttempts: stats.totalAttempts || 0,
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
            last30Days: temporalData.last30Days.map((t) => ({
                date: t._id,
                sessions: t.count,
            })),
            byDayOfWeek: temporalData.byDayOfWeek.map((t) => ({
                day: t._id,
                count: t.count,
            })),
            byHourOfDay: temporalData.byHourOfDay.map((t) => ({
                hour: t._id,
                count: t.count,
            })),
        },
        recentFeedback: recentFeedback.map((r) => ({
            rating: r.rating,
            body: r.body,
            date: r.createdAt
                ? r.createdAt.toISOString().split("T")[0]
                : "Recent",
        })),
        demographics: demographics,
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
