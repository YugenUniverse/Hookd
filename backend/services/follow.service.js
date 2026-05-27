const Follow = require("../models/Follow");

exports.follow = async (followerId, followingId) => {
    if (followerId.toString() === followingId.toString()) {
        const err = new Error("Cannot follow yourself");
        err.statusCode = 400;
        throw err;
    }
    try {
        await Follow.create({ follower: followerId, following: followingId });
    } catch (err) {
        if (err.code === 11000) return; // already following — idempotent
        throw err;
    }
};

exports.unfollow = async (followerId, followingId) => {
    await Follow.deleteOne({ follower: followerId, following: followingId });
};

exports.getFollowing = async (userId, { limit = 50, skip = 0 } = {}) => {
    return Follow.find({ follower: userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("following", "username email userType");
};

exports.getFollowers = async (userId, { limit = 50, skip = 0 } = {}) => {
    return Follow.find({ following: userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("follower", "username email userType");
};

exports.isFollowing = async (followerId, followingId) => {
    return !!(await Follow.exists({ follower: followerId, following: followingId }));
};

exports.getFollowerIds = async (followingId) => {
    const docs = await Follow.find({ following: followingId }).select("follower");
    return docs.map((d) => d.follower);
};
