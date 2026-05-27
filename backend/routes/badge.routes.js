const express = require("express");
const router = express.Router();
const badgeController = require("../controllers/badge.controller");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

// Create a new badge (System or Custom)
router.post("/", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), badgeController.createBadge);

// Get all badges. Supports query filtering:
// Example: GET /badges?type=system
// Example: GET /badges?score=50
router.get("/", badgeController.getBadges);

// Get a specific badge by its ID
router.get("/:id", badgeController.getBadgeById);

// Update a badge's details (e.g., score or description)
router.put("/:id", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), badgeController.updateBadge);

// Delete a badge from the system
router.delete("/:id", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), badgeController.deleteBadge);

module.exports = router;
