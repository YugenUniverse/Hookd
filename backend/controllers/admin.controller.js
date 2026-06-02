const { User } = require("../models/User");
const Facility = require("../models/Facility");
const Review = require("../models/Review");
const notificationService = require("../services/notification.service");
const emailService = require("../services/email.service");

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
