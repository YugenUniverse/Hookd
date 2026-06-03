const reviewService = require("../services/review.service");

exports.getReviewsByWall = async (req, res, next) => {
    try {
        const reviews = await reviewService.getReviewsByWall(
            req.params.wallId,
            req.user?.id,
        );
        res.status(200).json({ reviews });
    } catch (err) {
        next(err);
    }
};

exports.getReviewsByUser = async (req, res, next) => {
    try {
        const reviews = await reviewService.getReviewsByUser(
            req.params.userId,
            req.user?.id,
        );
        res.status(200).json({ reviews });
    } catch (err) {
        next(err);
    }
};

exports.flagReview = async (req, res, next) => {
    try {
        const { flagReason } = req.body;
        await reviewService.flagReview(req.params.reviewId, req.user.id, flagReason);
        res.status(200).json({ message: "Review flagged successfully" });
    } catch (err) {
        next(err);
    }
};