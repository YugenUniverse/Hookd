const { Wall } = require("../models/Wall");
const { Facility, PublicBody } = require("../models/User");

exports.createWall = async (wallData, userId, userType) => {
    let wall;

    if (userType === "Facility") {
        wall = await IndoorWall.create({ ...wallData, facility: userId });

        await Facility.findByIdAndUpdate(userId, {
            $push: { walls: wall._id },
        });
    } else if (userType === "PublicBody") {
        wall = await OutdoorWall.create({ ...wallData, publicBody: userId });

        await PublicBody.findByIdAndUpdate(userId, {
            $push: { walls: wall._id },
        });
    } else {
        const error = new Error(
            "Only Facilities and Public Bodies can create walls.",
        );
        error.statusCode = 403;
        throw error;
    }

    return wall;
};

exports.getAllWalls = async () => {
    return await Wall.find()
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar")
        .populate("sessions");
};

exports.getWallById = async (id) => {
    const wall = await Wall.findById(id)
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar")
        .populate("sessions");

    if (!wall) {
        const error = new Error("Wall not found");
        error.statusCode = 404;
        throw error;
    }
    return wall;
};

exports.searchWalls = async (searchQuery) => {
    const escaped = searchQuery.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    return await Wall.find({
        name: { $regex: `.*${escaped}.*`, $options: "i" },
    })
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar");
};

exports.getWallsByLocation = async (lng, lat, radius) => {
    return await Wall.find({
        location: {
            $near: {
                $geometry: {
                    type: "Point",
                    coordinates: [parseFloat(lng), parseFloat(lat)],
                },
                $maxDistance: parseInt(radius),
            },
        },
    })
        .populate("facility", "username email avatar")
        .populate("publicBody", "username email avatar");
};

exports.deleteWall = async (id, userId, userType) => {
    const wall = await Wall.findById(id);

    if (!wall) {
        const error = new Error("Wall not found");
        error.statusCode = 404;
        throw error;
    }
    if (userType === "Facility" && wall.facility.toString() !== userId) {
        const error = new Error(
            "You do not have permission to delete this wall",
        );
        error.statusCode = 403;
        throw error;
    }
    if (userType === "PublicBody" && wall.publicBody.toString() !== userId) {
        const error = new Error(
            "You do not have permission to delete this wall",
        );
        error.statusCode = 403;
        throw error;
    }

    if (userType === "Facility") {
        await Facility.findByIdAndUpdate(userId, {
            $pull: { walls: wall._id },
        });
    } else if (userType === "PublicBody") {
        await PublicBody.findByIdAndUpdate(userId, {
            $pull: { walls: wall._id },
        });
    }
    await wall.deleteOne();
};
