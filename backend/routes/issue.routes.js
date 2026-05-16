const express = require("express");
const mongoose = require("mongoose");
const { authenticateJwt } = require("../middleware/auth.middleware");
const issueController = require("../controllers/issue.controllers");

const router = express.Router();

const VALID_ISSUE_STATUSES = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];

// Validation middleware
const validateCreateIssueInput = (req, res, next) => {
    const { wall_id, body } = req.body;

    // Check required fields
    if (!wall_id || !body) {
        return res.status(400).json({
            error: "wall_id and body are required",
        });
    }

    // Validate wall_id is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(wall_id)) {
        return res.status(400).json({
            error: "wall_id must be a valid ObjectId",
        });
    }

    // Validate body is a string
    if (typeof body !== "string") {
        return res.status(400).json({
            error: "body must be a string",
        });
    }

    // Validate body length
    if (body.trim().length === 0) {
        return res.status(400).json({
            error: "body cannot be empty",
        });
    }

    if (body.length > 500) {
        return res.status(400).json({
            error: "body cannot exceed 500 characters",
        });
    }

    next();
};

const validateUpdateIssueStatusInput = (req, res, next) => {
    const { status } = req.body;

    if (!status || typeof status !== "string") {
        return res.status(400).json({
            error: "status is required and must be a string",
        });
    }

    if (!VALID_ISSUE_STATUSES.includes(status)) {
        return res.status(400).json({
            error: `Invalid status. Valid values are: ${VALID_ISSUE_STATUSES.join(", ")}`,
        });
    }

    next();
};

router.use(authenticateJwt);
router.post("/", validateCreateIssueInput, issueController.createIssue);
router.get("/walls/:wallId", issueController.getIssuesForWall);
router.get("/my-issues", issueController.getIssuesByUser);
router.patch(
    "/:issueId/status",
    validateUpdateIssueStatusInput,
    issueController.updateIssueStatus,
);
router.delete("/:issueId", issueController.deleteIssue);
module.exports = router;
