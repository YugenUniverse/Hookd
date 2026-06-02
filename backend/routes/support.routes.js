const express = require("express");
const mongoose = require("mongoose");
const { authenticateJwt } = require("../middleware/auth.middleware");
const supportController = require("../controllers/support.controller");
const { CATEGORY_ENUM } = require("../models/SupportTicket");

const router = express.Router();

const validateCreateTicket = (req, res, next) => {
    const { subject, body, category } = req.body;

    if (!subject || !body) {
        return res.status(400).json({ error: "subject and body are required" });
    }
    if (typeof subject !== "string" || subject.trim().length === 0) {
        return res.status(400).json({ error: "subject cannot be empty" });
    }
    if (subject.length > 200) {
        return res.status(400).json({ error: "subject cannot exceed 200 characters" });
    }
    if (typeof body !== "string" || body.trim().length === 0) {
        return res.status(400).json({ error: "body cannot be empty" });
    }
    if (body.length > 2000) {
        return res.status(400).json({ error: "body cannot exceed 2000 characters" });
    }
    if (category && !CATEGORY_ENUM.includes(category)) {
        return res.status(400).json({
            error: `Invalid category. Valid values are: ${CATEGORY_ENUM.join(", ")}`,
        });
    }
    next();
};

const validateTicketId = (req, res, next) => {
    if (!mongoose.Types.ObjectId.isValid(req.params.ticketId)) {
        return res.status(400).json({ error: "ticketId must be a valid ObjectId" });
    }
    next();
};

router.use(authenticateJwt);

router.post("/", validateCreateTicket, supportController.createTicket);
router.get("/mine", supportController.getMyTickets);
router.get("/:ticketId", validateTicketId, supportController.getTicket);

module.exports = router;
