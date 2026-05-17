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
