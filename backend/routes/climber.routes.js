const express = require("express");
const router = express.Router();
const climberController = require("../controllers/climber.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

// Get the global ranking of climbers based on their total wallet score
router.get("/leaderboard", climberController.getLeaderboard);

// Award a badge to a specific climber and update their wallet score
// Example payload: { "badgeId": "60d5ecb..." }
router.post("/:id/badges", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), climberController.acquireBadge);

module.exports = router;
