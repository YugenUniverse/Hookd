const express = require("express");
const adminController = require("../controllers/admin.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

const router = express.Router();

router.use(authenticateJwt, restrictTo("Admin"));

router.get("/approvals/pending", adminController.getPendingApprovals);
router.put("/approvals/:userId/approve", adminController.approveAccount);
router.put("/approvals/:userId/reject", adminController.rejectAccount);

router.get("/moderation/flagged", adminController.getFlaggedReviews);
router.delete("/moderation/reviews/:reviewId", adminController.removeReview);
router.post("/moderation/reviews/:reviewId/dismiss", adminController.dismissFlag);

module.exports = router;
