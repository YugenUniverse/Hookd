const mongoose = require("mongoose");
const ClimbingSession = require("../models/ClimbingSession");
const { Wall, IndoorWall, OutdoorWall } = require("../models/Wall");
const { Facility, PublicBody } = require("../models/User");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createWall = async (wallData, userId, userType) => {
    let wall;

    if (userType === "Facility") {
        wall = await IndoorWall.create({ ...wallData, facility: userId });

        await Facility.findByIdAndUpdate(userId, {
            $push: { walls: wall._id },
        });
    } else if (userType === "PublicBody") {
        wall = await OutdoorWall.create({ ...wallData, publicBody: userId });

        await PublicBody.findByIdAndUpdate(userId, {
            $push: { walls: wall._id },
        });
    } else {
        const error = new Error(
            "Only Facilities and Public Bodies can create walls.",
        );
        error.statusCode = 403;
        throw error;
    }
    return wall;
};

exports.getAllWalls = async () => {
    const walls = await Wall.find()
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar")
        .populate("sessions");

    // Ensure rating and totalSessions are up-to-date for each wall
    for (const wall of walls) {
        try {
            await wall.computeRating();
        } catch (e) {
            // ignore compute errors and continue
        }
        const totalSessions = await ClimbingSession.countDocuments({
            wall_id: wall._id,
        });
        wall._totalSessions = totalSessions;
    }

    return walls;
};

exports.getWallById = async (id) => {
    const wall = await Wall.findById(id)
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar")
        .populate("sessions");

    if (!wall) {
        const error = new Error("Wall not found");
        error.statusCode = 404;
        throw error;
    }
    // Recompute rating before returning to ensure up-to-date mean
    try {
        await wall.computeRating();
    } catch (e) {
        // ignore
    }

    const totalSessions = await ClimbingSession.countDocuments({ wall_id: id });
    wall._totalSessions = totalSessions;
    return wall;
};

// getWallSessionCount removed; use Wall virtual `totalSessions` instead

exports.searchWalls = async (searchQuery) => {
    const escaped = searchQuery.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    const walls = await Wall.find({
        name: { $regex: `.*${escaped}.*`, $options: "i" },
    })
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar");

    for (const wall of walls) {
        try {
            await wall.computeRating();
        } catch (e) {}
        const totalSessions = await ClimbingSession.countDocuments({
            wall_id: wall._id,
        });
        wall._totalSessions = totalSessions;
    }

    return walls;
};

exports.getWallsByLocation = async (lng, lat, radius) => {
    return await Wall.find({
        location: {
            $near: {
                $geometry: {
                    type: "Point",
                    coordinates: [parseFloat(lng), parseFloat(lat)],
                },
                $maxDistance: parseInt(radius),
            },
        },
    })
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar");
};

exports.deleteWall = async (id, userId, userType) => {
    const wall = await Wall.findById(id);

    if (!wall) {
        const error = new Error("Wall not found");
        error.statusCode = 404;
        throw error;
    }
    if (userType === "Facility" && wall.facility.toString() !== userId) {
        const error = new Error(
            "You do not have permission to delete this wall",
        );
        error.statusCode = 403;
        throw error;
    }
    if (userType === "PublicBody" && wall.publicBody.toString() !== userId) {
        const error = new Error(
            "You do not have permission to delete this wall",
        );
        error.statusCode = 403;
        throw error;
    }

    if (userType === "Facility") {
        await Facility.findByIdAndUpdate(userId, {
            $pull: { walls: wall._id },
        });
    } else if (userType === "PublicBody") {
        await PublicBody.findByIdAndUpdate(userId, {
            $pull: { walls: wall._id },
        });
    }
    await wall.deleteOne();
};

const getSeasonData = (offset = 0) => {
    const now = new Date();

    const currentQuarter = Math.floor(now.getMonth() / 3);
    const totalQuarters =
        now.getFullYear() * 4 + currentQuarter + parseInt(offset);

    const targetYear = Math.floor(totalQuarters / 4);
    const targetQuarter = totalQuarters % 4;

    const startDate = new Date(targetYear, targetQuarter * 3, 1);
    const endDate = new Date(targetYear, (targetQuarter + 1) * 3, 1);

    const seasonNames = ["Winter", "Spring", "Summer", "Fall"];

    return {
        name: `${seasonNames[targetQuarter]} Season ${targetYear}`,
        startDate,
        endDate,
        isHistorical: offset < 0,
    };
};

exports.getWallLeaderboard = async (wallId, limit = 50, offset = 0) => {
    if (!mongoose.Types.ObjectId.isValid(wallId)) {
        const error = new Error("Invalid wall id");
        error.statusCode = 400;
        throw error;
    }

    const targetSeason = getSeasonData(offset);

    const result = await ClimbingSession.aggregate([
        {
            $match: {
                wall_id: new mongoose.Types.ObjectId(wallId),
            },
        },
        {
            $facet: {
                wallStats: [
                    { $group: { _id: null, averageTime: { $avg: "$time" } } },
                ],

                climberStats: [
                    {
                        $match: {
                            date: {
                                $gte: targetSeason.startDate,
                                $lt: targetSeason.endDate,
                            },
                        },
                    },
                    {
                        $group: {
                            _id: "$climber_id",
                            totalAscents: { $sum: 1 },
                            bestTime: { $min: "$time" },
                        },
                    },
                    {
                        $lookup: {
                            from: "users",
                            localField: "_id",
                            foreignField: "_id",
                            as: "climberInfo",
                        },
                    },
                    { $unwind: "$climberInfo" },
                    {
                        $project: {
                            id: "$_id",
                            username: "$climberInfo.username",
                            avatar: "$climberInfo.avatar",
                            totalAscents: 1,
                            bestTime: 1,
                        },
                    },
                    { $sort: { totalAscents: -1, bestTime: 1 } },
                    { $limit: parseInt(limit) },
                ],
            },
        },
    ]);

    const averageTime = result[0].wallStats[0]?.averageTime || 0;
    const rawLeaderboard = result[0].climberStats;

    if (rawLeaderboard.length === 0) {
        return {
            seasonName: targetSeason.name,
            isHistorical: targetSeason.isHistorical,
            daysRemaining: 0,
            averageTime: Math.round(averageTime),
            leaderboard: [],
        };
    }

    let wallMasterId = null;
    let speedDemonId = null;
    let minTime = Infinity;

    if (rawLeaderboard.length > 0) {
        wallMasterId = rawLeaderboard[0].id.toString();

        rawLeaderboard.forEach((climber) => {
            if (climber.bestTime && climber.bestTime < minTime) {
                minTime = climber.bestTime;
                speedDemonId = climber.id.toString();
            }
        });
    }

    const leaderboard = rawLeaderboard.map((climber) => {
        const badges = [];
        let score = 0;

        score += climber.totalAscents * 50;

        if (averageTime > 0 && climber.bestTime < averageTime) {
            const percentFaster =
                ((averageTime - climber.bestTime) / averageTime) * 100;
            const outlierBonus = Math.round(percentFaster * 10);
            score += outlierBonus;
        }

        if (climber.id.toString() === wallMasterId) badges.push("WALL_MASTER");
        if (climber.id.toString() === speedDemonId) badges.push("SPEED_DEMON");

        return {
            id: climber.id.toString(),
            username: climber.username,
            avatar: climber.avatar,
            totalAscents: climber.totalAscents,
            bestTime: climber.bestTime,
            score: score,
            badges: badges,
        };
    });

    leaderboard.sort((a, b) => b.score - a.score);

    let daysRemaining = 0;
    if (!targetSeason.isHistorical) {
        const msPerDay = 1000 * 60 * 60 * 24;
        daysRemaining = Math.ceil(
            (targetSeason.endDate - new Date()) / msPerDay,
        );
    }

    return {
        seasonName: targetSeason.name,
        isHistorical: targetSeason.isHistorical,
        daysRemaining: daysRemaining,
        averageTime: Math.round(averageTime),
        leaderboard,
    };
};

exports.getUserWalls = async (userId, userType) => {
    if (userType === "Facility") {
        return await Wall.find({ facility: userId });
    } else if (userType === "PublicBody") {
        return await Wall.find({ publicBody: userId });
    } else {
        const error = new Error("Invalid user type");
        error.statusCode = 400;
        throw error;
    }
};
