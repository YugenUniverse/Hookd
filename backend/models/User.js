const mongoose = require("mongoose");
const bcrypt = require("bcrypt");

const userSchema = new mongoose.Schema(
    {
        email: { type: String, required: true, unique: true, lowercase: true },
        username: { type: String, required: true },

        avatar: {
            type: String,
            default: "",
        },

        password: { type: String, select: false },
        googleId: { type: String, unique: true, sparse: true },
        authMethods: [{ type: String, enum: ["local", "google"] }],
    },
    { timestamps: true },
);

userSchema.pre("save", async function () {
    if (!this.isModified("password") || !this.password) return;

    this.password = await bcrypt.hash(this.password, 10);
});

userSchema.methods.matchPassword = async function (enteredPassword) {
    if (!this.password) return false;

    return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model("User", userSchema);
