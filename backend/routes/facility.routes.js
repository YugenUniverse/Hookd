const express = require("express");
const router = express.Router();
const Facility = require("../models/Facility");
const { FacilityOwner } = require("../models/User");
const { authenticateJwt, restrictTo } = require("../middleware/auth.middleware");

const getOwnerFacility = async (ownerId) => {
    const owner = await FacilityOwner.findById(ownerId).populate("facility");
    return owner;
};

// Search unclaimed facilities by name (requires auth).
router.get("/search", async (req, res, next) => {
    try {
        const { q } = req.query;
        if (!q || q.trim().length < 2) {
            return res.status(400).json({ message: "Query must be at least 2 characters" });
        }

        const escaped = q.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const facilities = await Facility.find({
            name: { $regex: escaped, $options: "i" },
            ownerAccount: { $exists: false },
        })
            .select("name location")
            .limit(10);

        res.json(facilities);
    } catch (err) {
        next(err);
    }
});

// Claim an unclaimed facility — restricted to FacilityOwner accounts.
router.post("/:id/claim", authenticateJwt, restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        const facility = await Facility.findById(req.params.id);
        if (!facility) {
            return res.status(404).json({ message: "Facility not found" });
        }
        const userId = req.user.id;

        if (facility.ownerAccount && facility.ownerAccount.toString() !== userId) {
            return res.status(409).json({ message: "This facility already has an owner" });
        }

        const owner = await getOwnerFacility(userId);
        if (owner?.facility && owner.facility._id?.toString() === facility._id.toString()) {
            return res.json({ message: "Facility claimed successfully", facility });
        }

        if (owner?.facility && owner.facility._id?.toString() !== facility._id.toString()) {
            await Facility.findByIdAndUpdate(owner.facility._id, {
                $unset: { ownerAccount: 1 },
            });
        }

        facility.ownerAccount = userId;
        await facility.save();

        await FacilityOwner.findByIdAndUpdate(userId, { facility: facility._id });

        res.json({ message: "Facility claimed successfully", facility });
    } catch (err) {
        next(err);
    }
});

// Update the facility linked to the authenticated FacilityOwner account.
router.put("/:id", authenticateJwt, restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        const facility = await Facility.findById(req.params.id);
        if (!facility) {
            return res.status(404).json({ message: "Facility not found" });
        }

        const owner = await getOwnerFacility(req.user.id);
        if (!owner?.facility || owner.facility._id.toString() !== facility._id.toString()) {
            return res.status(403).json({ message: "You are not the owner of this facility" });
        }

        const allowedUpdates = ["name", "description", "location"];
        for (const key of allowedUpdates) {
            if (req.body[key] !== undefined) {
                facility[key] = req.body[key];
            }
        }

        await facility.save();

        res.json({ message: "Facility updated successfully", facility });
    } catch (err) {
        if (err.name === "ValidationError") err.statusCode = 400;
        next(err);
    }
});

// Unpair the authenticated FacilityOwner from its facility.
router.post("/:id/unpair", authenticateJwt, restrictTo("FacilityOwner"), async (req, res, next) => {
    try {
        const facility = await Facility.findById(req.params.id);
        if (!facility) {
            return res.status(404).json({ message: "Facility not found" });
        }

        const owner = await getOwnerFacility(req.user.id);
        if (!owner?.facility || owner.facility._id.toString() !== facility._id.toString()) {
            return res.status(403).json({ message: "You are not the owner of this facility" });
        }

        facility.ownerAccount = undefined;
        await facility.save();

        await FacilityOwner.findByIdAndUpdate(req.user.id, { $unset: { facility: 1 } });

        res.json({ message: "Facility unpaired successfully", facility });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
