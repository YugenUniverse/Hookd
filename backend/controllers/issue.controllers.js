const issueService = require("../services/issue.service");

exports.createIssue = async (req, res, next) => {
    try {
        const issue = await issueService.createIssue(
            req.user.id,
            req.user.userType,
            req.body,
        );
        res.status(201).json({ issue });
    } catch (err) {
        next(err);
    }
};

exports.getIssuesForWall = async (req, res, next) => {
    try {
        const issues = await issueService.getIssuesForWall(
            req.user.id,
            req.user.userType,
            req.params.wallId,
        );
        res.json({ issues });
    } catch (err) {
        next(err);
    }
};

exports.getIssuesByUser = async (req, res, next) => {
    try {
        let issues;
        if (req.user.userType === "Climber") {
            issues = await issueService.getIssuesByClimber(req.user.id);
        } else if (req.user.userType === "PublicBody") {
            issues = await issueService.getIssuesByPublicBody(req.user.id);
        } else if (req.user.userType === "FacilityOwner") {
            issues = await issueService.getIssuesByFacility(req.user.id);
        } else {
            const error = new Error("Invalid user type");
            error.statusCode = 400;
            throw error;
        }

        res.json({ issues });
    } catch (err) {
        next(err);
    }
};

exports.updateIssueStatus = async (req, res, next) => {
    try {
        const issue = await issueService.updateIssueStatus(
            req.params.issueId,
            req.body.status,
            req.user.id,
            req.user.userType,
        );

        res.json({ issues: [issue] });
    } catch (err) {
        next(err);
    }
};

exports.deleteIssue = async (req, res, next) => {
    try {
        await issueService.deleteIssue(req.params.issueId, req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
};
