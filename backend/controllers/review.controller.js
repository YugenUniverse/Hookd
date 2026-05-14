const reviewService = require("../services/review.service");

exports.getReviewsByWall = async (req, res, next) => {
    try {
        const reviews = await reviewService.getReviewsByWall(req.params.wallId);
        res.status(200).json({ reviews });
    } catch (err) {
        next(err);
    }
};

exports.getReviewsByUser = async (req, res, next) => {
    try {
        const reviews = await reviewService.getReviewsByUser(req.params.userId);
        res.status(200).json({ reviews });
    } catch (err) {
        next(err);
    }
};