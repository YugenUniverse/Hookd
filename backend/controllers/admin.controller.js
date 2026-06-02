const { User } = require("../models/User");
const Facility = require("../models/Facility");
const Review = require("../models/Review");
const notificationService = require("../services/notification.service");
const emailService = require("../services/email.service");
const ClimbingSession = require("../models/ClimbingSession");
const { Wall } = require("../models/Wall");
const Group = require("../models/Group");
const Event = require("../models/Event");
const { Report } = require("../models/Report");
const { Issue } = require("../models/Issue");

const getPendingApprovals = async (req, res, next) => {
    try {
        const pendingUsers = await User.find({
            userType: { $in: ["FacilityOwner", "PublicBody"] },
            approvalStatus: "pending",
        }).populate("facility");

        res.status(200).json(pendingUsers);
    } catch (err) {
        next(err);
    }
};

const getPublicBodies = async (req, res, next) => {
    try {
        const publicBodies = await User.find({
            userType: "PublicBody",
            approvalStatus: "approved",
        });

        res.status(200).json(publicBodies);
    } catch (err) {
        next(err);
    }
};

const approveAccount = async (req, res, next) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);

        if (!user || !["FacilityOwner", "PublicBody"].includes(user.userType)) {
            const error = new Error("User not found or not approvable");
            error.statusCode = 404;
            throw error;
        }

        if (user.approvalStatus === "approved") {
            const error = new Error("Account is already approved");
            error.statusCode = 400;
            throw error;
        }

        user.approvalStatus = "approved";
        await user.save();

        if (user.userType === "FacilityOwner" && user.facility) {
            const facility = await Facility.findById(user.facility);
            if (facility) {
                facility.ownerAccount = user._id;
                await facility.save();
            }
        }

        // Send notifications
        await notificationService.createBulk([user._id], "account_approved", {
            message: "Your account request has been approved.",
        });
        await emailService.sendAccountApprovedEmail(user);

        
        const padData = (data) => {
            const result = [];
            let current = new Date(startBound.getFullYear(), startBound.getMonth(), 1);
            const end = new Date(endBound.getFullYear(), endBound.getMonth(), 1);

            while (current <= end) {
                const year = current.getFullYear();
                const month = current.getMonth() + 1;
                const match = data.find(item => item._id.year === year && item._id.month === month);
                result.push({
                    _id: { year, month },
                    count: match ? match.count : 0
                });
                current.setMonth(current.getMonth() + 1);
            }
            return result;
        };

        res.status(200).json({ message: "Account approved", user });
    } catch (err) {
        next(err);
    }
};

const rejectAccount = async (req, res, next) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);

        if (!user || !["FacilityOwner", "PublicBody"].includes(user.userType)) {
            const error = new Error("User not found or not approvable");
            error.statusCode = 404;
            throw error;
        }

        user.approvalStatus = "rejected";
        await user.save();

        // Send notifications
        await notificationService.createBulk([user._id], "account_rejected", {
            message: "Your account request has been rejected.",
        });
        await emailService.sendAccountRejectedEmail(user);

        
        const padData = (data) => {
            const result = [];
            let current = new Date(startBound.getFullYear(), startBound.getMonth(), 1);
            const end = new Date(endBound.getFullYear(), endBound.getMonth(), 1);

            while (current <= end) {
                const year = current.getFullYear();
                const month = current.getMonth() + 1;
                const match = data.find(item => item._id.year === year && item._id.month === month);
                result.push({
                    _id: { year, month },
                    count: match ? match.count : 0
                });
                current.setMonth(current.getMonth() + 1);
            }
            return result;
        };

        res.status(200).json({ message: "Account rejected", user });
    } catch (err) {
        next(err);
    }
};

const getFlaggedReviews = async (req, res, next) => {
    try {
        const reviews = await Review.find({ flagged: true, status: "active" })
            .populate({
                path: "climbing_session_id",
                select: "climber_id wall_id date",
                populate: [
                    { path: "climber_id", select: "username email" },
                    { path: "wall_id", select: "name" },
                ],
            })
            .sort({ createdAt: -1 });

        res.status(200).json(reviews);
    } catch (err) {
        next(err);
    }
};

const removeReview = async (req, res, next) => {
    try {
        const { reviewId } = req.params;
        const { reason } = req.body;

        const review = await Review.findById(reviewId).populate({
            path: "climbing_session_id",
            select: "climber_id",
            populate: { path: "climber_id", select: "username email" },
        });

        if (!review || review.status === "removed") {
            const error = new Error("Review not found");
            error.statusCode = 404;
            throw error;
        }

        review.status = "removed";
        review.moderatedBy = req.user.id;
        review.moderatedAt = new Date();
        await review.save();

        const author = review.climbing_session_id?.climber_id;
        if (author) {
            await notificationService.createBulk([author._id || author], "content_removed", {
                reason: reason || "Violation of community guidelines",
                contentType: "review",
            });
            await emailService.sendContentRemovedEmail(author, reason);
        }

        
        const padData = (data) => {
            const result = [];
            let current = new Date(startBound.getFullYear(), startBound.getMonth(), 1);
            const end = new Date(endBound.getFullYear(), endBound.getMonth(), 1);

            while (current <= end) {
                const year = current.getFullYear();
                const month = current.getMonth() + 1;
                const match = data.find(item => item._id.year === year && item._id.month === month);
                result.push({
                    _id: { year, month },
                    count: match ? match.count : 0
                });
                current.setMonth(current.getMonth() + 1);
            }
            return result;
        };

        res.status(200).json({ message: "Review removed" });
    } catch (err) {
        next(err);
    }
};

const dismissFlag = async (req, res, next) => {
    try {
        const { reviewId } = req.params;

        const review = await Review.findById(reviewId);

        if (!review || review.status === "removed") {
            const error = new Error("Review not found");
            error.statusCode = 404;
            throw error;
        }

        review.flagged = false;
        review.flagReason = "";
        await review.save();

        
        const padData = (data) => {
            const result = [];
            let current = new Date(startBound.getFullYear(), startBound.getMonth(), 1);
            const end = new Date(endBound.getFullYear(), endBound.getMonth(), 1);

            while (current <= end) {
                const year = current.getFullYear();
                const month = current.getMonth() + 1;
                const match = data.find(item => item._id.year === year && item._id.month === month);
                result.push({
                    _id: { year, month },
                    count: match ? match.count : 0
                });
                current.setMonth(current.getMonth() + 1);
            }
            return result;
        };

        res.status(200).json({ message: "Flag dismissed" });
    } catch (err) {
        next(err);
    }
};

module.exports = {
    getPendingApprovals,
    approveAccount,
    rejectAccount,
    getFlaggedReviews,
    removeReview,
    dismissFlag,
    getPublicBodies,
};

const getMetrics = async (req, res, next) => {
    try {
        const { startDate, endDate } = req.query;
        
        let startBound = new Date();
        startBound.setMonth(startBound.getMonth() - 11);
        startBound.setDate(1);
        startBound.setHours(0, 0, 0, 0);
        
        let endBound = new Date();
        
        if (startDate) {
            startBound = new Date(startDate);
            startBound.setDate(1);
            startBound.setHours(0, 0, 0, 0);
        }
        if (endDate) {
            endBound = new Date(endDate);
            endBound.setHours(23, 59, 59, 999);
        }

        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const [
            activeUsersArray,
            totalUsers,
            totalWalls,
            totalReviews,
            totalGroups,
            totalEvents,
            openReports,
            userRegistrations,
            sessionsLogged,
            eventsCreated,
            reviewsAdded,
            groupsCreated,
            wallsAdded,
        ] = await Promise.all([
            ClimbingSession.distinct("climber_id", { date: { $gte: thirtyDaysAgo } }),
            User.countDocuments(),
            Wall.countDocuments(),
            Review.countDocuments(),
            Group.countDocuments(),
            Event.countDocuments(),
            Issue.countDocuments({ status: "OPEN" }),
            
            // Aggregations for last 12 months
            User.aggregate([
                { $match: { createdAt: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$createdAt" }, month: { $month: "$createdAt" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
            ClimbingSession.aggregate([
                { $match: { date: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$date" }, month: { $month: "$date" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
            Event.aggregate([
                { $match: { createdAt: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$createdAt" }, month: { $month: "$createdAt" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
            Review.aggregate([
                { $match: { createdAt: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$createdAt" }, month: { $month: "$createdAt" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
            Group.aggregate([
                { $match: { createdAt: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$createdAt" }, month: { $month: "$createdAt" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
            Wall.aggregate([
                { $match: { createdAt: { $gte: startBound, $lte: endBound } } },
                {
                    $group: {
                        _id: { year: { $year: "$createdAt" }, month: { $month: "$createdAt" } },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { "_id.year": 1, "_id.month": 1 } },
            ]),
        ]);

        
        const padData = (data) => {
            const result = [];
            let current = new Date(startBound.getFullYear(), startBound.getMonth(), 1);
            const end = new Date(endBound.getFullYear(), endBound.getMonth(), 1);

            while (current <= end) {
                const year = current.getFullYear();
                const month = current.getMonth() + 1;
                const match = data.find(item => item._id.year === year && item._id.month === month);
                result.push({
                    _id: { year, month },
                    count: match ? match.count : 0
                });
                current.setMonth(current.getMonth() + 1);
            }
            return result;
        };

        res.status(200).json({
            activeUsers: activeUsersArray.length,
            totalUsers,
            totalWalls,
            totalReviews,
            totalGroups,
            totalEvents,
            openReports,
            graphs: {
                userRegistrations: padData(userRegistrations),
                sessionsLogged: padData(sessionsLogged),
                eventsCreated: padData(eventsCreated),
                reviewsAdded: padData(reviewsAdded),
                groupsCreated: padData(groupsCreated),
                wallsAdded: padData(wallsAdded),
            },
        });
    } catch (err) {
        next(err);
    }
};

module.exports = {
    getPendingApprovals,
    approveAccount,
    rejectAccount,
    getFlaggedReviews,
    removeReview,
    dismissFlag,
    getPublicBodies,
    getMetrics,
};
