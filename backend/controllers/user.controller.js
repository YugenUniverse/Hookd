const mongoose = require("mongoose");
const userService = require("../services/user.service");

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

        if (user.userType === "FacilityOwner" && user.facility) {
            await user.populate({
                path: "facility",
                populate: {
                    path: "walls",
                    select: "name description difficulty status rating wallType",
                },
            });
        }

        if (user.userType === "PublicBody" && user.walls?.length) {
            await user.populate({
                path: "walls",
                select: "name description difficulty status rating wallType",
            });
        }

        res.status(200).json(user.toJSON());
    } catch (err) {
        next(err);
    }
};
