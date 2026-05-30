const { Climber } = require("../models/User");
const Badge = require("../models/Badge");
const Group = require("../models/Group");

exports.getGlobalLeaderboard = async (limit = 50) => {
    const rawLeaderboard = await Climber.aggregate([
        {
            $project: {
                username: 1,
                name: 1,
                surname: 1,
                avatar: 1,
                wallet: 1,
                totalSessions: { $size: { $ifNull: ["$sessions", []] } },
                computedScore: {
                    $add: [
                        { $multiply: [{ $size: { $ifNull: ["$sessions", []] } }, 50] },
                        { $ifNull: ["$wallet.score", 0] }
                    ]
                }
            },
        },
        { $sort: { computedScore: -1 } },
        { $limit: limit },
    ]);

    return rawLeaderboard.map((climber) => {
        const ascents = climber.totalSessions;
        const globalScore = climber.computedScore;

        return {
            id: climber._id.toString(),
            username: climber.username,
            avatar: climber.avatar || "",
            totalAscents: ascents,
            bestTime: null,
            score: globalScore,
            badges: climber.wallet?.badges || [],
        };
    });
};

exports.acquireBadge = async (climberId, badgeId) => {
    const climber = await Climber.findById(climberId);
    if (!climber) throw new Error("Climber not found");

    const badge = await Badge.findById(badgeId);
    if (!badge) throw new Error("Badge not found");

    if (!climber.wallet) {
        climber.wallet = { score: 0, badges: [] };
    }

    if (!badge.reEarnable) {
        const hasBadge = climber.wallet.badges.some((b) => b.badge.toString() === badgeId);
        if (hasBadge) throw new Error("Climber already has this badge");
    }

    climber.wallet.badges.push({ badge: badge._id });

    if (badge.groupId) {
        // Group badge: update member's score inside the group
        const group = await Group.findById(badge.groupId);
        if (group) {
            const memberIndex = group.members.findIndex(m => m.user.toString() === climberId.toString());
            if (memberIndex !== -1) {
                group.members[memberIndex].score += (badge.score || 0);
                await group.save();
            }
        }
    } else {
        // Public badge: update global wallet score
        climber.wallet.score += (badge.score || 0);
    }

    await climber.save();

    return climber.wallet;
};
