const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

jest.setTimeout(30000);

const groupRoutes = require("../../routes/group.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User, PublicBody } = require("../../models/User");
const Group = require("../../models/Group");
const GroupInvitation = require("../../models/GroupInvitation");
const PlannedClimb = require("../../models/PlannedClimb");
const Notification = require("../../models/Notification");
const Facility = require("../../models/Facility");
const { OutdoorWall } = require("../../models/Wall");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/groups", groupRoutes);
app.use(errorMiddleware);

const makeToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

const climberData = (overrides = {}) => ({
    email: `climber-${Date.now()}-${Math.random()}@test.com`,
    username: `climber_${Date.now()}`,
    userType: "Climber",
    name: "Test",
    surname: "Climber",
    birthdate: new Date("1995-01-01"),
    authMethods: ["local"],
    ...overrides,
});

describe("group.routes", () => {
    let climber1, climber2, climber3, token1, token2, token3;

    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    beforeEach(async () => {
        climber1 = await User.create(climberData({ email: "c1@test.com", username: "c1" }));
        climber2 = await User.create(climberData({ email: "c2@test.com", username: "c2" }));
        climber3 = await User.create(climberData({ email: "c3@test.com", username: "c3" }));
        token1 = makeToken(climber1);
        token2 = makeToken(climber2);
        token3 = makeToken(climber3);
    });

    afterEach(async () => {
        await Notification.deleteMany({});
        await GroupInvitation.deleteMany({});
        await PlannedClimb.deleteMany({});
        await Group.deleteMany({});
        await User.deleteMany({});
        await Facility.deleteMany({});
        await OutdoorWall.deleteMany({});
        await PublicBody.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    // ─── Create ──────────────────────────────────────────────────────────────

    describe("POST /groups", () => {
        it("creates a group and makes the creator an admin member", async () => {
            const res = await request(app)
                .post("/groups")
                .set("Authorization", `Bearer ${token1}`)
                .send({ name: "Weekend Crew", description: "Let's climb!" });

            expect(res.status).toBe(201);
            expect(res.body.group.name).toBe("Weekend Crew");
            expect(res.body.group.members).toHaveLength(1);
            expect(res.body.group.members[0].role).toBe("admin");
        });

        it("returns 400 when name is missing", async () => {
            const res = await request(app)
                .post("/groups")
                .set("Authorization", `Bearer ${token1}`)
                .send({ description: "No name" });

            expect(res.status).toBe(400);
        });

        it("returns 403 for non-Climber users", async () => {
            const owner = await User.create({
                email: "owner@test.com",
                username: "facilityowner",
                userType: "FacilityOwner",
                name: "Owner",
                surname: "User",
                birthdate: new Date("1980-01-01"),
                authMethods: ["local"],
            });
            const ownerToken = makeToken(owner);

            const res = await request(app)
                .post("/groups")
                .set("Authorization", `Bearer ${ownerToken}`)
                .send({ name: "My Group" });

            expect(res.status).toBe(403);
        });
    });

    // ─── Mine ────────────────────────────────────────────────────────────────

    describe("GET /groups/mine", () => {
        it("returns only groups the user belongs to", async () => {
            await Group.create({
                name: "My Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            await Group.create({
                name: "Other Group",
                creator: climber2._id,
                members: [{ user: climber2._id, role: "admin" }],
            });

            const res = await request(app)
                .get("/groups/mine")
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(200);
            expect(res.body.groups).toHaveLength(1);
            expect(res.body.groups[0].name).toBe("My Group");
        });
    });

    // ─── Detail ───────────────────────────────────────────────────────────────

    describe("GET /groups/:id", () => {
        it("returns group details to a member", async () => {
            const group = await Group.create({
                name: "Detail Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .get(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(200);
            expect(res.body.group.name).toBe("Detail Group");
        });

        it("returns 403 to non-members", async () => {
            const group = await Group.create({
                name: "Private Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .get(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(403);
        });

        it("returns 404 for unknown group", async () => {
            const res = await request(app)
                .get(`/groups/${new mongoose.Types.ObjectId()}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(404);
        });
    });

    // ─── Update ───────────────────────────────────────────────────────────────

    describe("PATCH /groups/:id", () => {
        it("allows admin to update name and description", async () => {
            const group = await Group.create({
                name: "Old Name",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .patch(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ name: "New Name" });

            expect(res.status).toBe(200);
            expect(res.body.group.name).toBe("New Name");
        });

        it("returns 403 when non-admin tries to update", async () => {
            const group = await Group.create({
                name: "Admin Only",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .patch(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token2}`)
                .send({ name: "Hacked Name" });

            expect(res.status).toBe(403);
        });
    });

    // ─── Delete ───────────────────────────────────────────────────────────────

    describe("DELETE /groups/:id", () => {
        it("admin can delete the group and its invitations", async () => {
            const group = await Group.create({
                name: "To Delete",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            await GroupInvitation.create({
                group: group._id,
                invitee: climber2._id,
                invitedBy: climber1._id,
            });

            const res = await request(app)
                .delete(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(204);
            expect(await Group.findById(group._id)).toBeNull();
            expect(await GroupInvitation.countDocuments({ group: group._id })).toBe(0);
        });

        it("returns 403 when non-admin tries to delete", async () => {
            const group = await Group.create({
                name: "Protected",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(403);
        });
    });

    // ─── Invite ───────────────────────────────────────────────────────────────

    describe("POST /groups/:id/invites", () => {
        it("admin can invite another climber by username and a notification is sent", async () => {
            const group = await Group.create({
                name: "Inviting Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: climber2.username });

            expect(res.status).toBe(201);
            expect(res.body.invitation.status).toBe("pending");

            const notif = await Notification.findOne({ recipient: climber2._id });
            expect(notif).not.toBeNull();
            expect(notif.type).toBe("group_invite");
            expect(notif.payload.groupName).toBe("Inviting Group");
        });

        it("is case-insensitive for username lookup", async () => {
            const group = await Group.create({
                name: "Case Test Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: climber2.username.toUpperCase() });

            expect(res.status).toBe(201);
        });

        it("returns 400 when username is missing", async () => {
            const group = await Group.create({
                name: "No Username",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({});

            expect(res.status).toBe(400);
        });

        it("returns 404 when username does not exist", async () => {
            const group = await Group.create({
                name: "Ghost Invite",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: "nonexistent_user_xyz" });

            expect(res.status).toBe(404);
        });

        it("returns 409 on duplicate invite", async () => {
            const group = await Group.create({
                name: "Dup Invite",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: climber2.username });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: climber2.username });

            expect(res.status).toBe(409);
        });

        it("returns 409 when user is already a member", async () => {
            const group = await Group.create({
                name: "Already In",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ username: climber2.username });

            expect(res.status).toBe(409);
        });

        it("returns 403 when non-admin tries to invite", async () => {
            const group = await Group.create({
                name: "Non-admin Invite",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/invites`)
                .set("Authorization", `Bearer ${token2}`)
                .send({ username: climber3.username });

            expect(res.status).toBe(403);
        });
    });

    // ─── Pending invites ──────────────────────────────────────────────────────

    describe("GET /groups/invites/pending", () => {
        it("returns only pending invitations for the current user", async () => {
            const group = await Group.create({
                name: "Pending Test",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            await GroupInvitation.create({
                group: group._id,
                invitee: climber2._id,
                invitedBy: climber1._id,
            });

            const res = await request(app)
                .get("/groups/invites/pending")
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(200);
            expect(res.body.invitations).toHaveLength(1);
            expect(res.body.invitations[0].group.name).toBe("Pending Test");
        });
    });

    // ─── Accept / Decline ─────────────────────────────────────────────────────

    describe("PATCH /groups/invites/:inviteId/accept", () => {
        it("adds the user to the group on accept", async () => {
            const group = await Group.create({
                name: "Accept Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const invite = await GroupInvitation.create({
                group: group._id,
                invitee: climber2._id,
                invitedBy: climber1._id,
            });

            const res = await request(app)
                .patch(`/groups/invites/${invite._id}/accept`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(200);
            const updated = await Group.findById(group._id);
            const isMember = updated.members.some(
                (m) => m.user.toString() === climber2._id.toString(),
            );
            expect(isMember).toBe(true);
            const inv = await GroupInvitation.findById(invite._id);
            expect(inv.status).toBe("accepted");
        });

        it("returns 403 when another user tries to accept someone else's invite", async () => {
            const group = await Group.create({
                name: "Wrong User",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const invite = await GroupInvitation.create({
                group: group._id,
                invitee: climber2._id,
                invitedBy: climber1._id,
            });

            const res = await request(app)
                .patch(`/groups/invites/${invite._id}/accept`)
                .set("Authorization", `Bearer ${token3}`);

            expect(res.status).toBe(403);
        });
    });

    describe("PATCH /groups/invites/:inviteId/decline", () => {
        it("sets invitation status to declined", async () => {
            const group = await Group.create({
                name: "Decline Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const invite = await GroupInvitation.create({
                group: group._id,
                invitee: climber2._id,
                invitedBy: climber1._id,
            });

            const res = await request(app)
                .patch(`/groups/invites/${invite._id}/decline`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(200);
            expect(res.body.invitation.status).toBe("declined");
        });
    });

    // ─── Remove / Leave ───────────────────────────────────────────────────────

    describe("DELETE /groups/:id/members/:userId", () => {
        it("admin can remove a member", async () => {
            const group = await Group.create({
                name: "Remove Member",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/members/${climber2._id}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(204);
            const updated = await Group.findById(group._id);
            expect(updated.members).toHaveLength(1);
        });

        it("member can leave the group themselves", async () => {
            const group = await Group.create({
                name: "Self Leave",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/members/${climber2._id}`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(204);
        });

        it("returns 409 when trying to remove the last admin", async () => {
            const group = await Group.create({
                name: "Last Admin",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/members/${climber1._id}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(409);
        });

        it("returns 403 when non-admin tries to remove another member", async () => {
            const group = await Group.create({
                name: "Non-admin Remove",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                    { user: climber3._id, role: "member" },
                ],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/members/${climber3._id}`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(403);
        });
    });

    // ─── Planned Climbs ───────────────────────────────────────────────────────

    describe("POST /groups/:id/climbs", () => {
        it("admin can create a planned climb without a venue", async () => {
            const group = await Group.create({
                name: "Climb Planners",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ date: "2026-07-15T09:00:00Z", notes: "Bring slippers" });

            expect(res.status).toBe(201);
            expect(res.body.climb.notes).toBe("Bring slippers");
            expect(new Date(res.body.climb.date).getFullYear()).toBe(2026);
        });

        it("resolves wallName from a Facility venue", async () => {
            const facility = await Facility.create({
                name: "Rock Palace",
                location: { type: "Point", coordinates: [11.0, 46.0] },
            });
            const group = await Group.create({
                name: "Gym Crew",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ date: "2026-08-10T10:00:00Z", venueId: facility._id.toString(), venueType: "Facility" });

            expect(res.status).toBe(201);
            expect(res.body.climb.wallName).toBe("Rock Palace");
            expect(res.body.climb.facility).toBeDefined();
        });

        it("resolves wallName from an outdoor Wall venue", async () => {
            const pb = await PublicBody.create({
                email: "pb@test.com",
                username: "publicbody",
                name: "City Council",
                location: { type: "Point", coordinates: [10.9, 45.9] },
                authMethods: ["local"],
            });
            const wall = await OutdoorWall.create({
                name: "Arco Slab",
                location: { type: "Point", coordinates: [10.9, 45.9] },
                difficulty: "INTERMEDIATE",
                publicBody: pb._id,
            });
            const group = await Group.create({
                name: "Outdoor Crew",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ date: "2026-09-01T08:00:00Z", venueId: wall._id.toString(), venueType: "Wall" });

            expect(res.status).toBe(201);
            expect(res.body.climb.wallName).toBe("Arco Slab");
            expect(res.body.climb.wall).toBeDefined();
        });

        it("returns 404 when venueId does not exist", async () => {
            const group = await Group.create({
                name: "Ghost Venue",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ date: "2026-09-01T08:00:00Z", venueId: new mongoose.Types.ObjectId().toString(), venueType: "Facility" });

            expect(res.status).toBe(404);
        });

        it("returns 400 when date is missing", async () => {
            const group = await Group.create({
                name: "No Date Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ wallName: "Some Wall" });

            expect(res.status).toBe(400);
        });

        it("returns 400 when date is invalid", async () => {
            const group = await Group.create({
                name: "Bad Date Group",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ date: "not-a-date" });

            expect(res.status).toBe(400);
        });

        it("returns 403 when non-admin tries to create a planned climb", async () => {
            const group = await Group.create({
                name: "Member Only",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });

            const res = await request(app)
                .post(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token2}`)
                .send({ date: "2026-08-01T10:00:00Z" });

            expect(res.status).toBe(403);
        });
    });

    describe("GET /groups/:id/climbs", () => {
        it("member can list planned climbs sorted by date", async () => {
            const group = await Group.create({
                name: "List Climbs",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });
            await PlannedClimb.create({ group: group._id, createdBy: climber1._id, date: new Date("2026-09-10") });
            await PlannedClimb.create({ group: group._id, createdBy: climber1._id, date: new Date("2026-08-01") });

            const res = await request(app)
                .get(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(200);
            expect(res.body.climbs).toHaveLength(2);
            expect(new Date(res.body.climbs[0].date) < new Date(res.body.climbs[1].date)).toBe(true);
        });

        it("returns 403 for non-members", async () => {
            const group = await Group.create({
                name: "Private Climbs",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .get(`/groups/${group._id}/climbs`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(403);
        });
    });

    describe("DELETE /groups/:id/climbs/:climbId", () => {
        it("admin can delete a planned climb", async () => {
            const group = await Group.create({
                name: "Delete Climb",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-10-01"),
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/climbs/${climb._id}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(204);
            expect(await PlannedClimb.findById(climb._id)).toBeNull();
        });

        it("returns 403 when non-admin tries to delete", async () => {
            const group = await Group.create({
                name: "Protected Climb",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-10-01"),
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/climbs/${climb._id}`)
                .set("Authorization", `Bearer ${token2}`);

            expect(res.status).toBe(403);
        });

        it("returns 404 for a climb that does not exist", async () => {
            const group = await Group.create({
                name: "Missing Climb",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .delete(`/groups/${group._id}/climbs/${new mongoose.Types.ObjectId()}`)
                .set("Authorization", `Bearer ${token1}`);

            expect(res.status).toBe(404);
        });
    });

    // ─── RSVP ────────────────────────────────────────────────────────────────

    describe("PATCH /groups/:id/climbs/:climbId/rsvp", () => {
        it("member can set status to going", async () => {
            const group = await Group.create({
                name: "RSVP Group",
                creator: climber1._id,
                members: [
                    { user: climber1._id, role: "admin" },
                    { user: climber2._id, role: "member" },
                ],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-11-01"),
            });

            const res = await request(app)
                .patch(`/groups/${group._id}/climbs/${climb._id}/rsvp`)
                .set("Authorization", `Bearer ${token2}`)
                .send({ status: "going" });

            expect(res.status).toBe(200);
            expect(res.body.climb.attendees).toHaveLength(1);
            expect(res.body.climb.attendees[0].status).toBe("going");
        });

        it("switching status updates the existing attendee entry", async () => {
            const group = await Group.create({
                name: "Switch RSVP",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-11-15"),
                attendees: [{ user: climber1._id, status: "going" }],
            });

            const res = await request(app)
                .patch(`/groups/${group._id}/climbs/${climb._id}/rsvp`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ status: "not_going" });

            expect(res.status).toBe(200);
            expect(res.body.climb.attendees).toHaveLength(1);
            expect(res.body.climb.attendees[0].status).toBe("not_going");
        });

        it("returns 400 for an invalid status", async () => {
            const group = await Group.create({
                name: "Bad Status",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-12-01"),
            });

            const res = await request(app)
                .patch(`/groups/${group._id}/climbs/${climb._id}/rsvp`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ status: "maybe" });

            expect(res.status).toBe(400);
        });

        it("returns 403 for non-members", async () => {
            const group = await Group.create({
                name: "Non-member RSVP",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });
            const climb = await PlannedClimb.create({
                group: group._id,
                createdBy: climber1._id,
                date: new Date("2026-12-15"),
            });

            const res = await request(app)
                .patch(`/groups/${group._id}/climbs/${climb._id}/rsvp`)
                .set("Authorization", `Bearer ${token2}`)
                .send({ status: "going" });

            expect(res.status).toBe(403);
        });

        it("returns 404 for a climb that does not exist", async () => {
            const group = await Group.create({
                name: "No Climb RSVP",
                creator: climber1._id,
                members: [{ user: climber1._id, role: "admin" }],
            });

            const res = await request(app)
                .patch(`/groups/${group._id}/climbs/${new mongoose.Types.ObjectId()}/rsvp`)
                .set("Authorization", `Bearer ${token1}`)
                .send({ status: "going" });

            expect(res.status).toBe(404);
        });
    });
});
