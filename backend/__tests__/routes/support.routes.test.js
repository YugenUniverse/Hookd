const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const supportRoutes = require("../../routes/support.routes");
const adminRoutes = require("../../routes/admin.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { SupportTicket } = require("../../models/SupportTicket");
const { User } = require("../../models/User");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

jest.mock("../../services/email.service", () => ({
    sendSupportReplyEmail: jest.fn().mockResolvedValue(undefined),
}));
jest.mock("../../services/push.service", () => ({
    sendToTokens: jest.fn().mockResolvedValue(undefined),
}));

const app = express();
app.use(express.json());
app.use("/support", supportRoutes);
app.use("/admin", adminRoutes);
app.use(errorMiddleware);

const createAuthToken = (user) =>
    jwt.sign(
        { sub: user._id.toString(), email: user.email, userType: user.userType },
        process.env.JWT_SECRET,
        { expiresIn: "1h", issuer: "hookd" },
    );

const createClimber = (overrides = {}) =>
    User.create({
        email: "climber@example.com",
        username: "climber",
        userType: "Climber",
        name: "Test",
        surname: "Climber",
        birthdate: new Date("1990-01-01"),
        authMethods: ["local"],
        ...overrides,
    });

const createAdmin = (overrides = {}) =>
    User.create({
        email: "admin@example.com",
        username: "admin",
        userType: "Admin",
        authMethods: ["local"],
        ...overrides,
    });

jest.setTimeout(30000);

describe("support.routes", () => {
    beforeAll(async () => {
        jest.spyOn(console, "error").mockImplementation(() => {});
        await mongoose.connect(process.env.MONGO_URI, { dbName: "hookd" });
    });

    afterEach(async () => {
        await SupportTicket.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        console.error.mockRestore();
        await mongoose.disconnect();
    });

    // ─── POST /support ───────────────────────────────────────────────────────

    describe("POST /support - Create Ticket", () => {
        it("creates ticket with valid data", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "Cannot login", body: "I cannot access my account", category: "ACCOUNT" });

            expect(res.status).toBe(201);
            expect(res.body.ticket).toMatchObject({
                id: expect.any(String),
                subject: "Cannot login",
                body: "I cannot access my account",
                category: "ACCOUNT",
                status: "OPEN",
            });

            const stored = await SupportTicket.findById(res.body.ticket.id);
            expect(stored).not.toBeNull();
            expect(stored.user_id.toString()).toBe(user._id.toString());
        });

        it("defaults category to OTHER when not provided", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "Some issue", body: "Details here" });

            expect(res.status).toBe(201);
            expect(res.body.ticket.category).toBe("OTHER");
        });

        it("returns 400 when subject is missing", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ body: "Details here" });

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("subject and body are required");
        });

        it("returns 400 when body is missing", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "Some issue" });

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("subject and body are required");
        });

        it("returns 400 when subject is empty string", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "   ", body: "Details here" });

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("subject cannot be empty");
        });

        it("returns 400 when subject exceeds 200 characters", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "a".repeat(201), body: "Details here" });

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("subject cannot exceed 200 characters");
        });

        it("returns 400 when body exceeds 2000 characters", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "Issue", body: "a".repeat(2001) });

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("body cannot exceed 2000 characters");
        });

        it("returns 400 when category is invalid", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .post("/support")
                .set("Authorization", `Bearer ${token}`)
                .send({ subject: "Issue", body: "Details", category: "INVALID" });

            expect(res.status).toBe(400);
            expect(res.body.error).toContain("Invalid category");
        });

        it("returns 401 when unauthenticated", async () => {
            const res = await request(app)
                .post("/support")
                .send({ subject: "Issue", body: "Details" });

            expect(res.status).toBe(401);
        });
    });

    // ─── GET /support/mine ───────────────────────────────────────────────────

    describe("GET /support/mine - Get My Tickets", () => {
        it("returns user's own tickets", async () => {
            const user = await createClimber();
            const other = await createClimber({ email: "other@example.com", username: "other" });
            const token = createAuthToken(user);

            await SupportTicket.create({ user_id: user._id, subject: "My ticket", body: "Details" });
            await SupportTicket.create({ user_id: other._id, subject: "Other ticket", body: "Details" });

            const res = await request(app)
                .get("/support/mine")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.tickets).toHaveLength(1);
            expect(res.body.tickets[0].subject).toBe("My ticket");
        });

        it("returns empty array when no tickets", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .get("/support/mine")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.tickets).toEqual([]);
        });

        it("returns 401 when unauthenticated", async () => {
            const res = await request(app).get("/support/mine");
            expect(res.status).toBe(401);
        });
    });

    // ─── GET /support/:ticketId ───────────────────────────────────────────────

    describe("GET /support/:ticketId - Get Ticket", () => {
        it("returns own ticket", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "My ticket",
                body: "Details",
            });

            const res = await request(app)
                .get(`/support/${ticket._id}`)
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.ticket.id).toBe(ticket._id.toString());
            expect(res.body.ticket.subject).toBe("My ticket");
        });

        it("returns 403 when accessing another user's ticket", async () => {
            const user = await createClimber();
            const other = await createClimber({ email: "other@example.com", username: "other" });
            const token = createAuthToken(user);
            const ticket = await SupportTicket.create({
                user_id: other._id,
                subject: "Other's ticket",
                body: "Details",
            });

            const res = await request(app)
                .get(`/support/${ticket._id}`)
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(403);
        });

        it("returns 404 when ticket does not exist", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);
            const nonExistent = new mongoose.Types.ObjectId();

            const res = await request(app)
                .get(`/support/${nonExistent}`)
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(404);
            expect(res.body.error).toBe("Ticket not found");
        });

        it("returns 400 when ticketId is not a valid ObjectId", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .get("/support/invalid-id")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(400);
        });

        it("returns 401 when unauthenticated", async () => {
            const id = new mongoose.Types.ObjectId();
            const res = await request(app).get(`/support/${id}`);
            expect(res.status).toBe(401);
        });
    });

    // ─── GET /admin/support/tickets ─────────────────────────────────────────

    describe("GET /admin/support/tickets - List All Tickets", () => {
        it("returns all tickets for admin", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);

            await SupportTicket.create({ user_id: user._id, subject: "Ticket 1", body: "Body 1" });
            await SupportTicket.create({ user_id: user._id, subject: "Ticket 2", body: "Body 2", status: "RESOLVED" });

            const res = await request(app)
                .get("/admin/support/tickets")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.tickets).toHaveLength(2);
        });

        it("filters by status", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);

            await SupportTicket.create({ user_id: user._id, subject: "Open ticket", body: "Body", status: "OPEN" });
            await SupportTicket.create({ user_id: user._id, subject: "Resolved ticket", body: "Body", status: "RESOLVED" });

            const res = await request(app)
                .get("/admin/support/tickets?status=OPEN")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.tickets).toHaveLength(1);
            expect(res.body.tickets[0].status).toBe("OPEN");
        });

        it("filters by category", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);

            await SupportTicket.create({ user_id: user._id, subject: "Bug ticket", body: "Body", category: "BUG" });
            await SupportTicket.create({ user_id: user._id, subject: "Account ticket", body: "Body", category: "ACCOUNT" });

            const res = await request(app)
                .get("/admin/support/tickets?category=BUG")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.tickets).toHaveLength(1);
            expect(res.body.tickets[0].category).toBe("BUG");
        });

        it("returns 403 when non-admin accesses", async () => {
            const user = await createClimber();
            const token = createAuthToken(user);

            const res = await request(app)
                .get("/admin/support/tickets")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(403);
        });

        it("returns 401 when unauthenticated", async () => {
            const res = await request(app).get("/admin/support/tickets");
            expect(res.status).toBe(401);
        });
    });

    // ─── GET /admin/support/tickets/:ticketId ────────────────────────────────

    describe("GET /admin/support/tickets/:ticketId - Get Ticket (Admin)", () => {
        it("returns any ticket for admin", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Some ticket",
                body: "Details",
            });

            const res = await request(app)
                .get(`/admin/support/tickets/${ticket._id}`)
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(200);
            expect(res.body.ticket.id).toBe(ticket._id.toString());
        });

        it("returns 404 when ticket does not exist", async () => {
            const admin = await createAdmin();
            const token = createAuthToken(admin);
            const nonExistent = new mongoose.Types.ObjectId();

            const res = await request(app)
                .get(`/admin/support/tickets/${nonExistent}`)
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(404);
            expect(res.body.error).toBe("Ticket not found");
        });

        it("returns 400 for invalid ticketId", async () => {
            const admin = await createAdmin();
            const token = createAuthToken(admin);

            const res = await request(app)
                .get("/admin/support/tickets/invalid-id")
                .set("Authorization", `Bearer ${token}`);

            expect(res.status).toBe(400);
        });
    });

    // ─── PATCH /admin/support/tickets/:ticketId/reply ────────────────────────

    describe("PATCH /admin/support/tickets/:ticketId/reply - Reply to Ticket", () => {
        it("sets reply and changes status to IN_PROGRESS by default", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help needed",
                body: "I need help",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({ reply: "We are looking into this." });

            expect(res.status).toBe(200);
            expect(res.body.ticket).toMatchObject({
                admin_reply: "We are looking into this.",
                status: "IN_PROGRESS",
            });
            expect(res.body.ticket.replied_at).toBeDefined();

            const stored = await SupportTicket.findById(ticket._id);
            expect(stored.admin_reply).toBe("We are looking into this.");
            expect(stored.replied_by.toString()).toBe(admin._id.toString());
        });

        it("sets reply and custom status", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help needed",
                body: "I need help",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({ reply: "Issue resolved.", status: "RESOLVED" });

            expect(res.status).toBe(200);
            expect(res.body.ticket.status).toBe("RESOLVED");
        });

        it("returns 400 when reply is missing", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({});

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("reply is required");
        });

        it("returns 400 when status is invalid", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({ reply: "Some reply", status: "INVALID" });

            expect(res.status).toBe(400);
            expect(res.body.error).toContain("Invalid status");
        });

        it("returns 404 when ticket does not exist", async () => {
            const admin = await createAdmin();
            const token = createAuthToken(admin);
            const nonExistent = new mongoose.Types.ObjectId();

            const res = await request(app)
                .patch(`/admin/support/tickets/${nonExistent}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({ reply: "Some reply" });

            expect(res.status).toBe(404);
        });

        it("returns 403 when non-admin tries to reply", async () => {
            const user = await createClimber();
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });
            const token = createAuthToken(user);

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/reply`)
                .set("Authorization", `Bearer ${token}`)
                .send({ reply: "Some reply" });

            expect(res.status).toBe(403);
        });
    });

    // ─── PATCH /admin/support/tickets/:ticketId/status ───────────────────────

    describe("PATCH /admin/support/tickets/:ticketId/status - Update Status", () => {
        it("updates ticket status", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/status`)
                .set("Authorization", `Bearer ${token}`)
                .send({ status: "CLOSED" });

            expect(res.status).toBe(200);
            expect(res.body.ticket.status).toBe("CLOSED");

            const stored = await SupportTicket.findById(ticket._id);
            expect(stored.status).toBe("CLOSED");
        });

        it("returns 400 when status is missing", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/status`)
                .set("Authorization", `Bearer ${token}`)
                .send({});

            expect(res.status).toBe(400);
            expect(res.body.error).toBe("status is required");
        });

        it("returns 400 when status is invalid", async () => {
            const admin = await createAdmin();
            const user = await createClimber();
            const token = createAuthToken(admin);
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/status`)
                .set("Authorization", `Bearer ${token}`)
                .send({ status: "INVALID" });

            expect(res.status).toBe(400);
            expect(res.body.error).toContain("Invalid status");
        });

        it("returns 404 when ticket does not exist", async () => {
            const admin = await createAdmin();
            const token = createAuthToken(admin);
            const nonExistent = new mongoose.Types.ObjectId();

            const res = await request(app)
                .patch(`/admin/support/tickets/${nonExistent}/status`)
                .set("Authorization", `Bearer ${token}`)
                .send({ status: "CLOSED" });

            expect(res.status).toBe(404);
        });

        it("returns 403 when non-admin tries to update status", async () => {
            const user = await createClimber();
            const ticket = await SupportTicket.create({
                user_id: user._id,
                subject: "Help",
                body: "Body",
            });
            const token = createAuthToken(user);

            const res = await request(app)
                .patch(`/admin/support/tickets/${ticket._id}/status`)
                .set("Authorization", `Bearer ${token}`)
                .send({ status: "CLOSED" });

            expect(res.status).toBe(403);
        });
    });
});
