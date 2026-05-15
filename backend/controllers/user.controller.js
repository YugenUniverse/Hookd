const mongoose = require("mongoose");
const { User } = require("../models/User");

const selectPublicProjection = {
    username: 1,
    avatar: 1,
    userType: 1,
    bio: 1,
    description: 1,
    location: 1,
};

exports.getPublicUserById = async (req, res, next) => {
    try {
        const { id } = req.params;

        if (!mongoose.Types.ObjectId.isValid(id)) {
            const error = new Error("Invalid user id");
            error.statusCode = 400;
            throw error;
        }

        const user = await User.findById(id).select(selectPublicProjection).lean();

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

        const user = await User.findById(req.user.id);

        if (!user) {
            const error = new Error("User not found");
            error.statusCode = 404;
            throw error;
        }

        res.status(200).json(user.toJSON());
    } catch (err) {
        next(err);
    }
};
