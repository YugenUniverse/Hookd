const { Climber } = require("../models/User");

exports.getGlobalLeaderboard = async (limit = 50) => {
    const leaderboard = await Climber.aggregate([
        {
            $project: {
                username: 1,
                name: 1,
                surname: 1,
                avatar: 1,
                totalSessions: { $size: { $ifNull: ["$sessions", []] } },
            },
        },
        { $sort: { totalSessions: -1 } },
        { $limit: limit },
    ]);

    return leaderboard.map((climber) => ({
        id: climber._id,
        username: climber.username,
        name: climber.name,
        surname: climber.surname,
        avatar: climber.avatar,
        totalSessions: climber.totalSessions,
    }));
};
