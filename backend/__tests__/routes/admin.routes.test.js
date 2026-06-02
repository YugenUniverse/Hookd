const express = require("express");
const request = require("supertest");
const jwt = require("jsonwebtoken");

const adminRoutes = require("../../routes/admin.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const { User } = require("../../models/User");
const Facility = require("../../models/Facility");
const Review = require("../../models/Review");
const notificationService = require("../../services/notification.service");
const emailService = require("../../services/email.service");
const ClimbingSession = require("../../models/ClimbingSession");
const { Wall } = require("../../models/Wall");
const Group = require("../../models/Group");
const Event = require("../../models/Event");
const { Report } = require("../../models/Report");


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

    describe("GET /admin/moderation/flagged", () => {
        it("returns flagged reviews for Admin", async () => {
            const mockReviews = [
                {
                    id: "review-1",
                    body: "Bad language",
                    rating: 1,
                    flagged: true,
                    status: "active",
                    flagReason: "Offensive language",
                },
            ];

            const sortMock = jest.fn().mockResolvedValue(mockReviews);
            const populateMock = jest.fn().mockReturnValue({ sort: sortMock });
            jest.spyOn(Review, "find").mockReturnValue({ populate: populateMock });

            const response = await request(app)
                .get("/admin/moderation/flagged")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(response.body).toEqual(mockReviews);
            expect(Review.find).toHaveBeenCalledWith({ flagged: true, status: "active" });
        });

        it("forbids non-Admin users", async () => {
            const response = await request(app)
                .get("/admin/moderation/flagged")
                .set("Authorization", `Bearer ${climberToken}`);
            expect(response.status).toBe(403);
        });
    });

    describe("DELETE /admin/moderation/reviews/:reviewId", () => {
        it("removes review and notifies author", async () => {
            const mockAuthor = { _id: "climber-1", username: "climber", email: "climber@example.com" };
            const mockReview = {
                _id: "review-1",
                status: "active",
                flagged: true,
                flagReason: "Spam",
                climbing_session_id: { climber_id: mockAuthor },
                save: jest.fn().mockResolvedValue(true),
            };

            const populateMock = jest.fn().mockResolvedValue(mockReview);
            jest.spyOn(Review, "findById").mockReturnValue({ populate: populateMock });

            const response = await request(app)
                .delete("/admin/moderation/reviews/review-1")
                .set("Authorization", `Bearer ${adminToken}`)
                .send({ reason: "Spam content" });

            expect(response.status).toBe(200);
            expect(mockReview.status).toBe("removed");
            expect(mockReview.save).toHaveBeenCalled();
            expect(notificationService.createBulk).toHaveBeenCalledWith(
                [mockAuthor._id],
                "content_removed",
                { reason: "Spam content", contentType: "review" }
            );
            expect(emailService.sendContentRemovedEmail).toHaveBeenCalledWith(mockAuthor, "Spam content");
        });

        it("returns 404 for already removed review", async () => {
            const mockReview = { _id: "review-1", status: "removed" };
            const populateMock = jest.fn().mockResolvedValue(mockReview);
            jest.spyOn(Review, "findById").mockReturnValue({ populate: populateMock });

            const response = await request(app)
                .delete("/admin/moderation/reviews/review-1")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(404);
        });
    });

    describe("POST /admin/moderation/reviews/:reviewId/dismiss", () => {
        it("clears flag on review", async () => {
            const mockReview = {
                _id: "review-1",
                status: "active",
                flagged: true,
                flagReason: "Spam",
                save: jest.fn().mockResolvedValue(true),
            };

            jest.spyOn(Review, "findById").mockResolvedValue(mockReview);

            const response = await request(app)
                .post("/admin/moderation/reviews/review-1/dismiss")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(mockReview.flagged).toBe(false);
            expect(mockReview.flagReason).toBe("");
            expect(mockReview.save).toHaveBeenCalled();
        });
    });
    describe("GET /admin/metrics", () => {
        it("returns 403 for non-Admin users", async () => {
            const response = await request(app)
                .get("/admin/metrics")
                .set("Authorization", `Bearer ${climberToken}`);
            expect(response.status).toBe(403);
        });

        it("returns metrics object for Admin", async () => {
            jest.spyOn(ClimbingSession, "distinct").mockResolvedValue(["user1", "user2"]);
            jest.spyOn(User, "countDocuments").mockResolvedValue(100);
            jest.spyOn(Wall, "countDocuments").mockResolvedValue(20);
            jest.spyOn(Review, "countDocuments").mockResolvedValue(300);
            jest.spyOn(Group, "countDocuments").mockResolvedValue(10);
            jest.spyOn(Event, "countDocuments").mockResolvedValue(5);
            jest.spyOn(Report, "countDocuments").mockResolvedValue(2);
            
const now = new Date();
            const year = now.getFullYear();
            const month = now.getMonth() + 1;
            
            jest.spyOn(User, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 10 }]);
            jest.spyOn(ClimbingSession, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 50 }]);
            jest.spyOn(Event, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 2 }]);
            jest.spyOn(Review, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 15 }]);
            jest.spyOn(Group, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 3 }]);
            jest.spyOn(Wall, "aggregate").mockResolvedValue([{ _id: { year, month }, count: 8 }]);

            const response = await request(app)
                .get("/admin/metrics")
                .set("Authorization", `Bearer ${adminToken}`);

            expect(response.status).toBe(200);
            expect(response.body.activeUsers).toBe(2);
            expect(response.body.totalUsers).toBe(100);
            expect(response.body.totalWalls).toBe(20);
            expect(response.body.totalReviews).toBe(300);
            expect(response.body.totalGroups).toBe(10);
            expect(response.body.totalEvents).toBe(5);
            expect(response.body.openReports).toBe(2);
            expect(response.body.graphs.userRegistrations.length).toBe(12);
            expect(response.body.graphs.sessionsLogged.length).toBe(12);
            expect(response.body.graphs.eventsCreated.length).toBe(12);
            expect(response.body.graphs.reviewsAdded.length).toBe(12);
            expect(response.body.graphs.groupsCreated.length).toBe(12);
            expect(response.body.graphs.wallsAdded.length).toBe(12);

            const lastUserReg = response.body.graphs.userRegistrations[11];
            expect(lastUserReg.count).toBe(10);
            expect(response.body.graphs.sessionsLogged[11].count).toBe(50);
            expect(response.body.graphs.eventsCreated[11].count).toBe(2);

        });
    });

});
