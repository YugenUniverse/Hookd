const badgeService = require("../services/badge.service");

const createBadge = async (req, res, next) => {
    try {
        const payload = { ...req.body, createdBy: req.user.id };
        const badge = await badgeService.createBadge(payload);
        res.status(201).json(badge);
    } catch (error) {
        next(error);
    }
};

const getBadges = async (req, res, next) => {
    try {
        const badges = await badgeService.getBadges(req.query);
        res.status(200).json(badges);
    } catch (error) {
        next(error);
    }
};

const getBadgeById = async (req, res, next) => {
    try {
        const badge = await badgeService.getBadgeById(req.params.id);
        if (!badge) {
            return res.status(404).json({ message: "Badge not found" });
        }
        res.status(200).json(badge);
    } catch (error) {
        next(error);
    }
};

const updateBadge = async (req, res, next) => {
    try {
        const existingBadge = await badgeService.getBadgeById(req.params.id);
        if (!existingBadge) {
            return res.status(404).json({ message: "Badge not found" });
        }
        if (existingBadge.type === "system") {
            return res.status(403).json({ message: "System badges cannot be modified" });
        }
        if (existingBadge.createdBy?.toString() !== req.user.id) {
            return res.status(403).json({ message: "You can only modify badges you created" });
        }

        const badge = await badgeService.updateBadge(req.params.id, req.body);
        res.status(200).json(badge);
    } catch (error) {
        next(error);
    }
};

const deleteBadge = async (req, res, next) => {
    try {
        const existingBadge = await badgeService.getBadgeById(req.params.id);
        if (!existingBadge) {
            return res.status(404).json({ message: "Badge not found" });
        }
        if (existingBadge.type === "system") {
            return res.status(403).json({ message: "System badges cannot be deleted" });
        }
        if (existingBadge.createdBy?.toString() !== req.user.id) {
            return res.status(403).json({ message: "You can only delete badges you created" });
        }

        await badgeService.deleteBadge(req.params.id);
        res.status(200).json({ message: "Badge deleted successfully" });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    createBadge,
    getBadges,
    getBadgeById,
    updateBadge,
    deleteBadge,
};
