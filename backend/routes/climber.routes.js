const express = require("express");
const climberController = require("../controllers/climber.controller");
const { authenticateJwt } = require("../middleware/auth.middleware");

const router = express.Router();

router.get("/leaderboard", authenticateJwt, climberController.getLeaderboard);

module.exports = router;
