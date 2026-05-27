const mongoose = require("mongoose");
const Event = require("../models/Event");
const { FacilityOwner } = require("../models/User");
const notificationService = require("./notification.service");
const followService = require("./follow.service");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createEvent = async (userId, { title, description, startDate, endDate }) => {
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

exports.updateEvent = async (eventId, userId, { title, description, startDate, endDate }) => {
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
    if (title !== undefined) event.title = title;
    if (description !== undefined) event.description = description;
    if (startDate !== undefined) event.startDate = startDate;
    if (endDate !== undefined) event.endDate = endDate;
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
    await Event.findByIdAndDelete(eventId);
};
