const express = require("express");
const router = express.Router();

const wallController = require("../controllers/wall.controller");

const {
    authenticateJwt,
    restrictTo,
} = require("../middleware/auth.middleware");

// Get all walls
router.get("/", wallController.getAllWalls);

// Search walls by name (?q=keyword)
router.get("/search", wallController.searchWalls);

// Get walls near a location (?lng=11.12&lat=46.06&radius=5000)
router.get("/nearby", wallController.getWallsByLocation);

// Get wall leaderboard
router.get("/:id/leaderboard", wallController.getWallLeaderboard);

// Get walls owned by the authenticated Facility or PublicBody
router.get("/owned", authenticateJwt, restrictTo("FacilityOwner", "PublicBody"), wallController.getOwnedWalls);

// Get a single wall by ID (🚨 MUST be the last GET route!)
router.get("/:id", wallController.getWallById);

//Protected

// Create a new wall
router.post(
    "/",
    authenticateJwt,
    restrictTo("FacilityOwner", "PublicBody", "Admin"),
    wallController.createWall,
);

// Update a wall
router.put(
    "/:id",
    authenticateJwt,
    restrictTo("FacilityOwner", "PublicBody", "Admin"),
    wallController.updateWall,
);

// Delete a wall
router.delete(
    "/:id",
    authenticateJwt,
    restrictTo("FacilityOwner", "PublicBody", "Admin"),
    wallController.deleteWall,
);

module.exports = router;
