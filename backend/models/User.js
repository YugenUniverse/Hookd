const mongoose = require("mongoose");
const bcrypt = require("bcrypt");

const baseUserTransform = (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    return ret;
};

// --- USER ---
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
    {
        timestamps: true,
        discriminatorKey: "userType",
        toJSON: {
            transform: baseUserTransform,
        },
    },
);

userSchema.pre("save", async function () {
    if (!this.isModified("password") || !this.password) return;

    this.password = await bcrypt.hash(this.password, 10);
});

userSchema.methods.matchPassword = async function (enteredPassword) {
    if (!this.password) return false;

    return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model("User", userSchema);

// --- CLIMBER ---
const climberSchema = new mongoose.Schema(
    {
        name: { type: String, required: true, trim: true },
        surname: { type: String, required: true, trim: true },
        birthdate: { type: Date, required: true },
        bio: {
            type: String,
            default: "",
            trim: true,
            maxlength: [200, "Bio cannot exceed 200 characters"],
        },
        wallet: {
            type: Number,
            default: 0,
            min: [0, "Wallet balance cannot be negative"],
        },
    },
    {
        toJSON: {
            transform: function (doc, ret) {
                baseUserTransform(doc, ret);
                return ret;
            },
        },
    },
);

climberSchema.methods.editUser = async function (updates) {};

const Climber = User.discriminator("Climber", climberSchema);

module.exports = User;
