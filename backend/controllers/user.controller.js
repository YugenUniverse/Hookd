const mongoose = require("mongoose");
const userService = require("../services/user.service");
const Facility = require("../models/Facility");
const { FacilityOwner } = require("../models/User");

exports.getPublicUserById = async (req, res, next) => {
    try {
        const { id } = req.params;

        if (!mongoose.Types.ObjectId.isValid(id)) {
            const error = new Error("Invalid user id");
            error.statusCode = 400;
            throw error;
        }

        const user = await userService.getPublicUserById(id);

        if (!user) {
            const error = new Error("User not found");
            error.statusCode = 404;
            throw error;
        }

        const publicUser = {
            id: user._id.toString(),
            username: user.username,
            avatar: user.avatar || "",
            userType: user.userType,
            profile: {
                bio: user.bio || "",
                description: user.description || "",
                location: user.location || null,
            },
        };

        switch (user.userType) {
            case "FacilityOwner":
                if (user.facility) {
                    await mongoose.model("User").populate(user, {
                        path: "facility",
                        populate: {
                            path: "walls",
                            select: "name description difficulty status rating wallType",
                        },
                    });
                    publicUser.facility = user.facility;
                }
                break;
            case "PublicBody":
                if (user.walls?.length) {
                    await mongoose.model("User").populate(user, {
                        path: "walls",
                        select: "name description difficulty status rating wallType",
                    });
                    publicUser.walls = user.walls;
                }
                break;
            case "Climber":
                if (user.wallet) {
                    await mongoose.model("User").populate(user, { path: "wallet.badges.badge" });
                    publicUser.wallet = user.wallet;
                }
                break;
        }

        res.status(200).json(publicUser);
    } catch (err) {
        next(err);
    }
};

exports.getCurrentUser = async (req, res, next) => {
    try {
        if (!req.user || !req.user.id) {
            const error = new Error("Unauthorized");
            error.statusCode = 401;
            throw error;
        }

        const user = await userService.getUserById(req.user.id);

        if (!user) {
            const error = new Error("User not found");
            error.statusCode = 404;
            throw error;
        }

        switch (user.userType) {
            case "FacilityOwner":
                if (!user.facility) {
                    const linked = await Facility.findOne({ ownerAccount: user._id }).select("_id");
                    if (linked) {
                        await FacilityOwner.findByIdAndUpdate(user._id, { facility: linked._id });
                        user.facility = linked._id;
                    }
                }
                if (user.facility) {
                    await user.populate({
                        path: "facility",
                        populate: {
                            path: "walls",
                            select: "name description difficulty status rating wallType",
                        },
                    });
                }
                break;
            case "PublicBody":
                if (user.walls?.length) {
                    await user.populate({
                        path: "walls",
                        select: "name description difficulty status rating wallType",
                    });
                }
                break;
            case "Climber":
                if (user.wallet) {
                    await user.populate("wallet.badges.badge");
                }
                break;
        }

        res.status(200).json(user.toJSON());
    } catch (err) {
        next(err);
    }
};
