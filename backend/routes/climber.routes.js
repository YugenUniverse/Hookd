const express = require("express");
const climberController = require("../controllers/climber.controller");

const router = express.Router();

router.get("/leaderboard", climberController.getLeaderboard);

module.exports = router;
