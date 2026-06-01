const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");

const adminRoutes = require("../../routes/admin.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User } = require("../../models/User");
const Facility = require("../../models/Facility");
const notificationService = require("../../services/notification.service");
const emailService = require("../../services/email.service");

jest.mock("../../services/notification.service");
jest.mock("../../services/email.service");

process.env.JWT_SECRET = process.env.JWT_SECRET || "test-jwt-secret";

const app = express();
app.use(express.json());
app.use("/admin", adminRoutes);
app.use(errorMiddleware);

const createAuthToken = (user) => {
    return jwt.sign(
        {
            sub: user._id.toString(),
            email: user.email,
            userType: user.userType,
        },
        process.env.JWT_SECRET,
        {
            expiresIn: "1h",
            issuer: "hookd",
        },
    );
};

describe("admin.routes", () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

    const adminToken = createAuthToken({
        _id: { toString: () => "admin-1" },
        email: "admin@example.com",
        userType: "Admin",
    });

    const climberToken = createAuthToken({
        _id: { toString: () => "climber-1" },
        email: "climber@example.com",
        userType: "Climber",
    });

    describe("GET /admin/approvals/pending", () => {
        it("requires authentication", async () => {
            const response = await request(app).get("/admin/approvals/pending");
            expect(response.status).toBe(401);
        });

        it("forbids non-Admin users", async () => {
            const response = await request(app)
                .get("/admin/approvals/pending")
                .set("Authorization", `Bearer ${climberToken}`);
            expect(response.status).toBe(403);
        });

        it("returns pending approvals for Admin", async () => {
            const pendingUsers = [
                { _id: "user-1", email: "test@example.com", userType: "FacilityOwner", approvalStatus: "pending" }
            ];
            
            const populateMock = jest.fn().mockResolvedValue(pendingUsers);
            jest.spyOn(User, "find").mockReturnValue({ populate: populateMock });

            const response = await request(app)
                .get("/admin/approvals/pending")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual(pendingUsers);
            expect(User.find).toHaveBeenCalledWith({
                userType: { $in: ["FacilityOwner", "PublicBody"] },
                approvalStatus: "pending",
            });
            expect(populateMock).toHaveBeenCalledWith("facility");
        });
    });

    describe("PUT /admin/approvals/:userId/approve", () => {
        it("approves the user account", async () => {
            const mockUser = {
                _id: "user-1",
                userType: "FacilityOwner",
                approvalStatus: "pending",
                facility: "facility-1",
                save: jest.fn().mockResolvedValue(true)
            };
            const mockFacility = {
                _id: "facility-1",
                ownerAccount: null,
                save: jest.fn().mockResolvedValue(true)
            };

            jest.spyOn(User, "findById").mockResolvedValue(mockUser);
            jest.spyOn(Facility, "findById").mockResolvedValue(mockFacility);

            const response = await request(app)
                .put("/admin/approvals/user-1/approve")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(mockUser.approvalStatus).toBe("approved");
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockFacility.ownerAccount).toBe("user-1");
            expect(mockFacility.save).toHaveBeenCalled();
            expect(notificationService.createBulk).toHaveBeenCalledWith(["user-1"], "account_approved", {
                message: "Your account request has been approved.",
            });
            expect(emailService.sendAccountApprovedEmail).toHaveBeenCalledWith(mockUser);
        });
        
        it("returns 400 if already approved", async () => {
            const mockUser = {
                _id: "user-1",
                userType: "FacilityOwner",
                approvalStatus: "approved"
            };

            jest.spyOn(User, "findById").mockResolvedValue(mockUser);

            const response = await request(app)
                .put("/admin/approvals/user-1/approve")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(400);
            expect(response.body.error).toBe("Account is already approved");
        });
    });

    describe("PUT /admin/approvals/:userId/reject", () => {
        it("rejects the user account", async () => {
            const mockUser = {
                _id: "user-1",
                userType: "FacilityOwner",
                approvalStatus: "pending",
                save: jest.fn().mockResolvedValue(true)
            };

            jest.spyOn(User, "findById").mockResolvedValue(mockUser);

            const response = await request(app)
                .put("/admin/approvals/user-1/reject")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(mockUser.approvalStatus).toBe("rejected");
            expect(mockUser.save).toHaveBeenCalled();
            expect(notificationService.createBulk).toHaveBeenCalledWith(["user-1"], "account_rejected", {
                message: "Your account request has been rejected.",
            });
            expect(emailService.sendAccountRejectedEmail).toHaveBeenCalledWith(mockUser);
        });
    });
});
