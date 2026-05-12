const mongoose = require("mongoose");
const { User } = require("../../models/User");

jest.setTimeout(30000);

describe("User model", () => {
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
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                password: "Climb123!",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
                bio: "Passionate climber",
                wallet: 100,
            });

            await climber.save();

            const foundClimber = await User.findById(climber._id);
            expect(foundClimber.email).toBe("climber@example.com");
            expect(foundClimber.username).toBe("climber");
            expect(foundClimber.name).toBe("John");
            expect(foundClimber.surname).toBe("Doe");
            expect(foundClimber.birthdate).toEqual(new Date("1990-01-01"));
            expect(foundClimber.bio).toBe("Passionate climber");
            expect(foundClimber.wallet).toBe(100);
            expect(foundClimber.userType).toBe("Climber");
        });

        it("requires name, surname, and birthdate for climber", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                // missing birthdate
            });

            await expect(climber.save()).rejects.toThrow();
        });

        it("defaults bio to empty string for climber", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
            });

            await climber.save();

            expect(climber.bio).toBe("");
        });

        it("defaults wallet to 0 for climber", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
            });

            await climber.save();

            expect(climber.wallet).toBe(0);
        });

        it("bio cannot exceed 200 characters", async () => {
            const longBio = "a".repeat(201);
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
                bio: longBio,
            });

            await expect(climber.save()).rejects.toThrow();
        });

        it("wallet cannot be negative", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
                wallet: -10,
            });

            await expect(climber.save()).rejects.toThrow();
        });

        it("climber has editUser method", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
            });

            await climber.save();

            expect(typeof climber.editUser).toBe("function");
        });

        it("toJSON transforms _id to id for climber", async () => {
            const climber = new User({
                userType: "Climber",
                email: "climber@example.com",
                username: "climber",
                name: "John",
                surname: "Doe",
                birthdate: new Date("1990-01-01"),
            });

            await climber.save();

            const json = climber.toJSON();
            expect(String(json.id)).toEqual(climber._id.toString());
            expect(json._id).toBeUndefined();
            expect(json.__v).toBeUndefined();
        });
    });
});
