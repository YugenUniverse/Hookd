const express = require("express");
const router = express.Router();

const reviewController = require("../controllers/review.controller");

router.get("/wall/:wallId", reviewController.getReviewsByWall);
router.get("/user/:userId", reviewController.getReviewsByUser);

module.exports = router;