const mongoose = require("mongoose");

const CATEGORY_ENUM = ["ACCOUNT", "BUG", "CONTENT", "OTHER"];
const STATUS_ENUM = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];

const supportTicketSchema = new mongoose.Schema(
    {
        user_id: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
            required: true,
        },
        subject: {
            type: String,
            required: true,
            trim: true,
            maxlength: [200, "Subject cannot exceed 200 characters"],
        },
        body: {
            type: String,
            required: true,
            trim: true,
            maxlength: [2000, "Body cannot exceed 2000 characters"],
        },
        category: {
            type: String,
            enum: CATEGORY_ENUM,
            default: "OTHER",
        },
        status: {
            type: String,
            enum: STATUS_ENUM,
            default: "OPEN",
        },
        admin_reply: {
            type: String,
            trim: true,
            maxlength: [2000, "Admin reply cannot exceed 2000 characters"],
            default: null,
        },
        replied_at: {
            type: Date,
            default: null,
        },
        replied_by: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
            default: null,
        },
    },
    {
        timestamps: true,
        toJSON: {
            transform: (doc, ret) => {
                ret.id = ret._id;
                delete ret._id;
                delete ret.__v;
                return ret;
            },
        },
    },
);

supportTicketSchema.index({ user_id: 1, status: 1 });
supportTicketSchema.index({ status: 1, createdAt: -1 });

const SupportTicket = mongoose.model("SupportTicket", supportTicketSchema);

module.exports = { SupportTicket, CATEGORY_ENUM, STATUS_ENUM };
