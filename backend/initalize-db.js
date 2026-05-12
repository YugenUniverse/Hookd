require("dotenv").config();

const axios = require("axios");
const mongoose = require("mongoose");
const { Wall } = require("./models/Wall");

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
  if (tags?.["climbing:bouldering"] === "yes") return "BEGINNER";
  if (tags?.["climbing:indoor"] === "yes") return "INTERMEDIATE";
  if (tags?.sport === "climbing") return "UNKNOWN";
  return "INTERMEDIATE";
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

  const responseData = await runOverpassQuery();
  const elements = responseData?.elements || [];
  let imported = 0;
  let skipped = 0;

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
    const climbingType = tags["climbing:indoor"] === "yes"
      ? "indoor"
      : tags["climbing:bouldering"] === "yes"
        ? "bouldering"
        : tags["sport"] === "climbing"
          ? "sport"
          : "climbing";

    await Wall.updateOne(
      {
        name,
        "location.coordinates": [lon, lat],
      },
      {
        $set: {
          name,
          description:
            tags.description ||
            tags["climbing:description"] ||
            `Imported from OpenStreetMap (${climbingType})`,
          location: {
            type: "Point",
            coordinates: [lon, lat],
            address: tags.address || tags["addr:full"],
          },
          difficulty,
          status: "OPEN",
          rating: 0,
        },
      },
      {
        upsert: true,
      },
    );

    imported += 1;
  }

  console.log(`Import completed: ${imported} upserted, ${skipped} skipped`);
}

main()
  .catch((error) => {
    console.error("Import failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });