const express = require("express");
const adminController = require("../controllers/admin.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

const router = express.Router();

router.use(authenticateJwt, restrictTo("Admin"));

router.get("/approvals/pending", adminController.getPendingApprovals);
router.put("/approvals/:userId/approve", adminController.approveAccount);
router.put("/approvals/:userId/reject", adminController.rejectAccount);

module.exports = router;
