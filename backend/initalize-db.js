require("dotenv").config();

const axios = require("axios");
const mongoose = require("mongoose");
const bcrypt = require("bcrypt");
const { Wall } = require("./models/Wall");
const Facility = require("./models/Facility");
const { PublicBody } = require("./models/User");

const query = `
[out:json][timeout:90];

area(3600045757)->.searchArea;

(
  node["sport"="climbing"](area.searchArea);
  way["sport"="climbing"](area.searchArea);
  relation["sport"="climbing"](area.searchArea);

  node["climbing:indoor"="yes"](area.searchArea);
  way["climbing:indoor"="yes"](area.searchArea);
  relation["climbing:indoor"="yes"](area.searchArea);

  node["climbing:bouldering"="yes"](area.searchArea);
  way["climbing:bouldering"="yes"](area.searchArea);
  relation["climbing:bouldering"="yes"](area.searchArea);
);

out center tags;
`;

const pickDifficulty = (tags) => {
  // Bouldering areas skew beginner-friendly
  if (tags?.["climbing:boulder"] === "yes" || tags?.["climbing:bouldering"] === "yes") return "BEGINNER";
  // Trad and multipitch require solid leading skills
  if (tags?.["climbing:trad"] === "yes" || tags?.["climbing:multipitch"] === "yes") return "ADVANCED";
  // Managed indoor gyms tend to have beginner-through-intermediate grades
  if (tags?.["climbing:indoor"] === "yes" || tags?.["leisure"] === "sports_centre") return "INTERMEDIATE";
  return "UNKNOWN";
};

// Signals checked in order of certainty. Anything not matched is OutdoorWall.
const pickWallType = (tags) => {
  // Explicit indoor tags
  if (tags?.["climbing:indoor"] === "yes") return "IndoorWall";
  if (tags?.["indoor"] === "yes" || tags?.["indoor"] === "only") return "IndoorWall";
  if (tags?.["outdoor"] === "no") return "IndoorWall";
  // Indoor climbing gym tagged as a sports centre
  if (tags?.["leisure"] === "sports_centre") return "IndoorWall";
  // Feature sits inside a building (artificial wall)
  if (tags?.["building"] && tags?.["building"] !== "no") return "IndoorWall";
  return "OutdoorWall";
};

const overpassEndpoints = [
  "https://overpass-api.de/api/interpreter",
  "https://lz4.overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
];

async function runOverpassQuery() {
  const payload = new URLSearchParams({ data: query }).toString();

  let lastError;

  for (const endpoint of overpassEndpoints) {
    try {
      console.log(`Querying Overpass endpoint: ${endpoint}`);
      const response = await axios.post(endpoint, payload, {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
          Accept: "application/json",
          "User-Agent": "HookdImporter/1.0 (+https://github.com/mattia/Hookd)",
        },
        timeout: 120000,
        validateStatus: (status) => status >= 200 && status < 300,
      });

      return response.data;
    } catch (error) {
      lastError = error;
      const status = error.response?.status;
      console.warn(
        `Overpass endpoint failed${status ? ` with status ${status}` : ""}: ${endpoint}`,
      );

      // 406/429/5xx are often endpoint-specific; try the next mirror.
      if (status && ![406, 408, 429, 500, 502, 503, 504].includes(status)) {
        throw error;
      }
    }
  }

  throw lastError || new Error("All Overpass endpoints failed");
}

async function main() {
  await mongoose.connect(process.env.MONGO_URI || "mongodb://localhost:27017/hookd");

  // Upsert the PublicBody that will own all seeded outdoor walls
  const seedPasswordPlain = process.env.SEED_PUBLICBODY_PASSWORD || "hookd_test_password";
  const seedPasswordHash = await bcrypt.hash(seedPasswordPlain, 10);

  const regioneTrentino = await PublicBody.findOneAndUpdate(
    { username: "regione_trentino" },
    {
      $set: {
        name: "Regione Trentino",
        description: "Autonomous Province of Trento — manages outdoor climbing areas in the Trentino region.",
        location: { type: "Point", coordinates: [11.1217, 46.0667] },
      },
      $setOnInsert: {
        email: "regione.trentino@hookd.internal",
        username: "regione_trentino",
        password: seedPasswordHash,
        authMethods: ["local"],
      },
    },
    { upsert: true, new: true },
  );
  console.log(`PublicBody "Regione Trentino" ready (id: ${regioneTrentino._id})`);

  const responseData = await runOverpassQuery();
  const elements = responseData?.elements || [];
  let imported = 0;
  let skipped = 0;
  const outdoorWallIds = [];

  for (const el of elements) {
    const tags = el.tags || {};
    const lat = el.lat ?? el.center?.lat;
    const lon = el.lon ?? el.center?.lon;

    if (lat == null || lon == null) {
      skipped += 1;
      continue;
    }

    const name = tags.name || "Unnamed climbing wall";
    const difficulty = pickDifficulty(tags);
    const wallType = pickWallType(tags);
    const climbingType = tags["climbing:indoor"] === "yes"
      ? "indoor"
      : tags["climbing:bouldering"] === "yes"
        ? "bouldering"
        : tags["sport"] === "climbing"
          ? "sport"
          : "climbing";

    const description =
      tags.description ||
      tags["climbing:description"] ||
      `Imported from OpenStreetMap (${climbingType})`;
    const location = {
      type: "Point",
      coordinates: [lon, lat],
      address: tags.address || tags["addr:full"],
    };
    const wallFilter = { name, "location.coordinates": [lon, lat] };

    if (wallType === "IndoorWall") {
      // 1. Upsert the Facility document
      const facilityResult = await Facility.findOneAndUpdate(
        { name, "location.coordinates": [lon, lat] },
        { $set: { name, description, location } },
        { upsert: true, new: true },
      );

      // 2. Upsert the IndoorWall linked to this Facility
      const wallResult = await Wall.findOneAndUpdate(
        wallFilter,
        { $set: { name, wallType, description, location, difficulty, status: "OPEN", rating: 0, facility: facilityResult._id } },
        { upsert: true, new: true, strict: false },
      );

      // 3. Register the wall in the Facility's walls array (idempotent)
      await Facility.updateOne(
        { _id: facilityResult._id },
        { $addToSet: { walls: wallResult._id } },
      );
    } else {
      const wallResult = await Wall.findOneAndUpdate(
        wallFilter,
        { $set: { name, wallType, description, location, difficulty, status: "OPEN", rating: 0, publicBody: regioneTrentino._id } },
        { upsert: true, new: true, strict: false },
      );
      outdoorWallIds.push(wallResult._id);
    }

    imported += 1;
  }

  // Link all outdoor walls to Regione Trentino (idempotent)
  await PublicBody.findByIdAndUpdate(regioneTrentino._id, {
    $addToSet: { walls: { $each: outdoorWallIds } },
  });

  console.log(`Import completed: ${imported} upserted, ${skipped} skipped`);
  console.log(`Outdoor walls linked to Regione Trentino: ${outdoorWallIds.length}`);
}

main()
  .catch((error) => {
    console.error("Import failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });