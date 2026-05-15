const wallService = require("../services/wall.service");

exports.createWall = async (req, res, next) => {
    try {
        const wall = await wallService.createWall(
            req.body,
            req.user.id,
            req.user.userType,
        );

        res.status(201).json({
            message: "Wall created successfully",
            wall,
        });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
};

exports.getAllWalls = async (req, res, next) => {
    try {
        const walls = await wallService.getAllWalls();
        res.status(200).json(walls);
    } catch (err) {
        next(err);
    }
};

exports.getWallById = async (req, res, next) => {
    try {
        const wall = await wallService.getWallById(req.params.id);
        res.status(200).json(wall);
    } catch (err) {
        next(err);
    }
};

exports.searchWalls = async (req, res, next) => {
    try {
        if (!req.query.q) {
            return res
                .status(400)
                .json({ message: "Please provide a search query (?q=...)" });
        }
        const walls = await wallService.searchWalls(req.query.q);
        res.status(200).json(walls);
    } catch (err) {
        next(err);
    }
};

exports.getWallsByLocation = async (req, res, next) => {
    try {
        const { lng, lat, radius = 10000 } = req.query;

        if (!lng || !lat) {
            return res.status(400).json({
                message: "Please provide both lng and lat query parameters.",
            });
        }

        const walls = await wallService.getWallsByLocation(lng, lat, radius);
        res.status(200).json(walls);
    } catch (err) {
        next(err);
    }
};

exports.deleteWall = async (req, res, next) => {
    try {
        await wallService.deleteWall(
            req.params.id,
            req.user.id,
            req.user.userType,
        );

        res.status(200).json({
            message: "Wall deleted successfully",
        });
    } catch (err) {
        next(err);
    }
};

exports.getWallLeaderboard = async (req, res, next) => {
    try {
        const limit = req.query.limit ? parseInt(req.query.limit) : 50;
        const offset = req.query.offset ? parseInt(req.query.offset) : 0;

        if (Number.isNaN(limit) || limit <= 0) {
            return res.status(400).json({
                message: "Limit must be a positive integer greater than 0.",
            });
        }

        if (Number.isNaN(offset) || offset > 0) {
            return res.status(400).json({
                message:
                    "Offset must be 0 (current season) or a negative integer (e.g., -1 for last season).",
            });
        }
        const leaderboardData = await wallService.getWallLeaderboard(
            req.params.id,
            limit,
            offset,
        );

        res.status(200).json(leaderboardData);
    } catch (err) {
        next(err);
    }
};
