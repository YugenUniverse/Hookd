const express = require("express");
const userController = require("../controllers/user.controller");
const { authenticateJwt } = require("../middleware/auth.middleware");

const router = express.Router();

router.get("/me", authenticateJwt, userController.getCurrentUser);
router.patch("/me", authenticateJwt, userController.updateCurrentUser);
router.get("/:id([0-9a-fA-F]{24})", userController.getPublicUserById);

module.exports = router;
