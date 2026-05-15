const { Climber } = require("../models/User");

exports.getGlobalLeaderboard = async (limit = 50) => {
    const rawLeaderboard = await Climber.aggregate([
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

    return rawLeaderboard.map((climber) => {
        const ascents = climber.totalSessions;

        const globalScore = ascents * 50;

        return {
            id: climber._id.toString(),
            username: climber.username,
            avatar: climber.avatar || "",
            totalAscents: ascents,
            bestTime: null,
            score: globalScore,
            badges: [],
        };
    });
};
