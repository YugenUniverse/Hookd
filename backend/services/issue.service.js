const mongoose = require("mongoose");
const { Issue } = require("../models/Issue");
const { Wall, IndoorWall, OutdoorWall } = require("../models/Wall");
const { User } = require("../models/User");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

exports.createIssue = async (userId, userType, { wall_id, body }) => {
    if (userType !== "Climber") {
        const error = new Error("Only climbers can create issues");
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

    const issue = await Issue.create({
        climber_id: userId,
        wall_id,
        body,
    });

    await Wall.findByIdAndUpdate(wall_id, {
        $push: { issues: issue._id },
    });

    return issue;
};

exports.getIssuesForWall = async (userId, userType, wallId) => {
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
            "Only public bodies or facilities can access issues for a wall",
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

    const wallFacilityId = wall.facility ? wall.facility.toString() : null;
    if (!userWallsStr.includes(wallIdStr) && wallFacilityId !== userId) {
        const error = new Error("You can only access issues for walls you own");
        error.statusCode = 403;
        throw error;
    }

    const issues = await Issue.find({ wall_id: wallId });
    return issues;
};

exports.getIssuesByClimber = async (userId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const issues = await Issue.find({ climber_id: userId });
    return issues;
};

const getOwnedWallIds = async (userId, ownerField) => {
    const ownedWallModel = ownerField === "facility" ? IndoorWall : OutdoorWall;
    const wallsByField = await ownedWallModel.find({ [ownerField]: userId }).distinct(
        "_id",
    );
    const user = await User.findById(userId).select("walls");
    const explicitWallIds = (user?.walls || []).map((id) => id.toString());
    const ownerWallIds = wallsByField.map((id) => id.toString());

    const uniqueIds = Array.from(
        new Set([...ownerWallIds, ...explicitWallIds]),
    );
    return uniqueIds.map((id) => new mongoose.Types.ObjectId(id));
};

exports.getIssuesByFacility = async (userId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const ownedWallIds = await getOwnedWallIds(userId, "facility");
    if (ownedWallIds.length === 0) {
        return [];
    }

    return await Issue.find({ wall_id: { $in: ownedWallIds } });
};

exports.getIssuesByPublicBody = async (userId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const ownedWallIds = await getOwnedWallIds(userId, "publicBody");
    if (ownedWallIds.length === 0) {
        return [];
    }

    return await Issue.find({ wall_id: { $in: ownedWallIds } });
};

exports.updateIssueStatus = async (issueId, newStatus, userId, userType) => {
    if (!isValidObjectId(issueId)) {
        const error = new Error("issueId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (userType !== "PublicBody" && userType !== "Facility") {
        const error = new Error(
            "Only public bodies or facilities can update issue status",
        );
        error.statusCode = 403;
        throw error;
    }

    const issue = await Issue.findById(issueId);
    if (!issue) {
        const error = new Error("Issue not found");
        error.statusCode = 404;
        throw error;
    }

    const ownerField = userType === "Facility" ? "facility" : "publicBody";
    const ownedWallIds = await getOwnedWallIds(userId, ownerField);
    const issueWallId = issue.wall_id.toString();

    if (!ownedWallIds.some((id) => id.toString() === issueWallId)) {
        const error = new Error("You can only update issues for walls you own");
        error.statusCode = 403;
        throw error;
    }

    return await issue.updateStatus(newStatus);
};

exports.deleteIssue = async (issueId, userId) => {
    if (!isValidObjectId(issueId)) {
        const error = new Error("issueId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const issue = await Issue.findById(issueId);
    if (!issue) {
        const error = new Error("Issue not found");
        error.statusCode = 404;
        throw error;
    }

    if (issue.climber_id.toString() !== userId) {
        const error = new Error("You can only delete your own issues");
        error.statusCode = 403;
        throw error;
    }

    await Issue.findByIdAndDelete(issueId);
};
