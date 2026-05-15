const poiService = require("../services/poi.service");

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
