require("dotenv").config();

const axios = require("axios");
const mongoose = require("mongoose");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const { faker } = require("@faker-js/faker");

const { Wall, IndoorWall, OutdoorWall } = require("./models/Wall");
const FacilityModel = require("./models/Facility");
const { FacilityOwner, PublicBody, Climber } = require("./models/User");
const Badge = require("./models/Badge");

const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

// ==========================================
// --- SEED QUANTITIES & PROBABILITIES ---
// ==========================================
const NUM_CLIMBERS = 50; // Total climbers to register
const MIN_SESSIONS_PER_CLIMBER = 3; // Minimum sessions logged per climber
const MAX_SESSIONS_PER_CLIMBER = 12; // Maximum sessions logged per climber
const SEND_PROBABILITY = 0.25; // 25% chance a session is a "send" (success)
const REVIEW_PROBABILITY = 0.4; // 40% chance a climber leaves a review after a session
const NUM_ISSUES = 10; // Total number of wall issues reported by random climbers
// ==========================================

const CLIMBING_FEEDBACK = [
    "The crux was super reachy, but loved the crimps.",
    "Flows really well, great setting.",
    "Best route set this week!",
    "Absolute classic, ran laps on this today.",
    "Tough start but the top-out is extremely rewarding.",
    "Perfectly graded. Really enjoyed the dynamic move.",
    "Such a fun sequence on the volume!",
    "Blue hold at the top is spinning a bit!",
    "Felt a bit sandbagged for an intermediate route.",
    "Slipped on the volume, need to brush it.",
    "Wish the foot placements were a bit more obvious.",
    "A bit too morpho—if you're short, the span is impossible.",
    "Tape is peeling off the start hold.",
];

const CLIMBING_ISSUES = [
    {
        title: "Spinning Hold",
        description:
            "The blue jug near the 3rd quickdraw is spinning dangerously.",
    },
    {
        title: "Missing Tape",
        description:
            "The starting handhold lost its tape, hard to tell where to start.",
    },
    {
        title: "Worn out carabiner",
        description:
            "The gate on the anchor carabiner is super sticky and hard to clip.",
    },
    {
        title: "Loose Volume",
        description: "The large triangle volume shifts when you step on it.",
    },
    {
        title: "Blood on hold",
        description: "Someone flappers on the crimp halfway up, needs a scrub.",
    },
];

const weightedRandom = (items, weights) => {
    let sum = weights.reduce((a, b) => a + b, 0);
    let rand = Math.random() * sum;
    for (let i = 0; i < items.length; i++) {
        if (rand < weights[i]) return items[i];
        rand -= weights[i];
    }
    return items[0];
};

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
    if (
        tags?.["climbing:boulder"] === "yes" ||
        tags?.["climbing:bouldering"] === "yes"
    )
        return "BEGINNER";
    if (
        tags?.["climbing:trad"] === "yes" ||
        tags?.["climbing:multipitch"] === "yes"
    )
        return "ADVANCED";
    if (
        tags?.["climbing:indoor"] === "yes" ||
        tags?.["leisure"] === "sports_centre"
    )
        return "INTERMEDIATE";
    return "UNKNOWN";
};

const pickWallType = (tags) => {
    if (
        tags?.["climbing:indoor"] === "yes" ||
        tags?.["indoor"] === "yes" ||
        tags?.["indoor"] === "only" ||
        tags?.["outdoor"] === "no" ||
        tags?.["leisure"] === "sports_centre" ||
        (tags?.["building"] && tags?.["building"] !== "no")
    ) {
        return "IndoorWall";
    }
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
                    "Content-Type":
                        "application/x-www-form-urlencoded; charset=UTF-8",
                    Accept: "application/json",
                    "User-Agent": "HookdImporter/1.0",
                },
                timeout: 120000,
            });
            return response.data;
        } catch (error) {
            lastError = error;
            const status = error.response?.status;
            console.warn(`Overpass endpoint failed: ${endpoint}`);
            if (status && ![406, 408, 429, 500, 502, 503, 504].includes(status))
                throw error;
        }
    }
    throw lastError || new Error("All Overpass endpoints failed");
}

async function seedOverpass() {
    console.log("\n--- 🌍 STARTING PHASE 1: OVERPASS IMPORT ---");

    const seedPasswordPlain =
        process.env.SEED_PUBLICBODY_PASSWORD || "hookd_test_password";
    const seedPasswordHash = await bcrypt.hash(seedPasswordPlain, 10);

    const regioneTrentino = await PublicBody.findOneAndUpdate(
        { username: "regione_trentino" },
        {
            $set: {
                name: "Regione Trentino",
                description:
                    "Autonomous Province of Trento — manages outdoor climbing areas in the Trentino region.",
                location: { type: "Point", coordinates: [11.1217, 46.0667] },
            },
            $setOnInsert: {
                email: "regione.trentino@hookd.internal",
                username: "regione_trentino",
                password: seedPasswordHash,
                authMethods: ["local"],
            },
        },
        { upsert: true, returnDocument: "after" },
    );
    console.log(
        `PublicBody "Regione Trentino" ready (id: ${regioneTrentino._id})`,
    );

    const responseData = await runOverpassQuery();
    const elements = responseData?.elements || [];
    let imported = 0,
        skipped = 0;
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
        const climbingType =
            tags["climbing:indoor"] === "yes"
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
            const facilitySlug = name
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, "_")
                .replace(/^_+|_+$/g, "")
                .slice(0, 30);
            const facilityUsername = `${facilitySlug || "facility"}_${Math.round(lat * 10000)}_${Math.round(lon * 10000)}`;
            const facilityEmail = `${facilityUsername}@hookd.internal`;

            const userResult = await FacilityOwner.findOneAndUpdate(
                { username: facilityUsername },
                {
                    $set: { name, description, location },
                    $setOnInsert: {
                        email: facilityEmail,
                        username: facilityUsername,
                        password: seedPasswordHash,
                        authMethods: ["local"],
                    },
                },
                { upsert: true, returnDocument: "after" },
            );

            const facilityResult = await FacilityModel.findOneAndUpdate(
                { ownerAccount: userResult._id },
                {
                    $set: { name, description, location },
                    $setOnInsert: { ownerAccount: userResult._id },
                },
                { upsert: true, returnDocument: "after" },
            );

            await FacilityOwner.findByIdAndUpdate(userResult._id, {
                facility: facilityResult._id,
            });

            const wallResult = await IndoorWall.findOneAndUpdate(
                wallFilter,
                {
                    $set: {
                        name,
                        description,
                        location,
                        difficulty,
                        status: "OPEN",
                        rating: 0,
                        facility: facilityResult._id,
                    },
                },
                { upsert: true, returnDocument: "after", strict: false },
            );

            await FacilityModel.updateOne(
                { _id: facilityResult._id },
                { $addToSet: { walls: wallResult._id } },
            );
        } else {
            const wallResult = await OutdoorWall.findOneAndUpdate(
                wallFilter,
                {
                    $set: {
                        name,
                        description,
                        location,
                        difficulty,
                        status: "OPEN",
                        rating: 0,
                        publicBody: regioneTrentino._id,
                    },
                },
                { upsert: true, returnDocument: "after", strict: false },
            );
            outdoorWallIds.push(wallResult._id);
        }
        imported += 1;
    }

    await PublicBody.findByIdAndUpdate(regioneTrentino._id, {
        $addToSet: { walls: { $each: outdoorWallIds } },
    });
    console.log(
        `✅ Import completed: ${imported} upserted, ${skipped} skipped`,
    );
}

// ==========================================
// PHASE 2: SYSTEM BADGE SEED
// ==========================================

const SYSTEM_BADGES = [
    {
        name: "First Ascent",
        description: "Logged your first climbing session on Hookd.",
        icon: "first_ascent.png",
        score: 10,
        type: "system",
        reEarnable: false
    },
    {
        name: "Century Club",
        description: "Reached the massive milestone of 100 total climbing sessions.",
        icon: "century_club.png",
        score: 500,
        type: "system",
        reEarnable: false
    },
    {
        name: "Weekend Warrior",
        description: "Climbed both Saturday and Sunday in a single weekend.",
        icon: "weekend_warrior.png",
        score: 50,
        type: "system",
        reEarnable: false
    }
];

async function seedSystemBadges() {
    console.log("\n--- 🏅 STARTING PHASE 2: BADGE SEED ---");
    for (const b of SYSTEM_BADGES) {
        await Badge.findOneAndUpdate({ name: b.name }, b, { upsert: true, new: true });
    }
    console.log("✅ System badges seeded successfully!");
}

// ==========================================
// PHASE 3: HIGH-VOLUME API SEED
// ==========================================

async function seedViaApi() {
    const runId = uuidv4().substring(0, 6);
    console.log(
        `\n--- 🚀 STARTING PHASE 2: API SEED PROCESS (Run ID: ${runId}) ---`,
    );
    console.log(`Testing against server at: ${BASE_URL}`);

    try {
        // 1. REGISTER & LOGIN FACILITY
        console.log("🏢 Registering Facility...");
        const facilityEmail = `gym_${runId}@test.com`;
        const facilityPw = "password123";

        const facilityRegRes = await axios.post(`${BASE_URL}/auth/register`, {
            email: facilityEmail,
            username: `test_gym_${runId}`,
            password: facilityPw,
            userType: "FacilityOwner",
            name: `API Test Gym ${runId}`,
            location: { type: "Point", coordinates: [11.12, 46.06] },
        });

        const facilityUserId =
            facilityRegRes.data.user?.id || facilityRegRes.data.user?._id;

        const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
            email: facilityEmail,
            password: facilityPw,
        });
        const facilityToken = loginRes.data.accessToken;
        const facilityHeaders = { Authorization: `Bearer ${facilityToken}` };

        const createdFacility = await FacilityModel.create({
            name: `API Test Gym ${runId}`,
            description: "High-volume seeded data for reporting UI.",
            location: { type: "Point", coordinates: [11.12, 46.06] },
            ownerAccount: facilityUserId,
        });
        await FacilityOwner.findByIdAndUpdate(facilityUserId, {
            facility: createdFacility._id,
        });
        console.log("✅ Facility profile created");

        // 2. CREATE A WALL
        console.log("🧱 Creating Wall...");
        const wallRes = await axios.post(
            `${BASE_URL}/walls`,
            {
                name: `The API Gamified Wall (${runId})`,
                description: "High-volume seeded data for reporting UI.",
                difficulty: "INTERMEDIATE",
                location: { type: "Point", coordinates: [11.12, 46.06] },
            },
            { headers: facilityHeaders },
        );

        const wallId = wallRes.data.wall?.id || wallRes.data.wall?._id;
        console.log(`✅ Wall Created (ID: ${wallId})`);

        // 3. REGISTER & LOGIN CLIMBERS
        console.log(`🧗 Registering ${NUM_CLIMBERS} Climbers...`);
        const climberTokens = [];

        for (let i = 0; i < NUM_CLIMBERS; i++) {
            const email = `climber_${i}_${runId}@test.com`;
            const birthdate = faker.date
                .birthdate({ min: 16, max: 50, mode: "age" })
                .toISOString()
                .split("T")[0];

            await axios.post(`${BASE_URL}/auth/register`, {
                email: email,
                username: faker.internet.username() + runId,
                password: "password123",
                userType: "Climber",
                name: faker.person.firstName(),
                surname: faker.person.lastName(),
                birthdate: birthdate,
            });

            const climberLogin = await axios.post(`${BASE_URL}/auth/login`, {
                email: email,
                password: "password123",
            });
            climberTokens.push(climberLogin.data.accessToken);
        }
        console.log(`✅ Authenticated ${climberTokens.length} climbers.`);

        // 4. LOG SESSIONS & LEAVE REVIEWS
        console.log(
            "📝 Logging climbing sessions and reviews (This will take a moment)...",
        );
        let totalSessions = 0;
        let totalReviews = 0;
        const now = new Date();

        for (const token of climberTokens) {
            const numSessions = faker.number.int({
                min: MIN_SESSIONS_PER_CLIMBER,
                max: MAX_SESSIONS_PER_CLIMBER,
            });
            const climberHeaders = { Authorization: `Bearer ${token}` };

            for (let j = 0; j < numSessions; j++) {
                const daysAgo =
                    Math.random() > 0.15
                        ? faker.number.int({ min: 0, max: 29 })
                        : faker.number.int({ min: 30, max: 90 });
                const baseDate = new Date(
                    now.getTime() - daysAgo * 24 * 60 * 60 * 1000,
                );
                const isWeekend =
                    baseDate.getDay() === 0 || baseDate.getDay() === 6;

                const randomHour = isWeekend
                    ? weightedRandom(
                          [9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
                          [5, 15, 20, 15, 15, 10, 5, 5, 5, 5],
                      )
                    : weightedRandom(
                          [12, 13, 16, 17, 18, 19, 20, 21, 22],
                          [5, 5, 10, 20, 25, 20, 10, 3, 2],
                      );

                baseDate.setHours(
                    randomHour,
                    faker.number.int({ min: 0, max: 59 }),
                    0,
                    0,
                );
                const timeTaken = weightedRandom(
                    [
                        faker.number.int({ min: 15, max: 25 }),
                        faker.number.int({ min: 45, max: 90 }),
                        faker.number.int({ min: 90, max: 120 }),
                    ],
                    [10, 80, 10],
                );

                const sessionRes = await axios.post(
                    `${BASE_URL}/sessions`,
                    {
                        wall_id: wallId,
                        date: baseDate.toISOString(),
                        time: timeTaken,
                        isSend: Math.random() < SEND_PROBABILITY,
                    },
                    { headers: climberHeaders },
                );

                totalSessions++;
                const sessionId =
                    sessionRes.data?.id ||
                    sessionRes.data?._id ||
                    sessionRes.data?.session?.id ||
                    sessionRes.data?.session?._id;

                if (sessionId && Math.random() < REVIEW_PROBABILITY) {
                    const rating =
                        timeTaken > 90
                            ? weightedRandom(
                                  [1, 2, 3, 4, 5],
                                  [15, 20, 25, 25, 15],
                              )
                            : weightedRandom(
                                  [1, 2, 3, 4, 5],
                                  [2, 5, 15, 45, 33],
                              );
                    const feedbackText =
                        rating <= 3
                            ? faker.helpers.arrayElement(
                                  CLIMBING_FEEDBACK.slice(7),
                              )
                            : faker.helpers.arrayElement(
                                  CLIMBING_FEEDBACK.slice(0, 7),
                              );

                    await axios.post(
                        `${BASE_URL}/sessions/${sessionId}/reviews`,
                        { rating: rating, body: feedbackText },
                        { headers: climberHeaders },
                    );
                    totalReviews++;
                }
            }
        }
        console.log(
            `✅ Logged ${totalSessions} sessions and ${totalReviews} reviews.`,
        );

        // 5. LOG ISSUES
        console.log("🚩 Generating Wall Issues...");
        let totalIssues = 0;

        for (let k = 0; k < NUM_ISSUES; k++) {
            const randomClimberToken =
                faker.helpers.arrayElement(climberTokens);
            const randomIssue = faker.helpers.arrayElement(CLIMBING_ISSUES);

            try {
                const formattedBody = `${randomIssue.title}: ${randomIssue.description}`;
                await axios.post(
                    `${BASE_URL}/issues`,
                    {
                        wall_id: wallId,
                        body: formattedBody,
                    },
                    {
                        headers: {
                            Authorization: `Bearer ${randomClimberToken}`,
                        },
                    },
                );
                totalIssues++;
            } catch (err) {
                console.warn(
                    `⚠️ Failed to create issue. Error: ${err.response?.status} - ${JSON.stringify(err.response?.data)}`,
                );
            }
        }
        console.log(`✅ Logged ${totalIssues} wall issues.`);

        // 6. GENERATE AND SAVE REPORTS
        console.log("📊 Generating Saved Reports as the Facility...");
        await axios.post(
            `${BASE_URL}/reports/wall/${wallId}/save`,
            {
                title: `Mid-Season Check-in (${runId})`,
                notes: "Traffic is holding steady. Evening rush is intense!",
            },
            { headers: facilityHeaders },
        );
        console.log("✅ First report snapshot saved!");

        await axios.post(
            `${BASE_URL}/reports/wall/${wallId}/save`,
            {
                title: `Final Wrap-up Report (${runId})`,
                notes: "Route is getting polished, scheduling a reset.",
            },
            { headers: facilityHeaders },
        );
        console.log("✅ Second report snapshot saved!");
    } catch (error) {
        console.error("❌ API Seeding Failed:");
        if (error.response) {
            console.error(`Status: ${error.response.status}`);
            console.error(`Data:`, error.response.data);
        } else if (error.code === "ECONNREFUSED") {
            console.error(`❌ Could not connect to ${BASE_URL}`);
            console.error(
                "Make sure the Express server is running on port 3000",
            );
        } else {
            console.error(error.message);
        }
        throw error;
    }
}

async function runAll() {
    try {
        await mongoose.connect(
            process.env.MONGO_URI || "mongodb://localhost:27017/hookd",
        );

        await seedOverpass();
        await seedSystemBadges();
        await seedViaApi();

        console.log("\n🎉 ALL SEEDING COMPLETE! Check your Flutter App! 🎉\n");
    } catch (err) {
        console.error("\n💥 Master Script Failed:", err);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}

runAll();
