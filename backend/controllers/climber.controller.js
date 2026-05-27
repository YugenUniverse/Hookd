const climberService = require("../services/climber.service");

exports.getLeaderboard = async (req, res, next) => {
    try {
        const limit = req.query.limit ? parseInt(req.query.limit) : 50;

        const leaderboard = await climberService.getGlobalLeaderboard(limit);

        res.status(200).json(leaderboard);
    } catch (err) {
        next(err);
    }
};

exports.acquireBadge = async (req, res, next) => {
    try {
        const climberId = req.params.id;
        const { badgeId } = req.body;

        const updatedWallet = await climberService.acquireBadge(climberId, badgeId);
        res.status(200).json(updatedWallet);
    } catch (err) {
        if (err.message === "Climber not found" || err.message === "Badge not found") {
            return res.status(404).json({ message: err.message });
        }
        if (err.message === "Climber already has this badge") {
            return res.status(400).json({ message: err.message });
        }
        next(err);
    }
};
