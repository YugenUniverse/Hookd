const mongoose = require("mongoose");
const { IssueReport } = require("../models/IssueReport");
const { Wall } = require("../models/Wall");
const { User } = require("../models/User");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createIssueReport = async (userId, userType, { wall_id, body }) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can create reports");
        error.statusCode = 403;
        throw error;
    }

    if (!wall_id || !body) {
        const error = new Error("wall_id and body are required");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(wall_id)) {
        const error = new Error("wall_id must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const report = await IssueReport.create({
        climber_id: userId,
        wall_id,
        body,
    });

    return report;
};

exports.getIssueReportsForWall = async (userId, userType, wallId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(wallId)) {
        const error = new Error("wallId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (userType !== "PublicBody" && userType !== "Facility") {
        const error = new Error(
            "Only public bodies or facilities can access issue reports for a wall",
        );
        error.statusCode = 403;
        throw error;
    }

    const wall = await Wall.findById(wallId);
    if (!wall) {
        const error = new Error("Wall not found");
        error.statusCode = 404;
        throw error;
    }

    const user = await User.findById(userId);
    if (!user) {
        const error = new Error("User not found");
        error.statusCode = 404;
        throw error;
    }

    const wallIdStr = wallId.toString();
    const userWallsStr = (user.walls || []).map((w) => w.toString());

    // Allow access if the wall is listed in the user's `walls` array
    // or if the wall document itself references the facility/public body
    // as its owner (e.g., `wall.facility` for IndoorWall).
    const wallFacilityId = wall.facility ? wall.facility.toString() : null;
    if (!userWallsStr.includes(wallIdStr) && wallFacilityId !== userId) {
        const error = new Error(
            "You can only access reports for walls you own",
        );
        error.statusCode = 403;
        throw error;
    }

    const reports = await IssueReport.find({ wall_id: wallId });
    return reports;
};

exports.getIssueReportsByClimber = async (userId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const reports = await IssueReport.find({ climber_id: userId });
    return reports;
};

exports.deleteIssueReport = async (reportId, userId) => {
    if (!isValidObjectId(reportId)) {
        const error = new Error("reportId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const report = await IssueReport.findById(reportId);
    if (!report) {
        const error = new Error("IssueReport not found");
        error.statusCode = 404;
        throw error;
    }

    if (report.climber_id.toString() !== userId) {
        const error = new Error("You can only delete your own reports");
        error.statusCode = 403;
        throw error;
    }

    await IssueReport.findByIdAndDelete(reportId);
};
