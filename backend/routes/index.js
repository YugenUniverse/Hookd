var express = require("express");
var router = express.Router();

const { User, Facility, PublicBody } = require("../models/User");

/* GET all users */
router.get("/", async function (req, res, next) {
    try {
        const users = await User.find();
        res.json(users);
    } catch (err) {
        next(err);
    }
});

module.exports = router;
