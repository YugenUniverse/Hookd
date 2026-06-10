const express = require("express");
const router = express.Router();
const climberController = require("../controllers/climber.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

// Get the global ranking of climbers based on their total wallet score
router.get("/leaderboard", climberController.getLeaderboard);

// Search climbers by username (min 2 chars)
router.get("/search", async (req, res, next) => {
    try {
        const { q } = req.query;
        if (!q || q.trim().length < 2) {
            return res.status(400).json({ error: "Query must be at least 2 characters" });
        }
        const { Climber } = require("../models/User");
        const escaped = q.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const climbers = await Climber.find({
            username: { $regex: escaped, $options: "i" },
        })
            .select("username avatar name surname")
            .limit(20);
        res.json({ users: climbers });
    } catch (err) {
        next(err);
    }
});

// Award a badge to a specific climber and update their wallet score
// Example payload: { "badgeId": "60d5ecb..." }
router.post("/:id/badges", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), climberController.acquireBadge);

module.exports = router;
