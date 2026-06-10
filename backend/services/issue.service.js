const mongoose = require("mongoose");
const { Issue } = require("../models/Issue");
const { Wall, IndoorWall, OutdoorWall } = require("../models/Wall");
const { User } = require("../models/User");
const notificationService = require("./notification.service");

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const getFacilityOwnerContext = async (userId) => {
    const facility = await mongoose
        .model("Facility")
        .findOne({ ownerAccount: userId })
        .select("_id");

    return {
        facilityId: facility?._id ?? null,
        legacyFacilityId: userId,
    };
};

exports.createIssue = async (userId, userType, { wall_id, body, severity, description, location }) => {
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
        severity: severity || "MEDIUM",
        description: description || "",
        location: location || "",
    });

    // Fetch wall to get owner and check type
    const wall = await Wall.findById(wall_id).select("publicBody facility name");
    if (wall) {
        // Link issue to wall
        await Wall.findByIdAndUpdate(wall_id, {
            $push: { issues: issue._id },
        });

        // Trigger notification for HIGH severity issues on outdoor walls (those with publicBody)
        if (issue.severity === "HIGH" && wall.publicBody) {
            try {
                await notificationService.createBulk([wall.publicBody], "new_issue", {
                    issueId: issue._id.toString(),
                    wallId: wall._id.toString(),
                    wallName: wall.name || "Unknown Wall",
                    severity: issue.severity,
                    body: issue.body,
                    description: issue.description,
                    location: issue.location,
                    climberId: userId.toString(),
                    submittedAt: new Date(issue.submitted_at).toISOString(),
                });
            } catch (notificationError) {
                console.error("Failed to create notification:", notificationError);
                // Don't throw - notification failure shouldn't prevent issue creation
            }
        }
    }

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

    if (userType !== "PublicBody" && userType !== "FacilityOwner") {
        const error = new Error(
            "Only public bodies or facility owners can access issues for a wall",
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

    const { facilityId, legacyFacilityId } = await getFacilityOwnerContext(userId);
    const wallFacilityId = wall.facility ? wall.facility.toString() : null;
    const canAccessWall =
        userWallsStr.includes(wallIdStr) ||
        wallFacilityId === facilityId?.toString() ||
        wallFacilityId === legacyFacilityId;

    if (!canAccessWall) {
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
    const user = await User.findById(userId).select("walls");
    const explicitWallIds = (user?.walls || []).map((id) => id.toString());

    let ownerWallIds = [];
    if (ownerField === "facility") {
        const { facilityId, legacyFacilityId } = await getFacilityOwnerContext(userId);
        const facilityMatchIds = [legacyFacilityId];

        if (facilityId) {
            facilityMatchIds.unshift(facilityId);
        }

        ownerWallIds = await ownedWallModel
            .find({ facility: { $in: facilityMatchIds } })
            .distinct("_id");
    } else {
        ownerWallIds = await ownedWallModel.find({ [ownerField]: userId }).distinct("_id");
    }

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

exports.getIssuesForPublicBodyDashboard = async (userId, filters = {}) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const ownedWallIds = await getOwnedWallIds(userId, "publicBody");
    if (ownedWallIds.length === 0) {
        return [];
    }

    const query = { wall_id: { $in: ownedWallIds } };

    // Apply status filter if provided
    if (filters.status && Array.isArray(filters.status) && filters.status.length > 0) {
        query.status = { $in: filters.status };
    }

    // Apply severity filter if provided
    if (filters.severity && Array.isArray(filters.severity) && filters.severity.length > 0) {
        query.severity = { $in: filters.severity };
    }

    const issues = await Issue.find(query)
        .populate({ path: "climber_id", select: "username" })
        .populate({ path: "wall_id", select: "name location" })
        .sort({ submitted_at: -1 });

    return issues;
};

exports.getIssuesSummaryForPublicBody = async (userId) => {
    if (!isValidObjectId(userId)) {
        const error = new Error("userId must be a valid ObjectId");
        error.statusCode = 400;
        throw error;
    }

    const ownedWallIds = await getOwnedWallIds(userId, "publicBody");
    if (ownedWallIds.length === 0) {
        return {
            totalOpen: 0,
            highSeverity: 0,
            mediumSeverity: 0,
            byStatus: {},
        };
    }

    const issues = await Issue.find({ wall_id: { $in: ownedWallIds } });

    const activeStatuses = ["OPEN", "IN_PROGRESS"];
    const summary = {
        totalOpen: issues.filter((i) => i.status === "OPEN").length,
        highSeverity: issues.filter((i) => i.severity === "HIGH" && activeStatuses.includes(i.status)).length,
        mediumSeverity: issues.filter((i) => i.severity === "MEDIUM" && activeStatuses.includes(i.status)).length,
        byStatus: {
            OPEN: issues.filter((i) => i.status === "OPEN").length,
            IN_PROGRESS: issues.filter((i) => i.status === "IN_PROGRESS").length,
            RESOLVED: issues.filter((i) => i.status === "RESOLVED").length,
            CLOSED: issues.filter((i) => i.status === "CLOSED").length,
        },
    };

    return summary;
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

    if (userType !== "PublicBody" && userType !== "FacilityOwner") {
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

    const ownerField = userType === "FacilityOwner" ? "facility" : "publicBody";
    const ownedWallIds = await getOwnedWallIds(userId, ownerField);
    const issueWallId = issue.wall_id.toString();

    if (!ownedWallIds.some((id) => id.toString() === issueWallId)) {
        const error = new Error("You can only update issues for walls you own");
        error.statusCode = 403;
        throw error;
    }

    const updated = await issue.updateStatus(newStatus);

    // Notify the climber who filed the issue — fire-and-forget
    Wall.findById(issue.wall_id, "name")
        .then((wall) =>
            notificationService.createBulk([issue.climber_id], "issue_status_changed", {
                issueId: issueId.toString(),
                wallId: issue.wall_id.toString(),
                wallName: wall?.name || "a wall",
                newStatus,
            })
        )
        .catch((err) => console.error("issue.service: issue_status_changed notification error:", err.message));

    return updated;
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
