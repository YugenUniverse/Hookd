const reportService = require("../services/report.service");

exports.createIssueReport = async (req, res, next) => {
    try {
        const report = await reportService.createIssueReport(
            req.user.id,
            req.user.userType,
            req.body,
        );
        res.status(201).json({ report });
    } catch (err) {
        next(err);
    }
};

exports.getIssueReportsForWall = async (req, res, next) => {
    try {
        const reports = await reportService.getIssueReportsForWall(
            req.user.id,
            req.user.userType,
            req.params.wallId,
        );
        res.json({ reports });
    } catch (err) {
        next(err);
    }
};

exports.getIssueReportsByClimber = async (req, res, next) => {
    try {
        const reports = await reportService.getIssueReportsByClimber(
            req.user.id,
        );
        res.json({ reports });
    } catch (err) {
        next(err);
    }
};

exports.deleteIssueReport = async (req, res, next) => {
    try {
        await reportService.deleteIssueReport(req.params.reportId, req.user.id);
        res.status(204).end();
    } catch (err) {
        next(err);
    }
};
