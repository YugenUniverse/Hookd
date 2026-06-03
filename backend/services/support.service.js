const { SupportTicket, STATUS_ENUM } = require("../models/SupportTicket");
const notificationService = require("./notification.service");
const emailService = require("./email.service");

exports.createTicket = async (userId, { subject, body, category }) => {
    const ticket = new SupportTicket({
        user_id: userId,
        subject,
        body,
        category: category || "OTHER",
    });
    return ticket.save();
};

exports.getTicketsByUser = async (userId, { limit = 20, skip = 0 } = {}) => {
    return SupportTicket.find({ user_id: userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);
};

exports.getTicketById = async (ticketId, userId) => {
    const ticket = await SupportTicket.findById(ticketId);
    if (!ticket) {
        const err = new Error("Ticket not found");
        err.statusCode = 404;
        throw err;
    }
    if (ticket.user_id.toString() !== userId.toString()) {
        const err = new Error("Forbidden");
        err.statusCode = 403;
        throw err;
    }
    return ticket;
};

exports.getAllTickets = async ({ status, category } = {}, { limit = 50, skip = 0 } = {}) => {
    const query = {};
    if (status) query.status = Array.isArray(status) ? { $in: status } : status;
    if (category) query.category = Array.isArray(category) ? { $in: category } : category;

    return SupportTicket.find(query)
        .populate("user_id", "username email")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);
};

exports.getTicketByIdAdmin = async (ticketId) => {
    const ticket = await SupportTicket.findById(ticketId).populate("user_id", "username email");
    if (!ticket) {
        const err = new Error("Ticket not found");
        err.statusCode = 404;
        throw err;
    }
    return ticket;
};

exports.replyToTicket = async (ticketId, adminId, { reply, status }) => {
    const ticket = await SupportTicket.findById(ticketId).populate("user_id", "username email");
    if (!ticket) {
        const err = new Error("Ticket not found");
        err.statusCode = 404;
        throw err;
    }

    if (status) {
        if (!STATUS_ENUM.includes(status)) {
            const err = new Error(`Invalid status: ${status}`);
            err.statusCode = 400;
            throw err;
        }
        ticket.status = status;
    } else {
        ticket.status = "IN_PROGRESS";
    }

    ticket.admin_reply = reply;
    ticket.replied_at = new Date();
    ticket.replied_by = adminId;

    await ticket.save();

    const user = ticket.user_id;
    if (user) {
        await notificationService.createBulk([user._id || user], "support_ticket_replied", {
            ticketId: ticket._id,
            subject: ticket.subject,
        });
        await emailService.sendSupportReplyEmail(user, ticket, reply);
    }

    return ticket;
};

exports.updateTicketStatus = async (ticketId, status) => {
    if (!STATUS_ENUM.includes(status)) {
        const err = new Error(`Invalid status: ${status}`);
        err.statusCode = 400;
        throw err;
    }
    const ticket = await SupportTicket.findByIdAndUpdate(
        ticketId,
        { status },
        { new: true },
    );
    if (!ticket) {
        const err = new Error("Ticket not found");
        err.statusCode = 404;
        throw err;
    }
    return ticket;
};
