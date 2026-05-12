const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const ensureSessionOwnership = (session, userId) => {
    if (!session) {
        const error = new Error("Climbing session not found");
        error.statusCode = 404;
        throw error;
    }

    if (session.climber_id.toString() !== userId) {
        const error = new Error("Forbidden");
        error.statusCode = 403;
        throw error;
    }
};

exports.createSession = async (req, res, next) => {
    try {
        const { wall_id, date, time } = req.body;

        if (!wall_id || !date || time === undefined) {
            const error = new Error(
                "wall_id, date, and time are required to create a climbing session",
            );
            error.statusCode = 400;
            throw error;
        }

        if (!isValidObjectId(wall_id)) {
            const error = new Error("wall_id must be a valid ObjectId");
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
            climber_id: req.user.id,
            wall_id,
            date: parsedDate,
            time,
        });

        let review = null;
        if (req.body.review) {
            const { rating, body } = req.body.review;
            if (rating === undefined) {
                const error = new Error(
                    "Review rating is required when review payload is provided",
                );
                error.statusCode = 400;
                throw error;
            }

            review = await climbingSession.addReview(rating, body || "");
        }

        const responsePayload = { session: climbingSession };
        if (review) {
            responsePayload.review = review;
        }

        res.status(201).json(responsePayload);
    } catch (err) {
        next(err);
    }
};

exports.getSessions = async (req, res, next) => {
    try {
        const sessions = await ClimbingSession.find({
            climber_id: req.user.id,
        });

        res.json({ sessions });
    } catch (err) {
        next(err);
    }
};

exports.getSessionById = async (req, res, next) => {
    try {
        const { sessionId } = req.params;

        if (!isValidObjectId(sessionId)) {
            const error = new Error("Invalid session id");
            error.statusCode = 400;
            throw error;
        }

        const session = await ClimbingSession.findById(sessionId);
        ensureSessionOwnership(session, req.user.id);

        res.json({ session });
    } catch (err) {
        next(err);
    }
};

exports.updateSession = async (req, res, next) => {
    try {
        const { sessionId } = req.params;
        const { wall_id, date, time } = req.body;

        if (!isValidObjectId(sessionId)) {
            const error = new Error("Invalid session id");
            error.statusCode = 400;
            throw error;
        }

        const session = await ClimbingSession.findById(sessionId);
        ensureSessionOwnership(session, req.user.id);

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
                "At least one field must be provided to update a climbing session",
            );
            error.statusCode = 400;
            throw error;
        }

        await session.save();

        res.json({ session });
    } catch (err) {
        next(err);
    }
};

exports.deleteSession = async (req, res, next) => {
    try {
        const { sessionId } = req.params;

        if (!isValidObjectId(sessionId)) {
            const error = new Error("Invalid session id");
            error.statusCode = 400;
            throw error;
        }

        const session = await ClimbingSession.findById(sessionId);
        ensureSessionOwnership(session, req.user.id);

        await session.deleteOne();

        res.status(204).end();
    } catch (err) {
        next(err);
    }
};

exports.addReviewToSession = async (req, res, next) => {
    try {
        const { sessionId } = req.params;
        const { rating, body } = req.body;

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
        ensureSessionOwnership(session, req.user.id);

        if (session.review_id) {
            const error = new Error("Climbing session already has a review");
            error.statusCode = 409;
            throw error;
        }

        const review = await session.addReview(rating, body || "");

        res.status(201).json({ session, review });
    } catch (err) {
        next(err);
    }
};
