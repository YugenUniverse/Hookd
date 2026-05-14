const mongoose = require("mongoose");

const Review = require("../models/Review");
const ClimbingSession = require("../models/ClimbingSession");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const reviewPopulateOptions = {
    path: "climbing_session_id",
    select: "wall_id climber_id date time",
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

exports.getReviewsByWall = async (wallId) => {
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

    return await Review.find({ climbing_session_id: { $in: sessionIds } })
        .sort({ _id: -1 })
        .populate(reviewPopulateOptions);
};

exports.getReviewsByUser = async (userId) => {
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

    return await Review.find({ climbing_session_id: { $in: sessionIds } })
        .sort({ _id: -1 })
        .populate(reviewPopulateOptions);
};