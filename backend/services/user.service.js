const mongoose = require("mongoose");
const { User } = require("../models/User");

const SELECT_PUBLIC = {
    username: 1,
    avatar: 1,
    userType: 1,
    bio: 1,
    description: 1,
    location: 1,
};

async function getPublicUserById(id) {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    return await User.findById(id).select(SELECT_PUBLIC).lean();
}

async function getUserById(id) {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    return await User.findById(id);
}

async function getUserByJwtId(jwtId) {
    return getUserById(jwtId);
}

async function updateUser(id, updates) {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    const user = await User.findById(id);
    if (!user) return null;

    const allowedBase = ["username", "avatar"];
    const allowedClimber = ["name", "surname", "bio", "birthdate"];

    for (const field of allowedBase) {
        if (updates[field] !== undefined) user[field] = updates[field];
    }

    if (user.userType === "Climber") {
        for (const field of allowedClimber) {
            if (updates[field] !== undefined) user[field] = updates[field];
        }
    }

    return await user.save();
}

module.exports = {
    getPublicUserById,
    getUserById,
    getUserByJwtId,
    updateUser,
};
