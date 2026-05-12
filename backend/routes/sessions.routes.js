const express = require("express");
const { authenticateJwt } = require("../middleware/auth.middleware");
const sessionController = require("../controllers/session.controller");

const router = express.Router();

router.use(authenticateJwt);

router.post("/", sessionController.createSession);
router.post("/:sessionId/review", sessionController.addReviewToSession);
router.get("/", sessionController.getSessions);
router.get("/:sessionId", sessionController.getSessionById);
router.put("/:sessionId", sessionController.updateSession);
router.delete("/:sessionId", sessionController.deleteSession);

module.exports = router;
