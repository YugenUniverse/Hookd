const express = require("express");
const mongoose = require("mongoose");
const adminController = require("../controllers/admin.controller");
const supportController = require("../controllers/support.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");
const { STATUS_ENUM, CATEGORY_ENUM } = require("../models/SupportTicket");

const router = express.Router();

router.use(authenticateJwt, restrictTo("Admin"));

router.get("/approvals/pending", adminController.getPendingApprovals);
router.put("/approvals/:userId/approve", adminController.approveAccount);
router.put("/approvals/:userId/reject", adminController.rejectAccount);

router.get("/moderation/flagged", adminController.getFlaggedReviews);
router.delete("/moderation/reviews/:reviewId", adminController.removeReview);
router.post("/moderation/reviews/:reviewId/dismiss", adminController.dismissFlag);

const validateTicketId = (req, res, next) => {
    if (!mongoose.Types.ObjectId.isValid(req.params.ticketId)) {
        return res.status(400).json({ error: "ticketId must be a valid ObjectId" });
    }
    next();
};

const validateReply = (req, res, next) => {
    const { reply, status } = req.body;
    if (!reply || typeof reply !== "string" || reply.trim().length === 0) {
        return res.status(400).json({ error: "reply is required" });
    }
    if (reply.length > 2000) {
        return res.status(400).json({ error: "reply cannot exceed 2000 characters" });
    }
    if (status && !STATUS_ENUM.includes(status)) {
        return res.status(400).json({ error: `Invalid status. Valid values are: ${STATUS_ENUM.join(", ")}` });
    }
    next();
};

const validateStatus = (req, res, next) => {
    const { status } = req.body;
    if (!status || typeof status !== "string") {
        return res.status(400).json({ error: "status is required" });
    }
    if (!STATUS_ENUM.includes(status)) {
        return res.status(400).json({ error: `Invalid status. Valid values are: ${STATUS_ENUM.join(", ")}` });
    }
    next();
};

router.get("/support/tickets", supportController.getAllTickets);
router.get("/support/tickets/:ticketId", validateTicketId, supportController.getTicketAdmin);
router.patch("/support/tickets/:ticketId/reply", validateTicketId, validateReply, supportController.replyToTicket);
router.patch("/support/tickets/:ticketId/status", validateTicketId, validateStatus, supportController.updateTicketStatus);

module.exports = router;
