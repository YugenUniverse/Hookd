const mongoose = require("mongoose");
const { Climber } = require("../models/User");
const { Wall } = require("../models/Wall");

const issueReportSchema = new mongoose.Schema({
    climber_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Climber",
        required: true,
    },
    wall_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Wall",
        required: true,
    },
    body: {
        type: String,
        required: true,
        trim: true,
        maxlength: [500, "Issue report body cannot exceed 500 characters"],
    },
});

module.exports = mongoose.model("IssueReport", issueReportSchema);
