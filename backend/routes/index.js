var express = require("express");
var router = express.Router();

const { User } = require("../models/User");
const { authenticateJwt } = require("../middleware/auth.middleware");

/* GET all users */
router.get("/", authenticateJwt, async function (req, res, next) {
    try {
        const users = await User.find();
        res.json(users);
    } catch (err) {
        next(err);
    }
});

module.exports = router;
