const { Wall } = require("../models/Wall");
const Facility = require("../models/Facility");

// Query that selects OutdoorWalls + legacy walls seeded before the discriminator
// was introduced (wallType missing). IndoorWalls are owned by Facilities and
// appear on the map as part of their Facility POI, not as top-level POIs.
const OUTDOOR_WALL_FILTER = { wallType: { $ne: "IndoorWall" } };

const toOutdoorWallPoi = (wall) => ({
    poiType: "OutdoorWall",
    id: wall._id.toString(),
    name: wall.name,
    description: wall.description || "",
    location: wall.location,
    difficulty: wall.difficulty,
    rating: wall.rating ?? 0,
    status: wall.status,
    ownerName: wall.publicBody?.name || wall.publicBody?.username || null,
});

const toFacilityPoi = (facility) => ({
    poiType: "Facility",
    id: facility._id.toString(),
    name: facility.name || facility.username,
    description: facility.description || "",
    location: facility.location,
    address: facility.location?.address || null,
    ownerAccountId: facility.ownerAccount?.toString() ?? null,
    walls: (facility.walls || []).map((w) => ({
        id: w._id.toString(),
        name: w.name,
        difficulty: w.difficulty,
        rating: w.rating ?? 0,
        status: w.status,
    })),
});

exports.getNearbyPois = async (lng, lat, radius) => {
    const nearGeo = {
        $near: {
            $geometry: {
                type: "Point",
                coordinates: [parseFloat(lng), parseFloat(lat)],
            },
            $maxDistance: parseInt(radius),
        },
    };

    const [outdoorWalls, facilities] = await Promise.all([
        Wall.find({ location: nearGeo, ...OUTDOOR_WALL_FILTER }).populate(
            "publicBody",
            "name username",
        ),
        Facility.find({ location: nearGeo }).populate(
            "walls",
            "name difficulty rating status",
        ),
    ]);

    return [
        ...outdoorWalls.map(toOutdoorWallPoi),
        ...facilities.map(toFacilityPoi),
    ];
};

exports.searchPois = async (query) => {
    const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regex = { $regex: `.*${escaped}.*`, $options: "i" };

    const [outdoorWalls, facilities] = await Promise.all([
        Wall.find({ name: regex, ...OUTDOOR_WALL_FILTER }).populate(
            "publicBody",
            "name username",
        ),
        Facility.find({ name: regex }).populate(
            "walls",
            "name difficulty rating status",
        ),
    ]);

    return [
        ...outdoorWalls.map(toOutdoorWallPoi),
        ...facilities.map(toFacilityPoi),
    ];
};

exports.getAllPois = async () => {
    const [outdoorWalls, facilities] = await Promise.all([
        Wall.find(OUTDOOR_WALL_FILTER).populate("publicBody", "name username"),
        Facility.find().populate("walls", "name difficulty rating status"),
    ]);

    return [
        ...outdoorWalls.map(toOutdoorWallPoi),
        ...facilities.map(toFacilityPoi),
    ];
};
