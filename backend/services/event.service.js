const mongoose = require("mongoose");
const Event = require("../models/Event");
const { FacilityOwner } = require("../models/User");
const notificationService = require("./notification.service");
const followService = require("./follow.service");
const ClimbingSession = require("../models/ClimbingSession");
const { Wall } = require("../models/Wall");
const Badge = require("../models/Badge");
const climberService = require("./climber.service");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createEvent = async (userId, { title, description, startDate, endDate, walls }) => {
    if (!title || !startDate) {
        const err = new Error("title and startDate are required");
        err.statusCode = 400;
        throw err;
    }

    const owner = await FacilityOwner.findById(userId).select("facility");
    if (!owner?.facility) {
        const err = new Error("You must be linked to a facility to create events");
        err.statusCode = 403;
        throw err;
    }

    const event = await Event.create({
        title,
        description,
        startDate,
        endDate,
        facility: owner.facility,
        createdBy: userId,
        walls: walls || [],
    });

    // Notify all users following the event creator
    const recipientIds = await followService.getFollowerIds(userId);

    await notificationService.createBulk(recipientIds, "new_event", {
        eventId: event._id.toString(),
        eventTitle: event.title,
        facilityId: owner.facility.toString(),
    });

    return event;
};


exports.getActiveEvents = async () => {
    return await Event.find({ status: 'active' }).populate('facility');
};

exports.getEventsForFacility = async (facilityId, { limit = 50, skip = 0 } = {}) => {
    if (!isValidObjectId(facilityId)) {
        const err = new Error("Invalid facility id");
        err.statusCode = 400;
        throw err;
    }
    return Event.find({ facility: facilityId })
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
    let walls = [];
    if (event.walls && event.walls.length > 0) {
        walls = await Wall.find({ _id: { $in: event.walls } });
    } else {
        walls = await Wall.find({ facility: event.facility });
    }
    const wallMap = {};
    walls.forEach(w => { wallMap[w._id.toString()] = w.difficulty; });
    const wallIds = walls.map(w => w._id);

    const difficultyWeights = {
        BEGINNER: 50,
        INTERMEDIATE: 75,
        ADVANCED: 100,
        EXPERT: 150
    };

    const sessions = await ClimbingSession.find({
        wall_id: { $in: wallIds },
        date: { $gte: event.startDate, $lte: event.endDate || new Date() }
    });

    const climberStats = {};
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
