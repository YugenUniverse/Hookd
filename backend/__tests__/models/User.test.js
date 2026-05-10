const mongoose = require("mongoose");
const User = require("../../models/User");

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

        const loadedUser = await User.findById(user._id).select("+password");

        expect(await loadedUser.matchPassword(plainPassword)).toBe(true);
        expect(await loadedUser.matchPassword("bad-password")).toBe(false);
    });

    it("matchPassword returns false when the password is not set", async () => {
        const user = new User({
            email: "celli@example.com",
            username: "celli",
        });

        await user.save();

        const loadedUser = await User.findById(user._id).select("+password");

        expect(await loadedUser.matchPassword("anything")).toBe(false);
    });
});
