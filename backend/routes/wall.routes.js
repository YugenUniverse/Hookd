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

// Get a single wall by ID (🚨 MUST be the last GET route!)
router.get("/:id", wallController.getWallById);

//Protected

// Create a new wall
router.post(
    "/",
    authenticateJwt,
    restrictTo("Facility", "PublicBody"),
    wallController.createWall,
);

// Delete a wall
router.delete(
    "/:id",
    authenticateJwt,
    restrictTo("Facility", "PublicBody"),
    wallController.deleteWall,
);

module.exports = router;
