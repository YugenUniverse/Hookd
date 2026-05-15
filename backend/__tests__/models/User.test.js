const mongoose = require("mongoose");
const { User, Climber, Facility, PublicBody } = require("../../models/User");

jest.setTimeout(30000);

describe("User model suite", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd",
        });
    });

    afterEach(async () => {
        await User.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    describe("Base User", () => {
        it("hashes the password before saving", async () => {
            const plainPassword = "Celli123!";
            const user = new User({
                email: "celli@example.com",
                username: "celli",
                password: plainPassword,
            });

            await user.save();

            expect(user.password).not.toBe(plainPassword);
            expect(user.password).toMatch(/\$2[ayb]\$.{56}/);
        });

        it("matchPassword returns true for the correct password and false for the wrong password", async () => {
            const plainPassword = "Celli123!";
            const user = new User({
                email: "celli@example.com",
                username: "celli",
                password: plainPassword,
            });

            await user.save();

            const loadedUser = await User.findById(user._id).select(
                "+password",
            );

            expect(await loadedUser.matchPassword(plainPassword)).toBe(true);
            expect(await loadedUser.matchPassword("bad-password")).toBe(false);
        });

        it("matchPassword returns false when the password is not set", async () => {
            const user = new User({
                email: "celli@example.com",
                username: "celli",
            });

            await user.save();

            const loadedUser = await User.findById(user._id).select(
                "+password",
            );

            expect(await loadedUser.matchPassword("anything")).toBe(false);
        });

        it("requires email and username", async () => {
            const user = new User({
                email: "test@example.com",
            });

            await expect(user.save()).rejects.toThrow();
        });

        it("email must be unique", async () => {
            await User.create({
                email: "duplicate@example.com",
                username: "user1",
            });

            const user2 = new User({
                email: "duplicate@example.com",
                username: "user2",
            });

            await expect(user2.save()).rejects.toThrow();
        });

        it("defaults avatar to empty string", async () => {
            const user = new User({
                email: "test@example.com",
                username: "testuser",
            });

            await user.save();

            expect(user.avatar).toBe("");
        });

        it("toJSON transforms _id to id and removes __v", async () => {
            const user = new User({
                email: "test@example.com",
                username: "testuser",
            });

            await user.save();

            const json = user.toJSON();
            expect(String(json.id)).toEqual(user._id.toString());
            expect(json._id).toBeUndefined();
            expect(json.__v).toBeUndefined();
        });
    });

    describe("Climber discriminator", () => {
        it("creates a climber with base user fields plus climber fields", async () => {
            const climber = await Climber.create({
                email: "climber@example.com",
                username: "climber",
                password: "Climb123!",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
                bio: "Passionate climber",
                wallet: 100,
            });

            const found = await User.findById(climber.id);
            expect(found.userType).toBe("Climber");
            expect(found.name).toBe("John");
            expect(found.wallet).toBe(100);
        });

        it("requires name, surname, and birthdate for climber", async () => {
            const climber = new Climber({
                email: "fail@example.com",
                username: "fail",
                // missing name, surname, birthdate
            });
            await expect(climber.save()).rejects.toThrow();
        });
    });

    describe("Facility discriminator", () => {
        it("creates a facility with valid location and description", async () => {
            const facility = await Facility.create({
                email: "gym@example.com",
                username: "vertical_limit",
                name: "Vertical Limit Gym",
                description: "Best indoor climbing in town",
                location: {
                    coordinates: [12.4964, 41.9028], // [Lng, Lat]
                    address: "123 Climbing St, Rome",
                },
            });

            expect(facility.userType).toBe("Facility");
            expect(facility.location.type).toBe("Point");
            expect(facility.location.coordinates).toContain(12.4964);
        });

        it("fails if description exceeds 1000 characters", async () => {
            const facility = new Facility({
                email: "gym2@example.com",
                username: "long_desc",
                name: "The Gym",
                description: "a".repeat(1001),
                location: { coordinates: [0, 0] },
            });
            await expect(facility.save()).rejects.toThrow(
                /Description cannot be more than 1000 characters/,
            );
        });

        it("requires coordinates in location", async () => {
            const facility = new Facility({
                email: "gym3@example.com",
                username: "no_loc",
                name: "No Loc Gym",
                location: { address: "Somewhere" }, // missing coordinates
            });
            await expect(facility.save()).rejects.toThrow();
        });
    });

    describe("PublicBody discriminator", () => {
        it("creates a public body correctly", async () => {
            const cityHall = await PublicBody.create({
                email: "admin@city.gov",
                username: "city_admin",
                name: "Department of Parks",
                location: {
                    coordinates: [45.4642, 9.19],
                },
            });

            expect(cityHall.userType).toBe("PublicBody");
            expect(cityHall.name).toBe("Department of Parks");
        });

        it("validates outdoor walls reference array", async () => {
            const pb = new PublicBody({
                email: "pb@example.com",
                username: "pb_user",
                name: "Park Authority",
                location: { coordinates: [0, 0] },
                walls: [new mongoose.Types.ObjectId()],
            });
            await pb.save();
            expect(pb.walls.length).toBe(1);
        });
    });

    describe("Cross-Type Logic", () => {
        it("prevents two different users from having the same email regardless of type", async () => {
            await Climber.create({
                email: "shared@test.com",
                username: "climber1",
                name: "Climber",
                surname: "One",
                birthdate: new Date(),
            });

            const gym = new Facility({
                email: "shared@test.com",
                username: "gym1",
                name: "Gym One",
                location: { coordinates: [0, 0] },
            });

            await expect(gym.save()).rejects.toThrow();
        });
    });
});
