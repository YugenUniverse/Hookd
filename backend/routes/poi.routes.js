const express = require("express");
const router = express.Router();

const poiController = require("../controllers/poi.controller");

router.get("/search", poiController.searchPois);
router.get("/nearby", poiController.getNearbyPois);
router.get("/", poiController.getAllPois);

module.exports = router;
