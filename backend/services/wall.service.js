const { Wall } = require("../models/Wall");

exports.createWall = async (wallData, userId, userType) => {
    if (userType === "Facility") {
        wallData.facility = userId;
    } else if (userType === "PublicBody") {
        wallData.publicBody = userId;
    }

    const newWall = await Wall.create(wallData);
    return newWall;
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
    return await Wall.find({ $text: { $search: searchQuery } })
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

    const isFacilityOwner =
        userType === "Facility" && wall.facility?.toString() === userId;
    const isPublicBodyOwner =
        userType === "PublicBody" && wall.publicBody?.toString() === userId;

    if (!isFacilityOwner && !isPublicBodyOwner) {
        const error = new Error(
            "You do not have permission to delete this wall",
        );
        error.statusCode = 403;
        throw error;
    }

    await wall.deleteOne();
    return true;
};
