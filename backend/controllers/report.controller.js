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

exports.saveGroupReport = async (req, res, next) => {
    try {
        const { title, notes } = req.body;
        const wallIds = Array.isArray(req.body.wallIds)
            ? req.body.wallIds
            : Array.isArray(req.body.wall_ids)
              ? req.body.wall_ids
              : undefined;

        if (!title) {
            return res
                .status(400)
                .json({ message: "A title is required to save a report." });
        }

        if (!Array.isArray(wallIds) || wallIds.length < 2) {
            return res.status(400).json({
                message:
                    "At least two wall IDs are required to save a group report.",
            });
        }

        const walls = await Wall.find({ _id: { $in: wallIds } });
        if (walls.length !== wallIds.length) {
            return res
                .status(404)
                .json({ message: "One or more walls not found" });
        }

        let isOwner = false;
        if (req.user.userType === "FacilityOwner") {
            const Facility = mongoose.model("Facility");
            const facilityProfile = await Facility.findOne({
                ownerAccount: req.user.id,
            });

            isOwner = walls.every(
                (wall) =>
                    wall.facility?.toString() ===
                        facilityProfile?._id.toString() ||
                    wall.facility?.toString() === req.user.id,
            );
        } else if (req.user.userType === "PublicBody") {
            isOwner = walls.every(
                (wall) => wall.publicBody?.toString() === req.user.id,
            );
        }

        if (!isOwner) {
            return res.status(403).json({
                message:
                    "You do not have permission to save reports for these walls.",
            });
        }

        const savedReport = await reportService.saveGroupReport(
            req.user.id,
            wallIds,
            title,
            notes,
        );

        res.status(201).json({
            message: "Group report snapshot saved successfully",
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

exports.exportSavedReportCsv = async (req, res, next) => {
    try {
        const report = await reportService.getReportById(
            req.params.id,
            req.user.id,
        );

        const csv = reportService.generateSavedReportCsv(report, req.query);
        const safeTitle = (report.title || "report")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/^-+|-+$/g, "")
            .slice(0, 40);
        const timestamp = new Date().toISOString().slice(0, 10);

        res.setHeader("Content-Type", "text/csv; charset=utf-8");
        res.setHeader(
            "Content-Disposition",
            `attachment; filename="${safeTitle || "report"}-${timestamp}.csv"`,
        );
        res.status(200).send(csv);
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

/**
 * Get statistics filtered by geographic area and time range
 * Query params:
 *   - minLat, maxLat, minLng, maxLng: geographic bounds
 *   - startDate, endDate: time range (ISO 8601 format)
 */
exports.getStatisticsByAreaAndTime = async (req, res, next) => {
    try {
        const { minLat, maxLat, minLng, maxLng, startDate, endDate } =
            req.query;

        // Validate required parameters
        const requiredParams = [
            "minLat",
            "maxLat",
            "minLng",
            "maxLng",
            "startDate",
            "endDate",
        ];
        const missingParams = requiredParams.filter((p) => !req.query[p]);

        if (missingParams.length > 0) {
            return res.status(400).json({
                message: `Missing required query parameters: ${missingParams.join(", ")}`,
            });
        }

        // Parse numeric values
        const bounds = {
            minLat: parseFloat(minLat),
            maxLat: parseFloat(maxLat),
            minLng: parseFloat(minLng),
            maxLng: parseFloat(maxLng),
        };

        // Validate bounds are numbers
        if (Object.values(bounds).some((val) => isNaN(val))) {
            return res.status(400).json({
                message: "Geographic bounds must be valid numbers",
            });
        }

        const stats = await reportService.getStatisticsByAreaAndTime(
            bounds.minLat,
            bounds.maxLat,
            bounds.minLng,
            bounds.maxLng,
            startDate,
            endDate,
        );

        res.status(200).json(stats);
    } catch (err) {
        next(err);
    }
};
