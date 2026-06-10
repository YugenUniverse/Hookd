const express = require("express");
const router = express.Router();
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");
const groupService = require("../services/group.service");
const eventService = require("../services/event.service");

router.use(authenticateJwt);
router.use(restrictTo("Climber"));

// Create a group
router.post("/", async (req, res, next) => {
    try {
        const group = await groupService.createGroup(req.user.id, req.body);
        res.status(201).json({ group });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Discover public groups (excludes groups the requester already belongs to)
router.get("/discover", async (req, res, next) => {
    try {
        const groups = await groupService.discoverGroups(req.user.id, { search: req.query.search });
        res.json({ groups });
    } catch (err) {
        next(err);
    }
});

// List groups the current user belongs to
router.get("/mine", async (req, res, next) => {
    try {
        const groups = await groupService.getGroupsForUser(req.user.id);
        res.json({ groups });
    } catch (err) {
        next(err);
    }
});

// List pending invitations for the current user
router.get("/invites/pending", async (req, res, next) => {
    try {
        const invitations = await groupService.getPendingInvitesForUser(req.user.id);
        res.json({ invitations });
    } catch (err) {
        next(err);
    }
});

// Accept an invitation
router.patch("/invites/:inviteId/accept", async (req, res, next) => {
    try {
        const group = await groupService.acceptInvite(req.params.inviteId, req.user.id);
        res.json({ group });
    } catch (err) {
        next(err);
    }
});

// Decline an invitation
router.patch("/invites/:inviteId/decline", async (req, res, next) => {
    try {
        const invitation = await groupService.declineInvite(req.params.inviteId, req.user.id);
        res.json({ invitation });
    } catch (err) {
        next(err);
    }
});

// Get group details (members only)
router.get("/:id", async (req, res, next) => {
    try {
        const group = await groupService.getGroupById(req.params.id, req.user.id);
        res.json({ group });
    } catch (err) {
        next(err);
    }
});

// Update group name/description (admin only)
router.patch("/:id", async (req, res, next) => {
    try {
        const group = await groupService.updateGroup(req.params.id, req.user.id, req.body);
        res.json({ group });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Delete group (admin only)
router.delete("/:id", async (req, res, next) => {
    try {
        await groupService.deleteGroup(req.params.id, req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

// Join a public group directly
router.post("/:id/join", async (req, res, next) => {
    try {
        const group = await groupService.joinPublicGroup(req.params.id, req.user.id);
        res.json({ group });
    } catch (err) {
        next(err);
    }
});

// Invite a user to the group (admin only)
router.post("/:id/invites", async (req, res, next) => {
    try {
        const { username } = req.body;
        if (!username) {
            return res.status(400).json({ error: "username is required" });
        }
        const invitation = await groupService.inviteUser(
            req.params.id,
            req.user.id,
            username,
        );
        res.status(201).json({ invitation });
    } catch (err) {
        next(err);
    }
});

// Remove a member or leave the group
router.delete("/:id/members/:userId", async (req, res, next) => {
    try {
        await groupService.removeMember(req.params.id, req.user.id, req.params.userId);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

// Update member role (admin only)
router.patch("/:id/members/:userId/role", async (req, res, next) => {
    try {
        const group = await groupService.updateMemberRole(req.params.id, req.user.id, req.params.userId, req.body.role);
        res.json({ group });
    } catch (err) {
        next(err);
    }
});

// List events for the group (members only)
router.get("/:id/events", async (req, res, next) => {
    try {
        const group = await groupService.getGroupById(req.params.id, req.user.id); // Validates membership
        const events = await eventService.getEventsForGroup(req.params.id);
        res.json({ events });
    } catch (err) {
        next(err);
    }
});

// Create an event for the group (admin/manager only)
router.post("/:id/events", async (req, res, next) => {
    try {
        const payload = { ...req.body, groupId: req.params.id };
        const event = await eventService.createEvent(req.user.id, payload);
        res.status(201).json({ event });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// List planned climbs for the group (members only)
router.get("/:id/climbs", async (req, res, next) => {
    try {
        const climbs = await groupService.getPlannedClimbs(req.params.id, req.user.id);
        res.json({ climbs });
    } catch (err) {
        next(err);
    }
});

// Create a planned climb (admin only)
router.post("/:id/climbs", async (req, res, next) => {
    try {
        const climb = await groupService.createPlannedClimb(req.params.id, req.user.id, req.body);
        res.status(201).json({ climb });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Delete a planned climb (admin only)
router.delete("/:id/climbs/:climbId", async (req, res, next) => {
    try {
        await groupService.deletePlannedClimb(req.params.id, req.user.id, req.params.climbId);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
});

// RSVP to a planned climb (any member)
router.patch("/:id/climbs/:climbId/rsvp", async (req, res, next) => {
    try {
        const { status } = req.body;
        if (!["going", "not_going"].includes(status)) {
            return res.status(400).json({ error: "status must be 'going' or 'not_going'" });
        }
        const climb = await groupService.rsvpPlannedClimb(
            req.params.id,
            req.params.climbId,
            req.user.id,
            status,
        );
        res.json({ climb });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
