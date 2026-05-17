const poiService = require("../services/poi.service");

exports.searchPois = async (req, res, next) => {
    try {
        const { q, type, difficulty } = req.query;
        if (!q || q.trim().length < 2) {
            const err = new Error("Search query must be at least 2 characters");
            err.statusCode = 400;
            return next(err);
        }
        const pois = await poiService.searchPois(q.trim(), { type, difficulty });
        res.json(pois);
    } catch (err) {
        next(err);
    }
};

exports.getNearbyPois = async (req, res, next) => {
    try {
        const { lng, lat, radius = 30000 } = req.query;

        if (!lng || !lat) {
            const err = new Error("lng and lat query parameters are required");
            err.statusCode = 400;
            return next(err);
        }

        const pois = await poiService.getNearbyPois(lng, lat, radius);
        res.json(pois);
    } catch (err) {
        next(err);
    }
};

exports.getAllPois = async (req, res, next) => {
    try {
        const pois = await poiService.getAllPois();
        res.json(pois);
    } catch (err) {
        next(err);
    }
};
