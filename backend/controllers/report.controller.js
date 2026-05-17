const reportService = require("../services/report.service");
const { Wall } = require("../models/Wall");
const mongoose = require("mongoose");
exports.getWallReport = async (req, res, next) => {
    try {
        const { wallId } = req.params;

        const wall = await Wall.findById(wallId);
        if (!wall) return res.status(404).json({ message: "Wall not found" });

        let isOwner = false;
        if (req.user.userType === "FacilityOwner") {
            const Facility = mongoose.model("Facility");
            const facilityProfile = await Facility.findOne({
                ownerAccount: req.user.id,
            });

            isOwner =
                wall.facility?.toString() === facilityProfile?._id.toString() ||
                wall.facility?.toString() === req.user.id;
        } else if (req.user.userType === "PublicBody") {
            isOwner = wall.publicBody?.toString() === req.user.id;
        }

        if (!isOwner) {
            return res.status(403).json({
                message:
                    "You do not have permission to view reports for this wall.",
            });
        }

        const reportData = await reportService.getWallReport(wallId);
        res.status(200).json(reportData);
    } catch (err) {
        console.error(err);
        next(err);
    }
};

exports.saveReport = async (req, res, next) => {
    try {
        const { wallId } = req.params;
        const { title, notes } = req.body;

        if (!title) {
            return res
                .status(400)
                .json({ message: "A title is required to save a report." });
        }

        const wall = await Wall.findById(wallId);
        if (!wall) return res.status(404).json({ message: "Wall not found" });

        let isOwner = false;
        if (req.user.userType === "FacilityOwner") {
            const Facility = mongoose.model("Facility");
            const facilityProfile = await Facility.findOne({
                ownerAccount: req.user.id,
            });

            isOwner =
                wall.facility?.toString() === facilityProfile?._id.toString() ||
                wall.facility?.toString() === req.user.id;
        } else if (req.user.userType === "PublicBody") {
            isOwner = wall.publicBody?.toString() === req.user.id;
        }

        if (!isOwner) {
            return res.status(403).json({
                message:
                    "You do not have permission to save reports for this wall.",
            });
        }

        const savedReport = await reportService.saveReport(
            req.user.id,
            wallId,
            title,
            notes,
        );

        res.status(201).json({
            message: "Report snapshot saved successfully",
            report: savedReport,
        });
    } catch (err) {
        console.error(err);
        next(err);
    }
};

exports.getReports = async (req, res, next) => {
    try {
        const reports = await reportService.getReportsList(req.user.id);
        res.status(200).json(reports);
    } catch (err) {
        next(err);
    }
};

exports.getReportById = async (req, res, next) => {
    try {
        const report = await reportService.getReportById(
            req.params.id,
            req.user.id,
        );
        res.status(200).json(report);
    } catch (err) {
        next(err);
    }
};

exports.deleteReport = async (req, res, next) => {
    try {
        await reportService.deleteReport(req.params.id, req.user.id);
        res.status(200).json({ message: "Report deleted successfully" });
    } catch (err) {
        next(err);
    }
};
