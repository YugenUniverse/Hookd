const mongoose = require("mongoose");
const { User, Climber, FacilityOwner, PublicBody } = require("../../models/User");

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

    describe("FacilityOwner discriminator", () => {
        it("creates a FacilityOwner account with email and username", async () => {
            const owner = await FacilityOwner.create({
                email: "gym@example.com",
                username: "vertical_limit",
            });

            expect(owner.userType).toBe("FacilityOwner");
            expect(owner.email).toBe("gym@example.com");
        });

        it("can store an optional facility reference", async () => {
            const facilityId = new mongoose.Types.ObjectId();
            const owner = await FacilityOwner.create({
                email: "gym2@example.com",
                username: "gym_owner",
                facility: facilityId,
            });

            expect(owner.facility.toString()).toBe(facilityId.toString());
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

            const gymOwner = new FacilityOwner({
                email: "shared@test.com",
                username: "gym1",
            });

            await expect(gymOwner.save()).rejects.toThrow();
        });
    });
});
