const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const { Report, BaseReport, GroupReport } = require("../models/Report");
const { Issue } = require("../models/Issue");
const { Wall } = require("../models/Wall");

exports.getWallReport = async (wallId) => {
    if (!mongoose.Types.ObjectId.isValid(wallId)) {
        const error = new Error("Invalid wall id");
        error.statusCode = 400;
        throw error;
    }

    const objectId = new mongoose.Types.ObjectId(wallId);
    const wall = await Wall.findById(objectId).select("name");

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
        wallId: wallId,
        wallName: wall?.name || null,
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

    const wallDocs = await Wall.find({ _id: { $in: objectIds } }).select(
        "name",
    );
    const wallNameById = new Map(
        wallDocs.map((wall) => [wall._id.toString(), wall.name]),
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
        wallComparisons: objectIds.map((wallId, index) => ({
            wallId: wallId,
            wallName: wallNameById.get(wallId.toString()) || "Unknown Wall",
            engagement: perWallReports[index].engagement,
            quality: perWallReports[index].quality,
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

const EXPORT_SECTION_MAP = {
    engagement: (report, rows) => {
        const sectionData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedEngagement || {}
                : report.reportData?.engagement || {};

        Object.entries(sectionData).forEach(([metric, value]) => {
            rows.push(["engagement", metric, "", value ?? "", ""]);
        });
    },
    quality: (report, rows) => {
        const sectionData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedQuality || {}
                : report.reportData?.quality || {};

        Object.entries(sectionData).forEach(([metric, value]) => {
            if (metric === "distribution" && Array.isArray(value)) {
                value.forEach((entry) => {
                    rows.push([
                        "quality",
                        "distribution",
                        `stars:${entry.stars}`,
                        entry.count ?? "",
                        "",
                    ]);
                });
                return;
            }

            rows.push(["quality", metric, "", value ?? "", ""]);
        });
    },
    trends: (report, rows) => {
        const trendData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedTrends || {}
                : report.reportData?.trends || {};

        (trendData.last30Days || []).forEach((entry) => {
            rows.push([
                "trends",
                "last30Days",
                entry.date,
                entry.sessions ?? "",
                "",
            ]);
        });

        (trendData.byDayOfWeek || []).forEach((entry) => {
            rows.push([
                "trends",
                "byDayOfWeek",
                `${entry.day}`,
                entry.count ?? "",
                "",
            ]);
        });

        (trendData.byHourOfDay || []).forEach((entry) => {
            rows.push([
                "trends",
                "byHourOfDay",
                `${entry.hour}`,
                entry.count ?? "",
                "",
            ]);
        });
    },
    feedback: (report, rows) => {
        const feedbackData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedFeedback || []
                : report.reportData?.recentFeedback || [];

        feedbackData.forEach((entry) => {
            rows.push([
                "feedback",
                "rating",
                entry.date || "",
                entry.rating ?? "",
                entry.body || "",
            ]);
        });
    },
    issues: (report, rows) => {
        const issuesData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedIssues || []
                : report.reportData?.recentIssues || [];

        issuesData.forEach((entry) => {
            rows.push([
                "issues",
                entry.status || "status",
                entry.date || "",
                entry.status ?? "",
                entry.body || "",
            ]);
        });
    },
    demographics: (report, rows) => {
        const demographicsData =
            report.reportType === "GroupReport"
                ? report.reportData?.aggregatedDemographics || []
                : report.reportData?.demographics || [];

        demographicsData.forEach((entry) => {
            rows.push([
                "demographics",
                "bracket",
                entry.bracket || "",
                entry.count ?? "",
                "",
            ]);
        });
    },
    wallComparisons: (report, rows) => {
        if (report.reportType !== "GroupReport") return;

        (report.reportData?.wallComparisons || []).forEach((comparison) => {
            const wallName =
                comparison.wallName || comparison.wallId || "Unknown Wall";

            Object.entries(comparison.engagement || {}).forEach(
                ([metric, value]) => {
                    rows.push([
                        "wallComparisons",
                        `engagement.${metric}`,
                        wallName,
                        value ?? "",
                        "",
                    ]);
                },
            );

            Object.entries(comparison.quality || {}).forEach(
                ([metric, value]) => {
                    if (metric === "distribution" && Array.isArray(value)) {
                        value.forEach((entry) => {
                            rows.push([
                                "wallComparisons",
                                "quality.distribution",
                                wallName,
                                entry.count ?? "",
                                `stars:${entry.stars}`,
                            ]);
                        });
                        return;
                    }

                    rows.push([
                        "wallComparisons",
                        `quality.${metric}`,
                        wallName,
                        value ?? "",
                        "",
                    ]);
                },
            );
        });
    },
};

const escapeCsvValue = (value) => {
    if (value === null || value === undefined) return "";

    const stringValue = Array.isArray(value) ? value.join("; ") : String(value);

    if (/[",\n\r]/.test(stringValue)) {
        return `"${stringValue.replace(/"/g, '""')}"`;
    }

    return stringValue;
};

exports.generateSavedReportCsv = (report, query = {}) => {
    const requestedSections = (query.sections || "")
        .split(",")
        .map((section) => section.trim())
        .filter(Boolean);

    const availableSections = Object.keys(EXPORT_SECTION_MAP);
    const selectedSections =
        requestedSections.length > 0 ? requestedSections : availableSections;

    const invalidSections = selectedSections.filter(
        (section) => !availableSections.includes(section),
    );

    if (invalidSections.length > 0) {
        const error = new Error(
            `Unsupported export sections: ${invalidSections.join(", ")}`,
        );
        error.statusCode = 400;
        throw error;
    }

    const rows = [["section", "metric", "sub_metric", "value", "detail"]];

    selectedSections.forEach((section) => {
        EXPORT_SECTION_MAP[section](report, rows);
    });

    const reportType = report.reportType || "BaseReport";
    const wallNames =
        report.wall_ids && Array.isArray(report.wall_ids)
            ? report.wall_ids
                  .map((wall) => wall?.name || wall?.toString())
                  .filter(Boolean)
            : report.wall_id
              ? [report.wall_id?.name || report.wall_id?.toString()].filter(
                    Boolean,
                )
              : [];

    const metadataRows = [
        [
            "metadata",
            "report_id",
            "",
            report._id?.toString() || report.id || "",
            "",
        ],
        ["metadata", "report_type", "", reportType, ""],
        ["metadata", "title", "", report.title || "", ""],
        ["metadata", "notes", "", report.notes || "", ""],
        [
            "metadata",
            "created_at",
            "",
            report.createdAt ? new Date(report.createdAt).toISOString() : "",
            "",
        ],
        ["metadata", "walls", "", wallNames.join("; "), ""],
    ];

    const csvRows = [...metadataRows, ...rows];
    return csvRows
        .map((row) => row.map((cell) => escapeCsvValue(cell)).join(","))
        .join("\n");
};

exports.getReportsList = async (ownerId) => {
    return await Report.find({ owner_id: ownerId })
        .select("-reportData")
        .populate("wall_id", "name difficulty")
        .populate("wall_ids", "name difficulty")
        .sort({ createdAt: -1 });
};

exports.getReportById = async (reportId, ownerId) => {
    const report = await Report.findOne({
        _id: reportId,
        owner_id: ownerId,
    })
        .populate("wall_id", "name difficulty location")
        .populate("wall_ids", "name difficulty location");

    if (!report) {
        const error = new Error("Report not found");
        error.statusCode = 404;
        throw error;
    }
    return report;
};

exports.deleteReport = async (reportId, ownerId) => {
    const report = await Report.findOneAndDelete({
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

/**
 * Get statistics filtered by geographic zone and temporal range
 * @param {number} minLat - Minimum latitude of bounding box
 * @param {number} maxLat - Maximum latitude of bounding box
 * @param {number} minLng - Minimum longitude of bounding box
 * @param {number} maxLng - Maximum longitude of bounding box
 * @param {Date|string} startDate - Start date for filtering sessions
 * @param {Date|string} endDate - End date for filtering sessions
 * @returns {Promise<object>} Aggregated statistics for the region and time period
 */
exports.getStatisticsByAreaAndTime = async (
    minLat,
    maxLat,
    minLng,
    maxLng,
    startDate,
    endDate,
) => {
    // Validate inputs
    if (
        typeof minLat !== "number" ||
        typeof maxLat !== "number" ||
        typeof minLng !== "number" ||
        typeof maxLng !== "number"
    ) {
        const error = new Error(
            "Geographic bounds must be numbers: minLat, maxLat, minLng, maxLng",
        );
        error.statusCode = 400;
        throw error;
    }

    if (minLat >= maxLat || minLng >= maxLng) {
        const error = new Error(
            "Invalid bounds: minLat < maxLat and minLng < maxLng required",
        );
        error.statusCode = 400;
        throw error;
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        const error = new Error(
            "Invalid dates: startDate and endDate must be valid dates",
        );
        error.statusCode = 400;
        throw error;
    }

    if (start >= end) {
        const error = new Error("startDate must be before endDate");
        error.statusCode = 400;
        throw error;
    }

    // $geoWithin with GeoJSON polygon uses the 2dsphere index on location
    const wallsInArea = await Wall.find({
        location: {
            $geoWithin: {
                $geometry: {
                    type: "Polygon",
                    coordinates: [[
                        [minLng, minLat],
                        [maxLng, minLat],
                        [maxLng, maxLat],
                        [minLng, maxLat],
                        [minLng, minLat],
                    ]],
                },
            },
        },
    }).select("_id name location");

    if (wallsInArea.length === 0) {
        return {
            area: {
                minLat,
                maxLat,
                minLng,
                maxLng,
            },
            timeRange: {
                startDate: start.toISOString(),
                endDate: end.toISOString(),
            },
            wallCount: 0,
            engagement: {
                totalSessions: 0,
                uniqueClimbers: 0,
                retentionRate: 0,
                avgTimeMins: 0,
                fastestTimeMins: null,
                totalSends: 0,
                totalAttempts: 0,
            },
            quality: {
                avgRating: 0,
                totalReviews: 0,
                distribution: [],
            },
            trends: {
                byDate: [],
                byDayOfWeek: [],
                byHourOfDay: [],
            },
            recentFeedback: [],
            demographics: [],
            wallList: [],
        };
    }

    const wallIds = wallsInArea.map((w) => w._id);

    // Engagement & Benchmark Stats
    const sessionStatsPromise = ClimbingSession.aggregate([
        {
            $match: {
                wall_id: { $in: wallIds },
                date: { $gte: start, $lte: end },
            },
        },
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

    // Temporal Trends
    const temporalStatsPromise = ClimbingSession.aggregate([
        {
            $match: {
                wall_id: { $in: wallIds },
                date: { $gte: start, $lte: end },
            },
        },
        {
            $facet: {
                byDate: [
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

    // Quality & Review Stats
    const reviewStatsPromise = ClimbingSession.aggregate([
        {
            $match: {
                wall_id: { $in: wallIds },
                date: { $gte: start, $lte: end },
            },
        },
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

    // Demographics
    const demographicsPromise = ClimbingSession.distinct("climber_id", {
        wall_id: { $in: wallIds },
        date: { $gte: start, $lte: end },
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

    // Recent Feedback — single aggregation avoids sequential distinct + find
    const recentFeedbackPromise = ClimbingSession.aggregate([
        {
            $match: {
                wall_id: { $in: wallIds },
                date: { $gte: start, $lte: end },
                review_id: { $ne: null },
            },
        },
        {
            $lookup: {
                from: "reviews",
                localField: "review_id",
                foreignField: "_id",
                as: "review",
            },
        },
        { $unwind: "$review" },
        { $match: { "review.body": { $exists: true, $ne: "" } } },
        { $sort: { "review.createdAt": -1 } },
        { $limit: 5 },
        {
            $project: {
                _id: 0,
                rating: "$review.rating",
                body: "$review.body",
                createdAt: "$review.createdAt",
            },
        },
    ]);

    // Execute all aggregations in parallel
    const [sessionStats, temporalStats, reviewStats, demographics, feedback] =
        await Promise.all([
            sessionStatsPromise,
            temporalStatsPromise,
            reviewStatsPromise,
            demographicsPromise,
            recentFeedbackPromise,
        ]);

    // Format results
    const stats = sessionStats[0] || {
        totalSessions: 0,
        uniqueClimbersCount: 0,
        avgTime: 0,
        fastestTime: null,
    };

    const temporalData = temporalStats[0] || {
        byDate: [],
        byDayOfWeek: [],
        byHourOfDay: [],
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
        area: {
            minLat,
            maxLat,
            minLng,
            maxLng,
        },
        timeRange: {
            startDate: start.toISOString(),
            endDate: end.toISOString(),
        },
        wallCount: wallsInArea.length,
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
            byDate: temporalData.byDate.map((t) => ({
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
        recentFeedback: feedback.map((r) => ({
            rating: r.rating,
            body: r.body,
            date: r.createdAt
                ? r.createdAt.toISOString().split("T")[0]
                : "Recent",
        })),
        demographics: demographics,
        wallList: wallsInArea.map((w) => ({
            id: w._id,
            name: w.name,
            location: {
                latitude: w.location.coordinates[1],
                longitude: w.location.coordinates[0],
            },
        })),
    };
};
