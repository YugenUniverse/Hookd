const express = require("express");
const router = express.Router();

const reviewController = require("../controllers/review.controller");
const { authenticateJwtOptional } = require("../middleware/auth.middleware");

router.use(authenticateJwtOptional);

router.get("/wall/:wallId", reviewController.getReviewsByWall);
router.get("/user/:userId", reviewController.getReviewsByUser);

module.exports = router;