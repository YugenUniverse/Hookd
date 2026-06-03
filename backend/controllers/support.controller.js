const supportService = require("../services/support.service");

exports.createTicket = async (req, res, next) => {
    try {
        const ticket = await supportService.createTicket(req.user.id, req.body);
        res.status(201).json({ ticket });
    } catch (err) {
        next(err);
    }
};

exports.getMyTickets = async (req, res, next) => {
    try {
        const { limit, skip } = req.query;
        const tickets = await supportService.getTicketsByUser(req.user.id, {
            limit: limit ? parseInt(limit, 10) : undefined,
            skip: skip ? parseInt(skip, 10) : undefined,
        });
        res.json({ tickets });
    } catch (err) {
        next(err);
    }
};

exports.getTicket = async (req, res, next) => {
    try {
        const ticket = await supportService.getTicketById(req.params.ticketId, req.user.id);
        res.json({ ticket });
    } catch (err) {
        next(err);
    }
};

exports.getAllTickets = async (req, res, next) => {
    try {
        const { status, category, limit, skip } = req.query;
        const tickets = await supportService.getAllTickets(
            { status, category },
            {
                limit: limit ? parseInt(limit, 10) : undefined,
                skip: skip ? parseInt(skip, 10) : undefined,
            },
        );
        res.json({ tickets });
    } catch (err) {
        next(err);
    }
};

exports.getTicketAdmin = async (req, res, next) => {
    try {
        const ticket = await supportService.getTicketByIdAdmin(req.params.ticketId);
        res.json({ ticket });
    } catch (err) {
        next(err);
    }
};

exports.replyToTicket = async (req, res, next) => {
    try {
        const ticket = await supportService.replyToTicket(
            req.params.ticketId,
            req.user.id,
            req.body,
        );
        res.json({ ticket });
    } catch (err) {
        next(err);
    }
};

exports.updateTicketStatus = async (req, res, next) => {
    try {
        const ticket = await supportService.updateTicketStatus(
            req.params.ticketId,
            req.body.status,
        );
        res.json({ ticket });
    } catch (err) {
        next(err);
    }
};
