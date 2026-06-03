const express = require("express");
const router = express.Router();

const reportController = require("../controllers/report.controller");
const {
    authenticateJwt,
    restrictTo,
} = require("../middleware/auth.middleware");

router.use(authenticateJwt);
router.use(restrictTo("FacilityOwner", "PublicBody"));

// GET live dynamic data
router.get("/wall/:wallId", reportController.getWallReport);

// GET statistics filtered by geographic area and time range
router.get("/stats/area-time", reportController.getStatisticsByAreaAndTime);

// POST request to generate and save a snapshot
router.post("/wall/:wallId/save", reportController.saveReport);

// POST request to generate and save a snapshot for multiple walls
router.post("/walls/save", reportController.saveGroupReport);

// GET list of all saved reports (lightweight list)
router.get("/saved", reportController.getReports);

// GET saved report as CSV
router.get("/saved/:id/export", reportController.exportSavedReportCsv);

// GET a specific saved report (includes full heavy data)
router.get("/saved/:id", reportController.getReportById);

// DELETE a specific saved report
router.delete("/saved/:id", reportController.deleteReport);

module.exports = router;
