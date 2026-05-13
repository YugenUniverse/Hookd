const sessionService = require("../services/session.service");

exports.createSession = async (req, res, next) => {
    try {
        const result = await sessionService.createSession(
            req.user.id,
            req.user.userType,
            req.body,
        );

        const responsePayload = { session: result.session };
        if (result.review) {
            responsePayload.review = result.review;
        }

        res.status(201).json(responsePayload);
    } catch (err) {
        next(err);
    }
};

exports.getSessions = async (req, res, next) => {
    try {
        const sessions = await sessionService.getSessionsByUser(
            req.user.id,
            req.user.userType,
        );
        res.json({ sessions });
    } catch (err) {
        next(err);
    }
};

exports.getSessionById = async (req, res, next) => {
    try {
        const session = await sessionService.getSessionById(
            req.params.sessionId,
            req.user.id,
            req.user.userType,
        );
        res.json({ session });
    } catch (err) {
        next(err);
    }
};

exports.updateSession = async (req, res, next) => {
    try {
        const session = await sessionService.updateSession(
            req.params.sessionId,
            req.user.id,
            req.user.userType,
            req.body,
        );
        res.json({ session });
    } catch (err) {
        next(err);
    }
};

exports.deleteSession = async (req, res, next) => {
    try {
        await sessionService.deleteSession(
            req.params.sessionId,
            req.user.id,
            req.user.userType,
        );
        res.status(204).end();
    } catch (err) {
        next(err);
    }
};

exports.addReviewToSession = async (req, res, next) => {
    try {
        const result = await sessionService.addReviewToSession(
            req.params.sessionId,
            req.user.id,
            req.user.userType,
            req.body,
        );
        res.status(201).json({
            session: result.session,
            review: result.review,
        });
    } catch (err) {
        next(err);
    }
};
