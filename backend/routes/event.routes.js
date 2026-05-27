const express = require("express");
const router = express.Router();
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");
const eventService = require("../services/event.service");

// All event routes require authentication
router.use(authenticateJwt);

// Create event — FacilityOwner only
router.post("/", restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        const event = await eventService.createEvent(req.user.id, req.body);
        res.status(201).json({ event });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// List events for a facility
router.get("/", async (req, res, next) => {
    try {
        const { facilityId, limit, skip } = req.query;
        if (!facilityId) {
            return res.status(400).json({ error: "facilityId query param is required" });
        }
        const events = await eventService.getEventsForFacility(facilityId, {
            limit: limit ? parseInt(limit) : undefined,
            skip: skip ? parseInt(skip) : undefined,
        });
        res.json({ events });
    } catch (err) {
        next(err);
    }
});

// Get single event
router.get("/:id", async (req, res, next) => {
    try {
        const event = await eventService.getEventById(req.params.id);
        res.json({ event });
    } catch (err) {
        next(err);
    }
});

// Edit event — FacilityOwner only (must own the event)
router.patch("/:id", restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        const event = await eventService.updateEvent(req.params.id, req.user.id, req.body);
        res.json({ event });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Delete event — FacilityOwner only (must own the event)
router.delete("/:id", restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        await eventService.deleteEvent(req.params.id, req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

module.exports = router;
