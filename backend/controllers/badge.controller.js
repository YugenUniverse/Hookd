const badgeService = require("../services/badge.service");
const eventService = require("../services/event.service");
const Group = require("../models/Group");

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
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot create badges for a closed event" });
            }

            if (event.groupId) {
                const group = await Group.findById(event.groupId);
                if (!group) {
                    return res.status(404).json({ message: "Group not found" });
                }
                const member = group.members.find(m => m.user.toString() === req.user.id);
                if (!member || (member.role !== "admin" && member.role !== "manager")) {
                    return res.status(403).json({ message: "You must be an admin or manager of the group to create badges for this event" });
                }
                payload.groupId = event.groupId;
            } else if (event.createdBy.toString() !== req.user.id) {
                return res.status(403).json({ message: "You can only create badges for your own events" });
            }
        } else if (!["FacilityOwner", "PublicBody"].includes(req.user.userType)) {
            return res.status(403).json({ message: "Only Facility Owners and Public Bodies can create system badges" });
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

        if (existingBadge.eventId) {
            const event = await eventService.getEventById(existingBadge.eventId);
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot modify a badge belonging to a closed event" });
            }
            if (event.groupId) {
                const group = await Group.findById(event.groupId);
                if (!group) return res.status(404).json({ message: "Group not found" });
                const member = group.members.find(m => m.user.toString() === req.user.id);
                if (!member || (member.role !== "admin" && member.role !== "manager")) {
                    return res.status(403).json({ message: "You must be an admin or manager of the group to modify badges for this event" });
                }
            } else if (existingBadge.createdBy?.toString() !== req.user.id) {
                return res.status(403).json({ message: "You can only modify badges you created" });
            }
        } else if (existingBadge.createdBy?.toString() !== req.user.id) {
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

        if (existingBadge.eventId) {
            const event = await eventService.getEventById(existingBadge.eventId);
            if (event.status === "closed") {
                return res.status(400).json({ message: "Cannot delete a badge belonging to a closed event" });
            }
            if (event.groupId) {
                const group = await Group.findById(event.groupId);
                if (!group) return res.status(404).json({ message: "Group not found" });
                const member = group.members.find(m => m.user.toString() === req.user.id);
                if (!member || (member.role !== "admin" && member.role !== "manager")) {
                    return res.status(403).json({ message: "You must be an admin or manager of the group to delete badges for this event" });
                }
            } else if (existingBadge.createdBy?.toString() !== req.user.id) {
                return res.status(403).json({ message: "You can only delete badges you created" });
            }
        } else if (existingBadge.createdBy?.toString() !== req.user.id) {
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
