const express = require("express");
const router = express.Router();

const reviewController = require("../controllers/review.controller");
const { authenticateJwtOptional, authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

router.get("/wall/:wallId", authenticateJwtOptional, reviewController.getReviewsByWall);
router.get("/user/:userId", authenticateJwtOptional, reviewController.getReviewsByUser);

router.post("/:reviewId/flag", authenticateJwt, restrictTo("Climber"), reviewController.flagReview);

module.exports = router;