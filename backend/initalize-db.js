require("dotenv").config();

const axios = require("axios");
const mongoose = require("mongoose");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const { faker } = require("@faker-js/faker");

const { Wall, IndoorWall, OutdoorWall } = require("./models/Wall");
const FacilityModel = require("./models/Facility");
const { FacilityOwner, PublicBody, Climber, Admin } = require("./models/User");
const Badge = require("./models/Badge");
const ClimbingSession = require("./models/ClimbingSession");
const { Issue } = require("./models/Issue");

const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

const stopPhaseIdx = process.argv.indexOf("--stop-at");
const stopPhase = stopPhaseIdx !== -1 ? process.argv[stopPhaseIdx + 1] : null;

// ==========================================
// --- SEED QUANTITIES & PROBABILITIES ---
// ==========================================
const NUM_CLIMBERS = 100; // Total climbers to register
const MIN_SESSIONS_PER_CLIMBER = 15; // Minimum sessions logged per climber
const MAX_SESSIONS_PER_CLIMBER = 25; // Maximum sessions logged per climber
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
    // ~25% stay UNKNOWN, rest get a random difficulty
    if (Math.random() < 0.25) return "UNKNOWN";
    const difficulties = ["BEGINNER", "INTERMEDIATE", "ADVANCED", "EXPERT"];
    return difficulties[Math.floor(Math.random() * difficulties.length)];
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

    const seedPasswordPlain = "password123";
    const seedPasswordHash = await bcrypt.hash(seedPasswordPlain, 10);

    const regioneTrentino = await PublicBody.findOneAndUpdate(
        { username: "regione_trentino" },
        {
            $set: {
                name: "Regione Trentino",
                description:
                    "Autonomous Province of Trento — manages outdoor climbing areas in the Trentino region.",
                location: { type: "Point", coordinates: [11.1217, 46.0667] },
                email: "regione.trentino@hookd.internal",
                password: seedPasswordHash,
                authMethods: ["local"],
                approvalStatus: "approved",
            },
            $setOnInsert: {
                username: "regione_trentino",
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
            const facilityFilter = { name, "location.coordinates": [lon, lat] };
            const isUnclaimed = Math.random() < 0.1; // 10% are unclaimed

            let ownerId = undefined;

            if (!isUnclaimed) {
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
                        $set: {
                            name,
                            description,
                            location,
                            email: facilityEmail,
                            password: seedPasswordHash,
                            authMethods: ["local"],
                            approvalStatus: "approved",
                        },
                        $setOnInsert: { username: facilityUsername },
                    },
                    { upsert: true, returnDocument: "after" },
                );
                ownerId = userResult._id;
            }

            const updatePayload = { $set: { name, description, location } };
            if (ownerId) {
                updatePayload.$set.ownerAccount = ownerId;
            } else {
                updatePayload.$unset = { ownerAccount: "" };
            }

            const facilityResult = await FacilityModel.findOneAndUpdate(
                facilityFilter,
                updatePayload,
                { upsert: true, returnDocument: "after" },
            );

            if (ownerId) {
                await FacilityOwner.findByIdAndUpdate(ownerId, {
                    facility: facilityResult._id,
                });
            }

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
// PHASE 2: ADMIN & PENDING ACCOUNTS SEED
// ==========================================

async function seedAdminAndPending() {
    console.log("\n--- 🛡️ STARTING PHASE 2: ADMIN & PENDING ACCOUNTS ---");
    const seedPasswordPlain = "password123";
    const seedPasswordHash = await bcrypt.hash(seedPasswordPlain, 10);

    // 1. Create Admin
    const adminEmail = "admin@hookd.internal";
    await Admin.findOneAndUpdate(
        { email: adminEmail },
        {
            $set: {
                name: "System Admin",
                password: seedPasswordHash,
                authMethods: ["local"],
            },
            $setOnInsert: {
                username: "hookd_admin",
            },
        },
        { upsert: true },
    );
    console.log("✅ Admin account created (admin@hookd.internal)");

    // 2. Create Pending Facility Owners
    for (let i = 1; i <= 3; i++) {
        await FacilityOwner.findOneAndUpdate(
            { email: `pending_owner${i}@hookd.test` },
            {
                $set: {
                    name: `Pending Facility ${i}`,
                    approvalStatus: "pending",
                    password: seedPasswordHash,
                    authMethods: ["local"],
                },
                $setOnInsert: {
                    username: `pending_owner${i}`,
                },
            },
            { upsert: true },
        );
    }
    console.log("✅ Pending FacilityOwner accounts created");

    // 3. Create Pending Public Bodies
    for (let i = 1; i <= 2; i++) {
        await PublicBody.findOneAndUpdate(
            { email: `pending_pb${i}@hookd.test` },
            {
                $set: {
                    name: `Pending Public Body ${i}`,
                    approvalStatus: "pending",
                    password: seedPasswordHash,
                    authMethods: ["local"],
                },
                $setOnInsert: {
                    username: `pending_pb${i}`,
                },
            },
            { upsert: true },
        );
    }
    console.log("✅ Pending PublicBody accounts created");
}

// ==========================================
// PHASE 3: SYSTEM BADGE SEED
// ==========================================

const SYSTEM_BADGES = [
    {
        name: "First Ascent",
        description: "Logged your first climbing session on Hookd.",
        icon: "first_ascent.png",
        score: 10,
        type: "system",
        reEarnable: false,
        level: 4,
    },
    {
        name: "Century Club",
        description:
            "Reached the massive milestone of 100 total climbing sessions.",
        icon: "century_club.png",
        score: 500,
        type: "system",
        reEarnable: false,
        level: 1,
    },
    {
        name: "Weekend Warrior",
        description: "Climbed both Saturday and Sunday in a single weekend.",
        icon: "weekend_warrior.png",
        score: 50,
        type: "system",
        reEarnable: false,
        level: 3,
    },
    {
        name: "Getting Hookd",
        description: "Logged 10 total climbing sessions.",
        icon: "dedicated_10.png",
        score: 50,
        type: "system",
        reEarnable: false,
        level: 4,
    },
    {
        name: "Dedicated Climber",
        description: "Logged 30 total climbing sessions.",
        icon: "dedicated_30.png",
        score: 150,
        type: "system",
        reEarnable: false,
        level: 3,
    },
    {
        name: "Half Century",
        description: "Logged 50 total climbing sessions.",
        icon: "dedicated_50.png",
        score: 250,
        type: "system",
        reEarnable: false,
        level: 2,
    },
    {
        name: "1-Month Streak",
        description:
            "Logged at least 1 session per week for 4 consecutive weeks.",
        icon: "streak_1.png",
        score: 100,
        type: "system",
        reEarnable: false,
        level: 4,
    },
    {
        name: "3-Month Streak",
        description:
            "Logged at least 1 session per week for 12 consecutive weeks.",
        icon: "streak_3.png",
        score: 300,
        type: "system",
        reEarnable: false,
        level: 3,
    },
    {
        name: "6-Month Streak",
        description:
            "Logged at least 1 session per week for 26 consecutive weeks.",
        icon: "streak_6.png",
        score: 600,
        type: "system",
        reEarnable: false,
        level: 2,
    },
    {
        name: "1-Year Streak",
        description:
            "Logged at least 1 session per week for 52 consecutive weeks.",
        icon: "streak_12.png",
        score: 1500,
        type: "system",
        reEarnable: false,
        level: 1,
    },
];

async function seedSystemBadges() {
    console.log("\n--- 🏅 STARTING PHASE 3: BADGE SEED ---");
    for (const b of SYSTEM_BADGES) {
        await Badge.findOneAndUpdate({ name: b.name }, b, {
            upsert: true,
            new: true,
        });
    }
    console.log("✅ System badges seeded successfully!");
}

// ==========================================
// PHASE 4: HIGH-VOLUME DIRECT SEED
// ==========================================

async function seedViaApi() {
    const runId = uuidv4().substring(0, 6);
    console.log(
        `\n--- 🚀 STARTING PHASE 4: DIRECT SEED PROCESS (Run ID: ${runId}) ---`,
    );

    const seedPasswordPlain = "password123";

    // 1. CREATE FACILITY OWNER + FACILITY
    console.log("🏢 Creating Facility...");
    const facilityEmail = `gym_test@test.com`;

    const facilityOwner = await FacilityOwner.create({
        email: facilityEmail,
        username: `test_gym_${runId}`,
        password: seedPasswordPlain,
        name: `API Test Gym ${runId}`,
        location: { type: "Point", coordinates: [11.12, 46.06] },
        authMethods: ["local"],
        approvalStatus: "approved",
    });

    const createdFacility = await FacilityModel.create({
        name: `API Test Gym ${runId}`,
        description: "High-volume seeded data for reporting UI.",
        location: { type: "Point", coordinates: [11.12, 46.06] },
        ownerAccount: facilityOwner._id,
    });
    await FacilityOwner.findByIdAndUpdate(facilityOwner._id, {
        facility: createdFacility._id,
    });
    console.log("✅ Facility profile created");

    if (stopPhase === "walls_and_facilities") {
        console.log("\n🛑 Stopping at phase: walls_and_facilities");
        return;
    }

    // --- ADD CUSTOM EVENTS AND BADGES ---
    console.log("🏆 Seeding Custom Events and Badges...");
    const Event = require("./models/Event");

    let localEvent = await Event.findOne({ title: `API Gym Comp ${runId}` });
    if (!localEvent) {
        localEvent = await Event.create({
            title: `API Gym Comp ${runId}`,
            description: "Compete at the API Gym to be the best!",
            startDate: new Date(),
            endDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            createdBy: facilityOwner._id,
            facility: createdFacility._id,
            isGlobal: false,
            status: "active",
        });
    }
    const localBadgeExists = await Badge.findOne({ eventId: localEvent._id });
    if (!localBadgeExists) {
        await Badge.create({
            name: "API Gym Champion",
            description: "Top 3 at API Gym Comp",
            icon: "medal",
            type: "event",
            eventId: localEvent._id,
            winningCondition: { metric: "rank", operator: "top", value: 3 },
            createdBy: facilityOwner._id,
        });
    }

    const regioneTrentino = await PublicBody.findOne({ username: "regione_trentino" });
    if (regioneTrentino) {
        let pbEvent = await Event.findOne({ title: "Global Summer Ascent Challenge" });
        if (!pbEvent) {
            pbEvent = await Event.create({
                title: "Global Summer Ascent Challenge",
                description:
                    "Climb anywhere in the world and accumulate points this week! Earn Bronze, Silver, and Gold tier badges.",
                startDate: new Date(),
                endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
                createdBy: regioneTrentino._id,
                facility: null,
                isGlobal: true,
                status: "active",
            });
        }
        const pbBadgeExists = await Badge.findOne({ eventId: pbEvent._id });
        if (!pbBadgeExists) {
            await Badge.insertMany([
                {
                    name: "Summer Ascender (Bronze)",
                    description:
                        "Earned by reaching 1000 points during the Global Summer Ascent Challenge",
                    icon: "medal",
                    type: "event",
                    level: 3,
                    eventId: pbEvent._id,
                    winningCondition: { metric: "score", operator: "gte", value: 1000 },
                    createdBy: regioneTrentino._id,
                },
                {
                    name: "Summer Ascender (Silver)",
                    description:
                        "Earned by reaching 2500 points during the Global Summer Ascent Challenge",
                    icon: "medal",
                    type: "event",
                    level: 2,
                    eventId: pbEvent._id,
                    winningCondition: { metric: "score", operator: "gte", value: 2500 },
                    createdBy: regioneTrentino._id,
                },
                {
                    name: "Summer Ascender (Gold)",
                    description:
                        "Earned by reaching 5000 points during the Global Summer Ascent Challenge",
                    icon: "trophy",
                    type: "event",
                    level: 1,
                    eventId: pbEvent._id,
                    winningCondition: { metric: "score", operator: "gte", value: 5000 },
                    createdBy: regioneTrentino._id,
                },
            ]);
        }
    }
    console.log("✅ Seeded Custom Events and Badges.");

    if (stopPhase === "badges_and_events") {
        console.log("\n🛑 Stopping at phase: badges_and_events");
        return;
    }

    // 2. CREATE A WALL
    console.log("🧱 Creating Wall...");
    const wall = await IndoorWall.create({
        name: `The API Gamified Wall (${runId})`,
        description: "High-volume seeded data for reporting UI.",
        difficulty: "INTERMEDIATE",
        location: { type: "Point", coordinates: [11.12, 46.06] },
        facility: createdFacility._id,
        status: "OPEN",
        rating: 0,
    });
    await FacilityModel.findByIdAndUpdate(createdFacility._id, {
        $push: { walls: wall._id },
    });
    const wallId = wall._id;
    console.log(`✅ Wall Created (ID: ${wallId})`);

    // 3. CREATE CLIMBERS
    console.log(`🧗 Creating ${NUM_CLIMBERS} Climbers...`);
    const climberIds = [];
    for (let i = 0; i < NUM_CLIMBERS; i++) {
        const climber = await Climber.create({
            email: `climber_${i}_${runId}@test.com`,
            username: faker.internet.username() + runId,
            password: seedPasswordPlain,
            name: faker.person.firstName(),
            surname: faker.person.lastName(),
            birthdate: faker.date.birthdate({ min: 16, max: 50, mode: "age" }),
            authMethods: ["local"],
        });
        climberIds.push(climber._id);
    }
    console.log(`✅ Created ${climberIds.length} climbers.`);

    // 4. LOG SESSIONS & LEAVE REVIEWS
    console.log(
        "📝 Logging climbing sessions and reviews (This will take a moment)...",
    );
    let totalSessions = 0;
    let totalReviews = 0;
    const now = new Date();

    for (const climberId of climberIds) {
        const numSessions = faker.number.int({
            min: MIN_SESSIONS_PER_CLIMBER,
            max: MAX_SESSIONS_PER_CLIMBER,
        });

        for (let j = 0; j < numSessions; j++) {
            const daysAgo =
                Math.random() > 0.15
                    ? faker.number.int({ min: 0, max: 29 })
                    : faker.number.int({ min: 30, max: 90 });
            const baseDate = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
            const isWeekend = baseDate.getDay() === 0 || baseDate.getDay() === 6;

            const randomHour = isWeekend
                ? weightedRandom(
                      [9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
                      [5, 15, 20, 15, 15, 10, 5, 5, 5, 5],
                  )
                : weightedRandom(
                      [12, 13, 16, 17, 18, 19, 20, 21, 22],
                      [5, 5, 10, 20, 25, 20, 10, 3, 2],
                  );

            baseDate.setHours(randomHour, faker.number.int({ min: 0, max: 59 }), 0, 0);
            const timeTaken = weightedRandom(
                [
                    faker.number.int({ min: 15, max: 25 }),
                    faker.number.int({ min: 45, max: 90 }),
                    faker.number.int({ min: 90, max: 120 }),
                ],
                [10, 80, 10],
            );

            const session = await ClimbingSession.create({
                climber_id: climberId,
                wall_id: wallId,
                date: baseDate,
                time: timeTaken,
                isSend: Math.random() < SEND_PROBABILITY,
            });

            await Promise.all([
                Wall.findByIdAndUpdate(wallId, { $push: { sessions: session._id } }),
                Climber.findByIdAndUpdate(climberId, { $push: { sessions: session._id } }),
            ]);

            totalSessions++;

            if (Math.random() < REVIEW_PROBABILITY && stopPhase !== "climbers_and_sessions") {
                const rating =
                    timeTaken > 90
                        ? weightedRandom([1, 2, 3, 4, 5], [15, 20, 25, 25, 15])
                        : weightedRandom([1, 2, 3, 4, 5], [2, 5, 15, 45, 33]);
                const feedbackText =
                    rating <= 3
                        ? faker.helpers.arrayElement(CLIMBING_FEEDBACK.slice(7))
                        : faker.helpers.arrayElement(CLIMBING_FEEDBACK.slice(0, 7));

                await session.addReview(rating, feedbackText);
                totalReviews++;
            }
        }
    }
    console.log(`✅ Logged ${totalSessions} sessions and ${totalReviews} reviews.`);

    // 5. LOG ISSUES
    console.log("🚩 Generating Wall Issues...");
    let totalIssues = 0;

    if (stopPhase !== "climbers_and_sessions") {
        for (let k = 0; k < NUM_ISSUES; k++) {
            const randomClimberId = faker.helpers.arrayElement(climberIds);
            const randomIssue = faker.helpers.arrayElement(CLIMBING_ISSUES);
            const formattedBody = `${randomIssue.title}: ${randomIssue.description}`;
            try {
                await Issue.create({
                    climber_id: randomClimberId,
                    wall_id: wallId,
                    body: formattedBody,
                });
                totalIssues++;
            } catch (err) {
                console.warn(`⚠️ Failed to create issue. Error: ${err.message}`);
            }
        }
        console.log(`✅ Logged ${totalIssues} wall issues.`);

        const publicBodyTrentino = await PublicBody.findOne({ username: "regione_trentino" });

        if (!publicBodyTrentino) {
            console.warn(
                "⚠️ PublicBody 'regione_trentino' not found. Skipping public-body seeded activity.",
            );
        } else {
            const publicBodyWalls = await OutdoorWall.find({
                publicBody: publicBodyTrentino._id,
            })
                .sort({ name: 1, createdAt: 1 })
                .lean();

            if (!publicBodyWalls.length) {
                console.warn(
                    "⚠️ No OutdoorWall documents linked to Regione Trentino. Skipping public-body seeded activity.",
                );
            } else {
                const selectedWallCount = Math.min(25, Math.ceil(publicBodyWalls.length / 3));
                const targetWalls = publicBodyWalls.slice(0, selectedWallCount);

                console.log(
                    `🌍 Seeding activity across ${targetWalls.length}/${publicBodyWalls.length} Regione Trentino walls (>= 1/3).`,
                );

                let regionSessions = 0;
                let regionReviews = 0;
                let regionIssues = 0;

                for (const outdoorWall of targetWalls) {
                    const outdoorWallId = outdoorWall._id;

                    const selectedClimbers = faker.helpers.arrayElements(
                        climberIds,
                        faker.number.int({ min: 3, max: 6 }),
                    );

                    for (const climberId of selectedClimbers) {
                        const numSessions = faker.number.int({ min: 1, max: 3 });

                        for (let sessionIndex = 0; sessionIndex < numSessions; sessionIndex++) {
                            const daysAgo =
                                Math.random() > 0.15
                                    ? faker.number.int({ min: 0, max: 29 })
                                    : faker.number.int({ min: 30, max: 90 });
                            const baseDate = new Date(
                                new Date().getTime() - daysAgo * 24 * 60 * 60 * 1000,
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

                            const session = await ClimbingSession.create({
                                climber_id: climberId,
                                wall_id: outdoorWallId,
                                date: baseDate,
                                time: timeTaken,
                                isSend: Math.random() < SEND_PROBABILITY,
                            });

                            await Promise.all([
                                Wall.findByIdAndUpdate(outdoorWallId, {
                                    $push: { sessions: session._id },
                                }),
                                Climber.findByIdAndUpdate(climberId, {
                                    $push: { sessions: session._id },
                                }),
                            ]);

                            regionSessions++;

                            if (Math.random() < REVIEW_PROBABILITY) {
                                const rating =
                                    timeTaken > 90
                                        ? weightedRandom([1, 2, 3, 4, 5], [15, 20, 25, 25, 15])
                                        : weightedRandom([1, 2, 3, 4, 5], [2, 5, 15, 45, 33]);
                                const feedbackText =
                                    rating <= 3
                                        ? faker.helpers.arrayElement(CLIMBING_FEEDBACK.slice(7))
                                        : faker.helpers.arrayElement(CLIMBING_FEEDBACK.slice(0, 7));

                                await session.addReview(rating, feedbackText);
                                regionReviews++;
                            }
                        }
                    }
                }

                if (stopPhase !== "climbers_and_sessions") {
                    for (let k = 0; k < NUM_ISSUES; k++) {
                        const randomWall =
                            targetWalls[Math.floor(Math.random() * targetWalls.length)];
                        const issueWallId = randomWall._id;
                        const randomClimberId = faker.helpers.arrayElement(climberIds);
                        const randomIssue = faker.helpers.arrayElement(CLIMBING_ISSUES);

                        try {
                            const formattedBody = `${randomIssue.title}: ${randomIssue.description}`;
                            await Issue.create({
                                climber_id: randomClimberId,
                                wall_id: issueWallId,
                                body: formattedBody,
                            });
                            regionIssues++;
                        } catch (err) {
                            console.warn(
                                `⚠️ Failed to create Regione Trentino issue. Error: ${err.message}`,
                            );
                        }
                    }
                }

                console.log(
                    `✅ Logged ${regionSessions} Regione Trentino sessions, ${regionReviews} reviews, and ${regionIssues} issues across ${targetWalls.length} walls.`,
                );
                if (stopPhase === "climbers_and_sessions") {
                    console.log("\n🛑 Stopping at phase: climbers_and_sessions");
                    return;
                }
                if (stopPhase === "reviews_and_issues") {
                    console.log("\n🛑 Stopping at phase: reviews_and_issues");
                    return;
                }
            }
        }
    }
}

async function runAll() {
    try {
        await mongoose.connect(
            process.env.MONGO_URI || "mongodb://localhost:27017/hookd",
        );

        console.log("\n--- 🧹 DROPPING DATABASE ---");
        await mongoose.connection.dropDatabase();
        console.log("✅ Database dropped");

        console.log("\n--- PHASE 1: walls_and_facilities ---");
        await seedOverpass();

        console.log("\n--- PHASE 2: admin_and_pending ---");
        await seedAdminAndPending();

        console.log("\n--- PHASE 3: badges_and_events ---");
        await seedSystemBadges();

        console.log("\n--- PHASE 4: high_volume_api ---");
        await seedViaApi();

        // Reports Phase
        if (stopPhase !== "reviews_and_issues") {
            console.log("\n--- PHASE 5: reports ---");
            await seedReports();
            if (stopPhase === "reports") {
                console.log("\n🛑 Stopping at phase: reports");
                return;
            }
        }

        // Flagged content Phase
        if (
            ![
                "reviews_and_issues",
                "climbers_and_sessions",
                "badges_and_events",
                "walls_and_facilities",
            ].includes(stopPhase)
        ) {
            console.log("\n--- PHASE 6: flagged_content ---");
            await seedFlaggedContent();
            if (stopPhase === "flagged_content") {
                console.log("\n🛑 Stopping at phase: flagged_content");
                return;
            }
        }

        // Groups Phase
        if (
            ![
                "reviews_and_issues",
                "climbers_and_sessions",
                "badges_and_events",
                "walls_and_facilities",
                "flagged_content",
            ].includes(stopPhase)
        ) {
            await seedGroupsAndEvents();
        }

        console.log("\n🎉 ALL SEEDING COMPLETE! Check your Flutter App! 🎉\n");
    } catch (err) {
        console.error("\n💥 Master Script Failed:", err);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}

// ==========================================
// PHASE 6: FLAGGED CONTENT SEED
// ==========================================

const FLAGGED_BODIES = [
    "This place is a complete scam!!! Staff are absolute ###, never coming back!!!",
    "BUY CHEAP CLIMBING GEAR AT DISCOUNTCLIMB.COM — best deals online, click now!!!",
    "The setter clearly has NO idea what they're doing. Absolute garbage route, embarrassing.",
    "WARNING: this gym has bedbugs. I got sick last time and they refused to refund me.",
    "Totally fake reviews here. This wall SUCKS and the management are crooks.",
    "SPAM SPAM SPAM — visit my profile for free climbing tips!!!",
    "I hope this place burns down. Worst experience of my life.",
    "The staff are racists. Do NOT go here. Spreading the word everywhere.",
];

const FLAG_REASONS = [
    "Offensive language",
    "Spam",
    "Offensive language",
    "Misleading",
    "Misleading",
    "Spam",
    "Offensive language",
    "Offensive language",
];

async function seedFlaggedContent() {
    console.log("\n--- 🚩 STARTING PHASE 6: FLAGGED CONTENT SEED ---");

    const Review = require("./models/Review");

    // Drop existing flagged reviews so re-runs stay clean
    await Review.updateMany(
        { flagged: true },
        { flagged: false, flagReason: "", status: "active" },
    );

    const reviews = await Review.find({ status: { $ne: "removed" } })
        .limit(50)
        .lean();

    if (!reviews.length) {
        console.warn("⚠️ No reviews found — run Phase 4 first.");
        return;
    }

    const count = Math.min(FLAGGED_BODIES.length, reviews.length);
    const toFlag = reviews.slice(0, count);

    for (let i = 0; i < toFlag.length; i++) {
        await Review.findByIdAndUpdate(toFlag[i]._id, {
            body: FLAGGED_BODIES[i],
            flagged: true,
            flagReason: FLAG_REASONS[i],
            status: "active",
        });
    }

    console.log(`✅ Flagged ${count} reviews with inappropriate content.`);
}

async function seedReports() {
    console.log("📊 Seeding Reports using live API logic...");
    const reportService = require("./services/report.service");
    const { FacilityOwner, PublicBody } = require("./models/User");
    const { Wall, OutdoorWall } = require("./models/Wall");

    try {
        // Generate reports for Facility Owners
        const facilities = await FacilityOwner.find();
        for (const f of facilities) {
            const wall = await Wall.findOne({ facility: f.facility });
            if (wall) {
                await reportService.saveReport(
                    f._id,
                    wall._id.toString(),
                    "Monthly Gym Analytics",
                    "Traffic has increased by 15% this month.",
                );
            }
        }

        // Generate reports for Public Bodies
        const pbs = await PublicBody.find();
        for (const pb of pbs) {
            const pbWalls = await OutdoorWall.find({
                publicBody: pb._id,
            }).limit(5);
            if (pbWalls.length >= 2) {
                const wallIds = pbWalls.map((w) => w._id.toString());
                await reportService.saveGroupReport(
                    pb._id,
                    wallIds,
                    "Regional Outdoor Crag Usage",
                    "Significant traffic observed at Arco.",
                );
            } else if (pbWalls.length === 1) {
                await reportService.saveReport(
                    pb._id,
                    pbWalls[0]._id.toString(),
                    "Regional Outdoor Crag Usage",
                    "Significant traffic observed at Arco.",
                );
            }
        }
        console.log(
            "✅ Reports created successfully using live DB data via reportService!",
        );
    } catch (e) {
        console.error("⚠️ Could not create reports:", e);
    }
}

async function seedGroupsAndEvents() {
    console.log("\n--- 🧗 STARTING PHASE 7: GROUPS AND EVENTS SEED ---");
    const Group = require("./models/Group");
    const Event = require("./models/Event");
    const { Climber } = require("./models/User");

    await Group.deleteMany({});
    await Event.deleteMany({ groupId: { $exists: true } });

    const climbers = await Climber.find().limit(20);
    if (climbers.length < 5) {
        console.warn("⚠️ Not enough climbers to create groups.");
        return;
    }

    const creator = climbers[0];

    // Create 3 groups
    const groupsData = [
        {
            name: "Weekend Crushers",
            description: "A group for weekend warriors.",
            visibility: "public",
        },
        {
            name: "Boulder Bros",
            description: "V4 and up only.",
            visibility: "private",
        },
        {
            name: "Morning Senders",
            description: "Early bird climbers.",
            visibility: "public",
        },
    ];

    const createdGroups = [];
    for (const gd of groupsData) {
        const group = new Group({
            ...gd,
            creator: creator._id,
            members: climbers.slice(0, 5).map((c) => ({
                user: c._id,
                role: c._id.equals(creator._id) ? "admin" : "member",
            })),
        });
        await group.save();
        createdGroups.push(group);
    }

    console.log(`✅ Seeded ${createdGroups.length} groups.`);

    // Create events for the groups
    for (const group of createdGroups) {
        const event = new Event({
            title: `${group.name} Meetup`,
            description: "Let's climb together!",
            groupId: group._id,
            createdBy: creator._id,
            startDate: new Date(),
            endDate: new Date(Date.now() + 86400000),
        });
        await event.save();
    }

    console.log(`✅ Seeded ${createdGroups.length} group events.`);
}

runAll();
