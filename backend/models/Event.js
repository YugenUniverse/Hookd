const mongoose = require("mongoose");

const eventSchema = new mongoose.Schema(
    {
        title: {
            type: String,
            required: [true, "Title is required"],
            trim: true,
            maxlength: [100, "Title cannot exceed 100 characters"],
        },
        description: {
            type: String,
            trim: true,
            maxlength: [1000, "Description cannot exceed 1000 characters"],
        },
        isGlobal: {
            type: Boolean,
            default: false,
        },
        facility: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Facility",
            required: function() {
                return !this.isGlobal && !this.groupId;
            },
        },
        groupId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Group",
        },
        createdBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
            required: true,
        },
        walls: [{
            type: mongoose.Schema.Types.ObjectId,
            ref: "IndoorWall"
        }],
        startDate: {
            type: Date,
            required: [true, "Start date is required"],
        },
        endDate: {
            type: Date,
            validate: {
                validator: function (val) {
                    return !val || val >= this.startDate;
                },
                message: "End date must be on or after start date",
            },
        },
        status: {
            type: String,
            enum: ["active", "closed"],
            default: "active",
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

module.exports = mongoose.model("Event", eventSchema);
