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

module.exports = {
    getPublicUserById,
    getUserById,
    getUserByJwtId,
};
