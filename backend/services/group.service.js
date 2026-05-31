const Group = require("../models/Group");
const GroupInvitation = require("../models/GroupInvitation");
const PlannedClimb = require("../models/PlannedClimb");
const { User } = require("../models/User");
const { Wall } = require("../models/Wall");
const Facility = require("../models/Facility");
const notificationService = require("./notification.service");

const err = (msg, code) => Object.assign(new Error(msg), { statusCode: code });

exports.createGroup = async (creatorId, { name, description, visibility }) => {
    const group = await Group.create({
        name,
        description,
        visibility: visibility === "public" ? "public" : "private",
        creator: creatorId,
        members: [{ user: creatorId, role: "admin", joinedAt: new Date() }],
    });
    return group;
};

exports.discoverGroups = async (userId, { search } = {}) => {
    const query = {
        visibility: "public",
        "members.user": { $ne: userId },
    };
    if (search) {
        query.name = { $regex: search.trim(), $options: "i" };
    }
    const groups = await Group.find(query)
        .select("name description visibility members createdAt")
        .sort({ createdAt: -1 })
        .limit(50);
    return groups.map((g) => ({
        id: g.id,
        name: g.name,
        description: g.description,
        visibility: g.visibility,
        memberCount: g.members.length,
        createdAt: g.createdAt,
    }));
};

exports.joinPublicGroup = async (groupId, userId) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    if (group.visibility !== "public") throw err("This group is private", 403);
    const alreadyMember = group.members.some((m) => m.user.toString() === userId.toString());
    if (alreadyMember) throw err("Already a member", 409);
    group.members.push({ user: userId, role: "member", joinedAt: new Date() });
    await group.save();
    return Group.findById(groupId)
        .populate("members.user", "name username")
        .populate("creator", "name username");
};

exports.getGroupsForUser = async (userId) => {
    return Group.find({ "members.user": userId })
        .populate("members.user", "name username")
        .sort({ createdAt: -1 });
};

exports.getGroupById = async (groupId, requesterId) => {
    const group = await Group.findById(groupId)
        .populate("members.user", "name username")
        .populate("creator", "name username");
    if (!group) throw err("Group not found", 404);
    const isMember = group.members.some(
        (m) => m.user._id.toString() === requesterId.toString(),
    );
    if (!isMember) throw err("Forbidden", 403);
    return group;
};

exports.updateGroup = async (groupId, adminId, patch) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdmin(group, adminId);
    const { name, description, visibility } = patch;
    if (name !== undefined) group.name = name;
    if (description !== undefined) group.description = description;
    if (visibility === "public" || visibility === "private") group.visibility = visibility;
    return group.save();
};

exports.deleteGroup = async (groupId, adminId) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdmin(group, adminId);
    await GroupInvitation.deleteMany({ group: groupId });
    await PlannedClimb.deleteMany({ group: groupId });
    await group.deleteOne();
};

exports.getPlannedClimbs = async (groupId, requesterId) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    const isMember = group.members.some((m) => m.user.toString() === requesterId.toString());
    if (!isMember) throw err("Forbidden", 403);
    return PlannedClimb.find({ group: groupId })
        .populate("createdBy", "name username")
        .populate("wall", "name")
        .populate("facility", "name")
        .populate("attendees.user", "name username")
        .sort({ date: 1 });
};

exports.rsvpPlannedClimb = async (groupId, climbId, userId, status) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    const isMember = group.members.some((m) => m.user.toString() === userId.toString());
    if (!isMember) throw err("Forbidden", 403);

    const climb = await PlannedClimb.findOne({ _id: climbId, group: groupId });
    if (!climb) throw err("Planned climb not found", 404);

    const existing = climb.attendees.find((a) => a.user.toString() === userId.toString());
    if (existing) {
        existing.status = status;
    } else {
        climb.attendees.push({ user: userId, status });
    }
    await climb.save();

    return PlannedClimb.findById(climb._id)
        .populate("createdBy", "name username")
        .populate("wall", "name")
        .populate("facility", "name")
        .populate("attendees.user", "name username");
};

exports.createPlannedClimb = async (groupId, adminId, { date, venueId, venueType, notes }) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdminOrManager(group, adminId);
    if (!date) throw err("date is required", 400);
    const parsedDate = new Date(date);
    if (isNaN(parsedDate.getTime())) throw err("Invalid date", 400);

    let wall, facility, wallName;
    if (venueId && venueType) {
        if (venueType === "Wall") {
            const w = await Wall.findById(venueId, "name");
            if (!w) throw err("Wall not found", 404);
            wall = w._id;
            wallName = w.name;
        } else if (venueType === "Facility") {
            const f = await Facility.findById(venueId, "name");
            if (!f) throw err("Facility not found", 404);
            facility = f._id;
            wallName = f.name;
        }
    }

    return PlannedClimb.create({ group: groupId, createdBy: adminId, date: parsedDate, wall, facility, wallName, notes });
};

exports.deletePlannedClimb = async (groupId, adminId, climbId) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdminOrManager(group, adminId);
    const climb = await PlannedClimb.findOne({ _id: climbId, group: groupId });
    if (!climb) throw err("Planned climb not found", 404);
    await climb.deleteOne();
};

exports.inviteUser = async (groupId, adminId, username) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdminOrManager(group, adminId);

    const invitee = await User.findOne({ username: username.toLowerCase().trim() });
    if (!invitee) throw err("User not found", 404);
    const inviteeId = invitee._id;

    if (inviteeId.toString() === adminId.toString()) {
        throw err("Cannot invite yourself", 400);
    }
    const alreadyMember = group.members.some(
        (m) => m.user.toString() === inviteeId.toString(),
    );
    if (alreadyMember) throw err("User is already a member", 409);

    const admin = await User.findById(adminId, "name username");

    let invitation;
    try {
        invitation = await GroupInvitation.create({
            group: groupId,
            invitee: inviteeId,
            invitedBy: adminId,
        });
    } catch (e) {
        if (e.code === 11000) throw err("Invite already sent", 409);
        throw e;
    }

    await notificationService.createBulk([inviteeId], "group_invite", {
        groupId: group._id,
        groupName: group.name,
        invitationId: invitation._id,
        invitedByName: admin?.name ?? admin?.username ?? "Someone",
    });

    return invitation;
};

exports.getPendingInvitesForUser = async (userId) => {
    return GroupInvitation.find({ invitee: userId, status: "pending" })
        .populate("group", "name description")
        .populate("invitedBy", "name username")
        .sort({ createdAt: -1 });
};

exports.acceptInvite = async (inviteId, userId) => {
    const invite = await GroupInvitation.findById(inviteId);
    if (!invite) throw err("Invitation not found", 404);
    if (invite.invitee.toString() !== userId.toString()) throw err("Forbidden", 403);
    if (invite.status !== "pending") throw err("Invitation is no longer pending", 409);

    const group = await Group.findById(invite.group);
    if (!group) throw err("Group not found", 404);

    const alreadyMember = group.members.some(
        (m) => m.user.toString() === userId.toString(),
    );
    if (!alreadyMember) {
        group.members.push({ user: userId, role: "member", joinedAt: new Date() });
        await group.save();
    }

    invite.status = "accepted";
    await invite.save();
    return group;
};

exports.declineInvite = async (inviteId, userId) => {
    const invite = await GroupInvitation.findById(inviteId);
    if (!invite) throw err("Invitation not found", 404);
    if (invite.invitee.toString() !== userId.toString()) throw err("Forbidden", 403);
    if (invite.status !== "pending") throw err("Invitation is no longer pending", 409);

    invite.status = "declined";
    return invite.save();
};

exports.removeMember = async (groupId, requesterId, targetId) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);

    const isSelf = requesterId.toString() === targetId.toString();
    if (!isSelf) _requireAdmin(group, requesterId);

    const memberIndex = group.members.findIndex(
        (m) => m.user.toString() === targetId.toString(),
    );
    if (memberIndex === -1) throw err("User is not a member", 404);

    const isTargetAdmin = group.members[memberIndex].role === "admin";

    if (isSelf && isTargetAdmin) {
        // Admin leaving: require at least one other member; auto-promote if no other admin
        const others = group.members.filter(
            (m) => m.user.toString() !== targetId.toString(),
        );
        if (others.length === 0) {
            throw err("You are the only member. Delete the group instead.", 409);
        }
        const hasOtherAdmin = others.some((m) => m.role === "admin");
        if (!hasOtherAdmin) {
            const earliest = others.reduce((a, b) =>
                new Date(a.joinedAt) <= new Date(b.joinedAt) ? a : b,
            );
            const toPromote = group.members.find(
                (m) => m.user.toString() === earliest.user.toString(),
            );
            toPromote.role = "admin";
        }
    } else if (!isSelf && isTargetAdmin) {
        // Admin forcibly removing another admin: keep last-admin guard
        const adminCount = group.members.filter((m) => m.role === "admin").length;
        if (adminCount === 1) throw err("Cannot remove the last admin", 409);
    }

    group.members.splice(memberIndex, 1);
    await group.save();
};

function _requireAdmin(group, userId) {
    const member = group.members.find(
        (m) => m.user.toString() === userId.toString(),
    );
    if (!member || member.role !== "admin") {
        throw err("Forbidden: admin only", 403);
    }
}

function _requireAdminOrManager(group, userId) {
    const member = group.members.find(
        (m) => m.user.toString() === userId.toString(),
    );
    if (!member || (member.role !== "admin" && member.role !== "manager")) {
        throw err("Forbidden: admin or manager only", 403);
    }
}

exports.updateMemberRole = async (groupId, adminId, targetUserId, newRole) => {
    const group = await Group.findById(groupId);
    if (!group) throw err("Group not found", 404);
    _requireAdmin(group, adminId); // Only admins can change roles

    const memberIndex = group.members.findIndex(
        (m) => m.user.toString() === targetUserId.toString(),
    );
    if (memberIndex === -1) throw err("User is not a member", 404);

    if (!["admin", "manager", "member"].includes(newRole)) {
        throw err("Invalid role", 400);
    }

    // Prevent demoting the last admin
    if (group.members[memberIndex].role === "admin" && newRole !== "admin") {
        const adminCount = group.members.filter((m) => m.role === "admin").length;
        if (adminCount <= 1) {
            throw err("Cannot demote the last admin", 409);
        }
    }

    group.members[memberIndex].role = newRole;
    await group.save();
    return group;
};
