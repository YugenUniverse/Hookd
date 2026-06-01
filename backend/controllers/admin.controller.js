const { User } = require("../models/User");
const Facility = require("../models/Facility");
const notificationService = require("../services/notification.service");
const emailService = require("../services/email.service");

const getPendingApprovals = async (req, res, next) => {
    try {
        const pendingUsers = await User.find({
            userType: { $in: ["FacilityOwner", "PublicBody"] },
            approvalStatus: "pending",
        }).populate("facility");

        res.status(200).json(pendingUsers);
    } catch (err) {
        next(err);
    }
};

const approveAccount = async (req, res, next) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);

        if (!user || !["FacilityOwner", "PublicBody"].includes(user.userType)) {
            const error = new Error("User not found or not approvable");
            error.statusCode = 404;
            throw error;
        }

        if (user.approvalStatus === "approved") {
            const error = new Error("Account is already approved");
            error.statusCode = 400;
            throw error;
        }

        user.approvalStatus = "approved";
        await user.save();

        if (user.userType === "FacilityOwner" && user.facility) {
            const facility = await Facility.findById(user.facility);
            if (facility) {
                facility.ownerAccount = user._id;
                await facility.save();
            }
        }

        // Send notifications
        await notificationService.createBulk([user._id], "account_approved", {
            message: "Your account request has been approved.",
        });
        await emailService.sendAccountApprovedEmail(user);

        res.status(200).json({ message: "Account approved", user });
    } catch (err) {
        next(err);
    }
};

const rejectAccount = async (req, res, next) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);

        if (!user || !["FacilityOwner", "PublicBody"].includes(user.userType)) {
            const error = new Error("User not found or not approvable");
            error.statusCode = 404;
            throw error;
        }

        user.approvalStatus = "rejected";
        await user.save();

        // Send notifications
        await notificationService.createBulk([user._id], "account_rejected", {
            message: "Your account request has been rejected.",
        });
        await emailService.sendAccountRejectedEmail(user);

        res.status(200).json({ message: "Account rejected", user });
    } catch (err) {
        next(err);
    }
};

module.exports = {
    getPendingApprovals,
    approveAccount,
    rejectAccount,
};
