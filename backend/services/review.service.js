const mongoose = require("mongoose");

const Review = require("../models/Review");
const ClimbingSession = require("../models/ClimbingSession");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const reviewPopulateOptions = {
    path: "climbing_session_id",
    select: "wall_id climber_id date time is_private",
    populate: [
        {
            path: "wall_id",
            select: "name difficulty wallType",
        },
        {
            path: "climber_id",
            select: "username avatar userType",
        },
    ],
};

const isVisibleToRequester = (review, requesterUserId) => {
    const session = review.climbing_session_id;
    if (!session) return false;

    if (!session.is_private) {
        return true;
    }

    if (!requesterUserId) {
        return false;
    }

    const sessionOwnerId = session.climber_id?.id || session.climber_id?._id || session.climber_id;
    return sessionOwnerId?.toString() === requesterUserId.toString();
};

const filterVisibleReviews = (reviews, requesterUserId) => {
    return reviews.filter((review) => isVisibleToRequester(review, requesterUserId));
};

exports.getReviewsByWall = async (wallId, requesterUserId = null) => {
    if (!isValidObjectId(wallId)) {
        const error = new Error("Invalid wall id");
        error.statusCode = 400;
        throw error;
    }

    const sessionIds = await ClimbingSession.distinct("_id", {
        wall_id: wallId,
    });

    if (!sessionIds.length) {
        return [];
    }

    const reviews = await Review.find({ climbing_session_id: { $in: sessionIds }, status: { $ne: "removed" } })
        .sort({ _id: -1 })
        .populate(reviewPopulateOptions);

    return filterVisibleReviews(reviews, requesterUserId);
};

exports.getReviewsByUser = async (userId, requesterUserId = null) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("Invalid user id");
        error.statusCode = 400;
        throw error;
    }

    const sessionIds = await ClimbingSession.distinct("_id", {
        climber_id: userId,
    });

    if (!sessionIds.length) {
        return [];
    }

    const reviews = await Review.find({ climbing_session_id: { $in: sessionIds }, status: { $ne: "removed" } })
        .sort({ _id: -1 })
        .populate(reviewPopulateOptions);

    return filterVisibleReviews(reviews, requesterUserId);
};

exports.flagReview = async (reviewId, requesterId, flagReason) => {
    if (!isValidObjectId(reviewId)) {
        const error = new Error("Invalid review id");
        error.statusCode = 400;
        throw error;
    }

    const review = await Review.findById(reviewId).populate({
        path: "climbing_session_id",
        select: "climber_id",
    });

    if (!review || review.status === "removed") {
        const error = new Error("Review not found");
        error.statusCode = 404;
        throw error;
    }

    const authorId = review.climbing_session_id?.climber_id?.toString();
    if (authorId === requesterId.toString()) {
        const error = new Error("Cannot flag your own review");
        error.statusCode = 400;
        throw error;
    }

    if (review.flagged) {
        const error = new Error("Review already flagged");
        error.statusCode = 409;
        throw error;
    }

    review.flagged = true;
    review.flagReason = flagReason || "";
    await review.save();
    return review;
};