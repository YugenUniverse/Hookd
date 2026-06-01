const mongoose = require("mongoose");
const Event = require("../models/Event");
const Group = require("../models/Group");
const { User, FacilityOwner } = require("../models/User");
const notificationService = require("./notification.service");
const followService = require("./follow.service");
const ClimbingSession = require("../models/ClimbingSession");
const { Wall } = require("../models/Wall");
const Badge = require("../models/Badge");
const climberService = require("./climber.service");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createEvent = async (userId, eventData) => {
    const { title, description, startDate, endDate, walls, groupId, facilityId } = eventData;

    if (!title || !startDate) {
        const err = new Error("Title and Start Date are required");
        err.statusCode = 400;
        throw err;
    }

    const user = await User.findById(userId);
    if (!user) {
        const err = new Error("User not found");
        err.statusCode = 404;
        throw err;
    }

    let isGlobal = false;
    let facility = facilityId || null;

    if (groupId) {
        if (!isValidObjectId(groupId)) {
            const err = new Error("Invalid group id");
            err.statusCode = 400;
            throw err;
        }
        const group = await Group.findById(groupId);
        if (!group) {
            const err = new Error("Group not found");
            err.statusCode = 404;
            throw err;
        }
        const member = group.members.find(m => m.user.toString() === userId.toString());
        if (!member || !["admin", "manager"].includes(member.role)) {
            const err = new Error("Only group admins or managers can create group events");
            err.statusCode = 403;
            throw err;
        }
    } else {
        if (user.userType === "PublicBody") {
            isGlobal = true;
        } else if (user.userType === "FacilityOwner") {
            const owner = await FacilityOwner.findById(userId).select("facility");
            if (!owner?.facility) {
                const err = new Error("You must be linked to a facility to create local events");
                err.statusCode = 403;
                throw err;
            }
            facility = owner.facility;
        } else {
            const err = new Error("Unauthorized to create events");
            err.statusCode = 403;
            throw err;
        }
    }

    const event = await Event.create({
        title,
        description,
        startDate,
        endDate,
        facility: facility,
        groupId: groupId,
        isGlobal: isGlobal,
        createdBy: userId,
        walls: walls || [],
    });

    // Notify all users following the event creator
    const recipientIds = await followService.getFollowerIds(userId);

    await notificationService.createBulk(recipientIds, "new_event", {
        eventId: event._id.toString(),
        eventTitle: event.title,
        facilityId: facility ? facility.toString() : "global",
    });

    return event;
};


exports.getActiveEvents = async () => {
    return await Event.find({ status: 'active', groupId: { $exists: false } }).populate('facility');
};

exports.getEventsForGroup = async (groupId, { limit = 50, skip = 0 } = {}) => {
    if (!isValidObjectId(groupId)) {
        const err = new Error("Invalid group id");
        err.statusCode = 400;
        throw err;
    }
    return Event.find({ groupId: groupId })
        .sort({ startDate: -1 })
        .skip(skip)
        .limit(limit);
};

exports.getEventsForFacility = async (facilityId, { limit = 50, skip = 0 } = {}) => {
    if (facilityId === 'global') {
        return Event.find({ isGlobal: true, groupId: { $exists: false } })
            .sort({ startDate: 1 })
            .skip(skip)
            .limit(limit);
    }
    if (!isValidObjectId(facilityId)) {
        const err = new Error("Invalid facility id");
        err.statusCode = 400;
        throw err;
    }
    return Event.find({ facility: facilityId, groupId: { $exists: false } })
        .sort({ startDate: 1 })
        .skip(skip)
        .limit(limit);
};

exports.getEventById = async (eventId) => {
    if (!isValidObjectId(eventId)) {
        const err = new Error("Invalid event id");
        err.statusCode = 400;
        throw err;
    }
    const event = await Event.findById(eventId);
    if (!event) {
        const err = new Error("Event not found");
        err.statusCode = 404;
        throw err;
    }
    return event;
};

exports.updateEvent = async (eventId, userId, { title, description, startDate, endDate, walls }) => {
    if (!isValidObjectId(eventId)) {
        const err = new Error("Invalid event id");
        err.statusCode = 400;
        throw err;
    }
    const event = await Event.findById(eventId);
    if (!event) {
        const err = new Error("Event not found");
        err.statusCode = 404;
        throw err;
    }
    if (event.createdBy.toString() !== userId.toString()) {
        const err = new Error("You can only edit your own events");
        err.statusCode = 403;
        throw err;
    }
    if (event.status === "closed") {
        const err = new Error("Cannot edit a closed event");
        err.statusCode = 400;
        throw err;
    }
    if (title !== undefined) event.title = title;
    if (description !== undefined) event.description = description;
    if (startDate !== undefined) event.startDate = startDate;
    if (endDate !== undefined) event.endDate = endDate;
    if (walls !== undefined) event.walls = walls;
    await event.save();
    return event;
};

exports.deleteEvent = async (eventId, userId) => {
    if (!isValidObjectId(eventId)) {
        const err = new Error("Invalid event id");
        err.statusCode = 400;
        throw err;
    }
    const event = await Event.findById(eventId);
    if (!event) {
        const err = new Error("Event not found");
        err.statusCode = 404;
        throw err;
    }
    if (event.createdBy.toString() !== userId.toString()) {
        const err = new Error("You can only delete your own events");
        err.statusCode = 403;
        throw err;
    }
    if (event.status === "closed") {
        const err = new Error("Cannot delete a closed event");
        err.statusCode = 400;
        throw err;
    }
    await Event.findByIdAndDelete(eventId);
};


async function computeLeaderboard(event) {
    const difficultyWeights = {
        BEGINNER: 50,
        INTERMEDIATE: 75,
        ADVANCED: 100,
        EXPERT: 150
    };

    let sessions = [];
    const climberStats = {};

    let groupMemberIds = null;
    if (event.groupId) {
        const group = await Group.findById(event.groupId).select('members');
        if (group) {
            groupMemberIds = group.members.map(m => m.user.toString());
        }
    }

    if (event.isGlobal || (!event.facility && !event.walls?.length)) {
        let query = { date: { $gte: event.startDate, $lte: event.endDate || new Date() } };
        if (groupMemberIds) {
            query.climber_id = { $in: groupMemberIds };
        }
        sessions = await ClimbingSession.find(query).populate("wall_id");

        sessions.forEach(s => {
            const cId = s.climber_id.toString();
            // If wall_id was deleted or not found, default to BEGINNER
            const diff = (s.wall_id && s.wall_id.difficulty) ? s.wall_id.difficulty : "BEGINNER";
            const points = difficultyWeights[diff] || 50;

            if (!climberStats[cId]) {
                climberStats[cId] = { climberId: cId, score: 0, sessions: 0 };
            }
            climberStats[cId].score += points;
            climberStats[cId].sessions += 1;
        });
    } else {
        let walls = [];
        if (event.walls && event.walls.length > 0) {
            walls = await Wall.find({ _id: { $in: event.walls } });
        } else {
            walls = await Wall.find({ facility: event.facility });
        }
        const wallMap = {};
        walls.forEach(w => { wallMap[w._id.toString()] = w.difficulty; });
        const wallIds = walls.map(w => w._id);

        let query = {
            wall_id: { $in: wallIds },
            date: { $gte: event.startDate, $lte: event.endDate || new Date() }
        };
        if (groupMemberIds) {
            query.climber_id = { $in: groupMemberIds };
        }

        sessions = await ClimbingSession.find(query);

        sessions.forEach(s => {
            const cId = s.climber_id.toString();
            const diff = wallMap[s.wall_id.toString()] || "BEGINNER";
            const points = difficultyWeights[diff] || 50;

            if (!climberStats[cId]) {
                climberStats[cId] = { climberId: cId, score: 0, sessions: 0 };
            }
            climberStats[cId].score += points;
            climberStats[cId].sessions += 1;
        });
    }



    let leaderboard = Object.values(climberStats);
    leaderboard.sort((a, b) => b.score - a.score);
    leaderboard.forEach((c, i) => { c.rank = i + 1; });

    return leaderboard;
}

exports.closeEvent = async (eventId, userId) => {
    if (!isValidObjectId(eventId)) {
        const err = new Error("Invalid event id");
        err.statusCode = 400;
        throw err;
    }

    const event = await Event.findById(eventId);
    if (!event) {
        const err = new Error("Event not found");
        err.statusCode = 404;
        throw err;
    }

    if (event.createdBy.toString() !== userId.toString()) {
        const err = new Error("You can only close your own events");
        err.statusCode = 403;
        throw err;
    }

    if (event.status === "closed") {
        const err = new Error("Event is already closed");
        err.statusCode = 400;
        throw err;
    }

    event.status = "closed";
    await event.save();
    const leaderboard = await computeLeaderboard(event);

    const badges = await Badge.find({ eventId: event._id });

    for (const badge of badges) {
        if (!badge.winningCondition) continue;

        const { metric, operator, value } = badge.winningCondition;
        let winners = [];

        leaderboard.forEach(c => {
            let metricValue = c[metric]; // rank, score, or sessions
            let isWinner = false;

            if (operator === "top") {
                if (metricValue <= value) isWinner = true;
            } else if (operator === "gte") {
                if (metricValue >= value) isWinner = true;
            }

            if (isWinner) winners.push(c.climberId);
        });

        for (const winnerId of winners) {
            try {
                await climberService.acquireBadge(winnerId, badge._id);
                console.log(`Badge ${badge._id} assigned to ${winnerId} for event ${event._id}`);
                await notificationService.createBulk([winnerId], "badge_awarded", {
                    badgeName: badge.name,
                    badgeLevel: badge.level,
                    eventId: event._id.toString(),
                    eventTitle: event.title,
                });
            } catch (e) {
                // Ignore if they already have it
            }
        }
    }

    return event;
};


exports.getEventLeaderboard = async (eventId) => {
    if (!isValidObjectId(eventId)) {
        const err = new Error("Invalid event id");
        err.statusCode = 400;
        throw err;
    }
    const event = await Event.findById(eventId);
    if (!event) {
        const err = new Error("Event not found");
        err.statusCode = 404;
        throw err;
    }

    const leaderboard = await computeLeaderboard(event);
    const badges = await Badge.find({ eventId: event._id });
    
    const User = require('../models/User').Climber;

    const enrichedLeaderboard = [];
    for (const entry of leaderboard) {
        const user = await User.findById(entry.climberId);
        if (!user) continue;

        // Determine if they got a badge
        const wonBadges = [];
        for (const badge of badges) {
            if (!badge.winningCondition) continue;
            const { metric, operator, value } = badge.winningCondition;
            let metricValue = entry[metric];
            let isWinner = false;
            if (operator === "top") {
                if (metricValue <= value) isWinner = true;
            } else if (operator === "gte") {
                if (metricValue >= value) isWinner = true;
            }
            if (isWinner) {
                // Return the badge object
                wonBadges.push(badge.toJSON());
            }
        }

        enrichedLeaderboard.push({
            ...entry,
            climberName: user.username || user.firstName,
            badges: wonBadges
        });
    }

    return enrichedLeaderboard;
};
