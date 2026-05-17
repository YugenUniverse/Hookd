const express = require("express");
const { authenticateJwt } = require("../middleware/auth.middleware");
const sessionController = require("../controllers/session.controller");

const router = express.Router();

const mongoose = require("mongoose");

// Validation middleware
const validateCreateSessionInput = (req, res, next) => {
    const { wall_id, date, time, review, is_private, isSend } = req.body;

    // Check required fields
    if (!wall_id || !date || time === undefined) {
        return res.status(400).json({
            error: "wall_id, date, and time are required",
        });
    }

    // Validate wall_id is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(wall_id)) {
        return res.status(400).json({
            error: "wall_id must be a valid ObjectId",
        });
    }

    // Validate date is a valid date string
    const parsedDate = new Date(date);
    if (Number.isNaN(parsedDate.getTime())) {
        return res.status(400).json({
            error: "date must be a valid date string",
        });
    }

    // Validate time is a number
    if (typeof time !== "number") {
        return res.status(400).json({
            error: "time must be a number",
        });
    }

    if (is_private !== undefined && typeof is_private !== "boolean") {
        return res.status(400).json({
            error: "is_private must be a boolean",
        });
    }

    if (isSend !== undefined && typeof isSend !== "boolean") {
        return res.status(400).json({
            error: "isSend must be a boolean",
        });
    }

    // If review is provided, validate it
    if (review) {
        if (review.rating === undefined) {
            return res.status(400).json({
                error: "Review rating is required when review payload is provided",
            });
        }
        if (typeof review.rating !== "number") {
            return res.status(400).json({
                error: "Review rating must be a number",
            });
        }
    }

    next();
};

const validateUpdateSessionInput = (req, res, next) => {
    const { wall_id, date, time, is_private, isSend } = req.body;

    // At least one field must be provided
    if (
        wall_id === undefined &&
        date === undefined &&
        time === undefined &&
        isSend === undefined
    ) {
        return res.status(400).json({
            error: "At least one field (wall_id, date, time, or isSend) must be provided to update",
        });
    }

    // Validate wall_id if provided
    if (wall_id !== undefined) {
        if (!mongoose.Types.ObjectId.isValid(wall_id)) {
            return res.status(400).json({
                error: "wall_id must be a valid ObjectId",
            });
        }
    }

    // Validate date if provided
    if (date !== undefined) {
        const parsedDate = new Date(date);
        if (Number.isNaN(parsedDate.getTime())) {
            return res.status(400).json({
                error: "date must be a valid date string",
            });
        }
    }

    // Validate time if provided
    if (time !== undefined && typeof time !== "number") {
        return res.status(400).json({
            error: "time must be a number",
        });
    }

    if (is_private !== undefined && typeof is_private !== "boolean") {
        return res.status(400).json({
            error: "is_private must be a boolean",
        });
    }

    if (isSend !== undefined && typeof isSend !== "boolean") {
        return res.status(400).json({
            error: "isSend must be a boolean",
        });
    }

    next();
};

const validateAddReviewInput = (req, res, next) => {
    const { rating, body } = req.body;

    if (rating === undefined) {
        return res.status(400).json({
            error: "Review rating is required",
        });
    }

    if (typeof rating !== "number") {
        return res.status(400).json({
            error: "Review rating must be a number",
        });
    }

    next();
};

router.use(authenticateJwt);

router.post("/", validateCreateSessionInput, sessionController.createSession);
router.post(
    "/:sessionId/reviews",
    validateAddReviewInput,
    sessionController.addReviewToSession,
);
router.get("/", sessionController.getSessions);
router.get("/:sessionId", sessionController.getSessionById);
router.put(
    "/:sessionId",
    validateUpdateSessionInput,
    sessionController.updateSession,
);
router.delete("/:sessionId", sessionController.deleteSession);

module.exports = router;
