const express = require("express");
const router = express.Router();
const { authenticateJwt } = require("../middleware/auth.middleware");
const followService = require("../services/follow.service");

router.use(authenticateJwt);

// Follow a user
router.post("/:targetId", async (req, res, next) => {
    try {
        await followService.follow(req.user.id, req.params.targetId);
        res.json({ message: "Followed" });
    } catch (err) {
        res.status(err.statusCode || 500).json({ message: err.message });
    }
});

// Unfollow a user
router.delete("/:targetId", async (req, res, next) => {
    try {
        await followService.unfollow(req.user.id, req.params.targetId);
        res.json({ message: "Unfollowed" });
    } catch (err) {
        next(err);
    }
});

// Check if the current user follows a specific user
router.get("/check/:targetId", async (req, res, next) => {
    try {
        const following = await followService.isFollowing(req.user.id, req.params.targetId);
        res.json({ following });
    } catch (err) {
        next(err);
    }
});

// Who the current user follows
router.get("/me", async (req, res, next) => {
    try {
        const follows = await followService.getFollowing(req.user.id);
        res.json({ following: follows.map((f) => f.following) });
    } catch (err) {
        next(err);
    }
});

// Followers of the current user
router.get("/me/followers", async (req, res, next) => {
    try {
        const follows = await followService.getFollowers(req.user.id);
        res.json({ followers: follows.map((f) => f.follower) });
    } catch (err) {
        next(err);
    }
});

// Followers of a given user
router.get("/:userId/followers", async (req, res, next) => {
    try {
        const follows = await followService.getFollowers(req.params.userId);
        res.json({ followers: follows.map((f) => f.follower) });
    } catch (err) {
        next(err);
    }
});

// Who a given user follows
router.get("/:userId/following", async (req, res, next) => {
    try {
        const follows = await followService.getFollowing(req.params.userId);
        res.json({ following: follows.map((f) => f.following) });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
