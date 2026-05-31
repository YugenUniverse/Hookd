const express = require("express");
const router = express.Router();
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");
const eventService = require("../services/event.service");

// Get all active events across facilities (PUBLIC)
router.get("/active", async (req, res, next) => {
    try {
        const events = await eventService.getActiveEvents();
        res.json({ events });
    } catch (err) {
        next(err);
    }
});

// List events for a facility (PUBLIC)
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

// Get single event (PUBLIC)
router.get("/:id", async (req, res, next) => {
    try {
        const event = await eventService.getEventById(req.params.id);
        res.json({ event });
    } catch (err) {
        next(err);
    }
});

// Get event leaderboard (PUBLIC)
router.get("/:id/leaderboard", async (req, res, next) => {
    try {
        const leaderboard = await eventService.getEventLeaderboard(req.params.id);
        res.json({ leaderboard });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// All event routes below require authentication
router.use(authenticateJwt);

// Create event — FacilityOwner or PublicBody
router.post("/", restrictTo("FacilityOwner", "PublicBody"), async (req, res, next) => {
    try {
        const event = await eventService.createEvent(req.user.id, req.body);
        res.status(201).json({ event });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Edit event — must own the event
router.patch("/:id", async (req, res, next) => {
    try {
        const event = await eventService.updateEvent(req.params.id, req.user.id, req.body);
        res.json({ event });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Delete event — must own the event
router.delete("/:id", async (req, res, next) => {
    try {
        await eventService.deleteEvent(req.params.id, req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

// Close event — must own the event
router.post("/:id/close", async (req, res, next) => {
    try {
        const event = await eventService.closeEvent(req.params.id, req.user.id);
        res.json({ event, message: "Event closed and badges distributed successfully" });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

module.exports = router;
