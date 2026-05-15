const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const { Wall } = require("../models/Wall");
const { Climber } = require("../models/User");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const ensureSessionOwnership = (session, userId) => {
    if (!session) {
        const error = new Error("Climbing session not found");
        error.statusCode = 404;
        throw error;
    }

    if (session.climber_id.toString() !== userId) {
        const error = new Error("Forbidden: You do not own this session");
        error.statusCode = 403;
        throw error;
    }
};

exports.createSession = async (
    userId,
    userType,
    { wall_id, date, time, review, is_private = false },
) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can create climbing sessions");
        error.statusCode = 403;
        throw error;
    }

    if (!wall_id || !date || time === undefined) {
        const error = new Error("wall_id, date, and time are required");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(wall_id)) {
        const error = new Error("wall_id must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const parsedDate = new Date(date);
    if (Number.isNaN(parsedDate.getTime())) {
        const error = new Error("date must be a valid date string");
        error.statusCode = 400;
        throw error;
    }

    const climbingSession = await ClimbingSession.create({
        climber_id: userId,
        wall_id,
        date: parsedDate,
        time,
        is_private,
    });

    await Promise.all([
        Wall.findByIdAndUpdate(wall_id, {
            $push: { sessions: climbingSession._id },
        }),
        Climber.findByIdAndUpdate(userId, {
            $push: { sessions: climbingSession._id },
        }),
    ]);

    let addedReview = null;
    if (review) {
        const { rating, body } = review;
        if (rating === undefined) {
            const error = new Error(
                "Review rating is required when review payload is provided",
            );
            error.statusCode = 400;
            throw error;
        }
        addedReview = await climbingSession.addReview(rating, body || "");
    }

    return { session: climbingSession, review: addedReview };
};

exports.getSessionsByUser = async (userId, userType) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can view climbing sessions");
        error.statusCode = 403;
        throw error;
    }

    return await ClimbingSession.find({ climber_id: userId });
};

exports.getSessionById = async (sessionId, userId, userType) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can view climbing sessions");
        error.statusCode = 403;
        throw error;
    }

    if (!isValidObjectId(sessionId)) {
        const error = new Error("Invalid session id");
        error.statusCode = 400;
        throw error;
    }

    const session = await ClimbingSession.findById(sessionId);
    ensureSessionOwnership(session, userId);

    return session;
};

exports.updateSession = async (
    sessionId,
    userId,
    userType,
    { wall_id, date, time },
) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can update climbing sessions");
        error.statusCode = 403;
        throw error;
    }

    if (!isValidObjectId(sessionId)) {
        const error = new Error("Invalid session id");
        error.statusCode = 400;
        throw error;
    }

    const session = await ClimbingSession.findById(sessionId);
    ensureSessionOwnership(session, userId);

    if (wall_id !== undefined) {
        if (!isValidObjectId(wall_id)) {
            const error = new Error("wall_id must be a valid ObjectId");
            error.statusCode = 400;
            throw error;
        }

        session.wall_id = wall_id;
    }

    if (date !== undefined) {
        const parsedDate = new Date(date);
        if (Number.isNaN(parsedDate.getTime())) {
            const error = new Error("date must be a valid date string");
            error.statusCode = 400;
            throw error;
        }
        session.date = parsedDate;
    }

    if (time !== undefined) {
        session.time = time;
    }

    if (wall_id === undefined && date === undefined && time === undefined) {
        const error = new Error(
            "At least one field must be provided to update",
        );
        error.statusCode = 400;
        throw error;
    }

    return await session.save();
};

exports.deleteSession = async (sessionId, userId, userType) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can delete climbing sessions");
        error.statusCode = 403;
        throw error;
    }

    if (!isValidObjectId(sessionId)) {
        const error = new Error("Invalid session id");
        error.statusCode = 400;
        throw error;
    }

    const session = await ClimbingSession.findById(sessionId);
    ensureSessionOwnership(session, userId);

    await Promise.all([
        Wall.findByIdAndUpdate(session.wall_id, {
            $pull: { sessions: session._id },
        }),
        Climber.findByIdAndUpdate(userId, {
            $pull: { sessions: session._id },
        }),
    ]);

    await session.deleteOne();
};

exports.addReviewToSession = async (
    sessionId,
    userId,
    userType,
    { rating, body },
) => {
    if (userType !== "Climber") {
        const error = new Error(
            "Only climbers can add reviews to climbing sessions",
        );
        error.statusCode = 403;
        throw error;
    }

    if (!isValidObjectId(sessionId)) {
        const error = new Error("Invalid session id");
        error.statusCode = 400;
        throw error;
    }

    if (rating === undefined) {
        const error = new Error("Review rating is required");
        error.statusCode = 400;
        throw error;
    }

    const session = await ClimbingSession.findById(sessionId);
    ensureSessionOwnership(session, userId);

    if (session.review_id) {
        const error = new Error("Climbing session already has a review");
        error.statusCode = 409;
        throw error;
    }

    const review = await session.addReview(rating, body || "");
    return { session, review };
};
