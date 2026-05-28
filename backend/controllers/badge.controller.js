const badgeService = require("../services/badge.service");
const eventService = require("../services/event.service");

const createBadge = async (req, res, next) => {
    try {
        const payload = { ...req.body, createdBy: req.user.id };

        if (payload.type === "event") {
            if (!payload.eventId) {
                return res.status(400).json({ message: "eventId is required for event badges" });
            }
            if (!payload.winningCondition || !payload.winningCondition.metric || !payload.winningCondition.operator || payload.winningCondition.value === undefined) {
                return res.status(400).json({ message: "winningCondition with metric, operator, and value is required for event badges" });
            }
            

            const event = await eventService.getEventById(payload.eventId);
            if (event.createdBy.toString() !== req.user.id) {
                return res.status(403).json({ message: "You can only create badges for your own events" });
            }
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot create badges for a closed event" });
            }

        }

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
        if (existingBadge.eventId) {
            const event = await eventService.getEventById(existingBadge.eventId);
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot modify a badge belonging to a closed event" });
            }
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
        if (existingBadge.eventId) {
            const event = await eventService.getEventById(existingBadge.eventId);
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot delete a badge belonging to a closed event" });
            }
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
