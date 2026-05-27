const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const { BaseReport, GroupReport } = require("../models/Report");
const { Issue } = require("../models/Issue");

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
                from: "reviews",
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
                    { $group: { _id: "$review.rating", count: { $sum: 1 } } },
                    { $sort: { _id: 1 } },
                ],
            },
        },
    ]);

    // --- PIPELINE 4: Climber Demographics ---
    const demographicsPromise = ClimbingSession.distinct("climber_id", {
        wall_id: objectId,
    }).then(async (userIds) => {
        const User = mongoose.model("User");
        const users = await User.find({ _id: { $in: userIds } }).select(
            "birthdate",
        );

        const brackets = { "< 20": 0, "20-29": 0, "30-39": 0, "40+": 0 };
        const today = new Date();

        users.forEach((user) => {
            if (!user.birthdate) return;
            const birthDate = new Date(user.birthdate);
            let age = today.getFullYear() - birthDate.getFullYear();
            const m = today.getMonth() - birthDate.getMonth();
            if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
                age--;
            }

            if (age < 20) brackets["< 20"]++;
            else if (age <= 29) brackets["20-29"]++;
            else if (age <= 39) brackets["30-39"]++;
            else brackets["40+"]++;
        });

        return Object.keys(brackets).map((key) => ({
            bracket: key,
            count: brackets[key],
        }));
    });

    // --- PIPELINE 5: Recent Feedback ---
    const Review = mongoose.model("Review");
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

    // --- PIPELINE 6: Recent Issues ---
    const recentIssuesPromise = Issue.find({ wall_id: objectId })
        .sort({ submitted_at: -1 })
        .limit(5)
        .select("body status submitted_at");

    // Execute all queries in parallel
    const [
        sessionStats,
        temporalStatsResult,
        reviewStats,
        recentFeedback,
        demographics,
        recentIssues,
    ] = await Promise.all([
        sessionStatsPromise,
        temporalStatsPromise,
        reviewStatsPromise,
        recentFeedbackPromise,
        demographicsPromise,
        recentIssuesPromise,
    ]);

    // --- FORMAT DATA ---
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

    const formattedIssues = recentIssues.map((i) => ({
        body: i.body,
        status: i.status || "OPEN",
        date: i.submitted_at
            ? i.submitted_at.toISOString().split("T")[0]
            : "Recent",
    }));

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
        recentIssues: formattedIssues,
        demographics: demographics,
    };
};

exports.saveReport = async (ownerId, wallId, title, notes) => {
    const reportData = await exports.getWallReport(wallId);

    const newReport = await BaseReport.create({
        owner_id: ownerId,
        wall_id: wallId,
        title: title,
        notes: notes || "",
        reportData: reportData,
    });

    return newReport;
};

exports.saveGroupReport = async (ownerId, wallIds, title, notes) => {
    if (!Array.isArray(wallIds) || wallIds.length < 2) {
        const error = new Error("At least two wall IDs are required");
        error.statusCode = 400;
        throw error;
    }

    const invalidId = wallIds.find(
        (id) => !mongoose.Types.ObjectId.isValid(id),
    );
    if (invalidId) {
        const error = new Error("Invalid wall id in wallIds");
        error.statusCode = 400;
        throw error;
    }

    const objectIds = wallIds.map((id) => new mongoose.Types.ObjectId(id));
    const distinctClimberIdsPromise = ClimbingSession.distinct("climber_id", {
        wall_id: { $in: objectIds },
    }).exec();

    const sessionStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: { $in: objectIds } } },
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

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const temporalStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: { $in: objectIds } } },
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

    const reviewStatsPromise = ClimbingSession.aggregate([
        { $match: { wall_id: { $in: objectIds } } },
        {
            $lookup: {
                from: "reviews",
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
                    { $group: { _id: "$review.rating", count: { $sum: 1 } } },
                    { $sort: { _id: 1 } },
                ],
            },
        },
    ]);

    const sessionIdsPromise = ClimbingSession.find({
        wall_id: { $in: objectIds },
    }).distinct("_id");

    const demographicsPromise = distinctClimberIdsPromise.then(
        async (userIds) => {
            const User = mongoose.model("User");
            const users = await User.find({ _id: { $in: userIds } }).select(
                "birthdate",
            );

            const brackets = { "< 20": 0, "20-29": 0, "30-39": 0, "40+": 0 };
            const today = new Date();

            users.forEach((user) => {
                if (!user.birthdate) return;
                const birthDate = new Date(user.birthdate);
                let age = today.getFullYear() - birthDate.getFullYear();
                const m = today.getMonth() - birthDate.getMonth();
                if (
                    m < 0 ||
                    (m === 0 && today.getDate() < birthDate.getDate())
                ) {
                    age--;
                }

                if (age < 20) brackets["< 20"]++;
                else if (age <= 29) brackets["20-29"]++;
                else if (age <= 39) brackets["30-39"]++;
                else brackets["40+"]++;
            });

            return Object.keys(brackets).map((key) => ({
                bracket: key,
                count: brackets[key],
            }));
        },
    );

    const perWallReportsPromise = Promise.all(
        objectIds.map((id) => exports.getWallReport(id.toString())),
    );

    const [
        sessionStats,
        temporalStatsResult,
        reviewStats,
        sessionIds,
        distinctClimberIds,
        demographics,
        recentIssues,
        perWallReports,
    ] = await Promise.all([
        sessionStatsPromise,
        temporalStatsPromise,
        reviewStatsPromise,
        sessionIdsPromise,
        distinctClimberIdsPromise,
        demographicsPromise,
        Issue.find({ wall_id: { $in: objectIds } })
            .sort({ submitted_at: -1 })
            .limit(5)
            .select("body status submitted_at"),
        perWallReportsPromise,
    ]);

    const recentFeedbackPromise = mongoose
        .model("Review")
        .find({
            climbing_session_id: { $in: sessionIds },
            body: { $ne: "", $exists: true },
        })
        .sort({ createdAt: -1 })
        .limit(3)
        .select("rating body createdAt");

    const recentFeedback = await recentFeedbackPromise;

    const stats = sessionStats[0] || {
        totalSessions: 0,
        uniqueClimbersCount: 0,
        avgTime: 0,
        fastestTime: null,
    };
    const temporalData = temporalStatsResult[0] || {
        last30Days: [],
        byDayOfWeek: [],
        byHourOfDay: [],
    };
    const reviews = reviewStats[0] || { overall: [], distribution: [] };
    const overallReviews = reviews.overall[0] || {
        avgRating: 0,
        totalReviews: 0,
    };
    const retentionRate =
        distinctClimberIds.length > 0
            ? parseFloat(
                  (stats.totalSessions / distinctClimberIds.length).toFixed(2),
              )
            : 0;

    const formattedIssues = recentIssues.map((i) => ({
        body: i.body,
        status: i.status || "OPEN",
        date: i.submitted_at
            ? i.submitted_at.toISOString().split("T")[0]
            : "Recent",
    }));

    const groupReportData = {
        aggregatedEngagement: {
            totalSessions: stats.totalSessions,
            uniqueClimbers: distinctClimberIds.length,
            retentionRate: retentionRate,
            avgTimeMins: stats.avgTime,
            fastestTimeMins: stats.fastestTime,
            totalSends: stats.totalSends || 0,
            totalAttempts: stats.totalAttempts || 0,
        },
        aggregatedQuality: {
            avgRating: overallReviews.avgRating
                ? parseFloat(overallReviews.avgRating.toFixed(1))
                : 0,
            totalReviews: overallReviews.totalReviews,
            distribution: reviews.distribution.map((d) => ({
                stars: d._id,
                count: d.count,
            })),
        },
        aggregatedTrends: {
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
        aggregatedFeedback: recentFeedback.map((r) => ({
            rating: r.rating,
            body: r.body,
            date: r.createdAt
                ? r.createdAt.toISOString().split("T")[0]
                : "Recent",
        })),
        aggregatedIssues: formattedIssues,
        aggregatedDemographics: demographics,
        wallComparisons: perWallReports.map((report, index) => ({
            wallId: objectIds[index],
            engagement: report.engagement,
            quality: report.quality,
        })),
    };

    const newReport = await GroupReport.create({
        owner_id: ownerId,
        wall_ids: objectIds,
        title: title,
        notes: notes || "",
        reportData: groupReportData,
    });

    return newReport;
};

exports.getReportsList = async (ownerId) => {
    return await BaseReport.find({ owner_id: ownerId })
        .select("-reportData")
        .populate("wall_id", "name difficulty")
        .sort({ createdAt: -1 });
};

exports.getReportById = async (reportId, ownerId) => {
    const report = await BaseReport.findOne({
        _id: reportId,
        owner_id: ownerId,
    }).populate("wall_id", "name difficulty location");

    if (!report) {
        const error = new Error("Report not found");
        error.statusCode = 404;
        throw error;
    }
    return report;
};

exports.deleteReport = async (reportId, ownerId) => {
    const report = await BaseReport.findOneAndDelete({
        _id: reportId,
        owner_id: ownerId,
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
