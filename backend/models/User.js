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

userSchema.methods.editUser = function (updates) {};

const User = mongoose.model("User", userSchema);

// --- CLIMBER ---
const climberSchema = new mongoose.Schema(
    {
        name: { type: String, trim: true },
        surname: { type: String, trim: true },
        birthdate: { type: Date },
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
        sessions: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: "ClimbingSession",
            },
        ],
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

climberSchema.methods.editUser = function (updates) {};

const Climber = User.discriminator("Climber", climberSchema);

// --- FACILITY OWNER ---
// Auth account for a gym/facility operator. Profile data (name, location, walls)
// lives in the standalone Facility model; this holds only the account link.
const facilityOwnerSchema = new mongoose.Schema(
    {
        name: { type: String, trim: true },
        surname: { type: String, trim: true },
        bio: {
            type: String,
            default: "",
            trim: true,
            maxlength: [200, "Bio cannot exceed 200 characters"],
        },
        facility: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "Facility",
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

facilityOwnerSchema.methods.editUser = function (updates) {};

const FacilityOwner = User.discriminator("FacilityOwner", facilityOwnerSchema);

// --- PUBLIC BODY ---
const publicBodySchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: true,
            trim: true,
        },
        bio: {
            type: String,
            default: "",
            trim: true,
            maxlength: [200, "Bio cannot exceed 200 characters"],
        },
        description: {
            type: String,
            trim: true,
            maxLength: [
                1000,
                "Description cannot be more than 1000 characters",
            ],
        },
        location: {
            type: {
                type: String,
                enum: ["Point"],
                default: "Point",
            },
            coordinates: {
                type: [Number], // [Longitude, Latitude]
                required: [true, "Coordinates are required"],
                validate: {
                    validator: (val) => val.length === 2,
                    message: "Coordinates must be [longitude, latitude]",
                },
            },
            address: String,
        },
        walls: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: "OutdoorWall",
            },
        ],
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

publicBodySchema.methods.editUser = function (updates) {};

const PublicBody = User.discriminator("PublicBody", publicBodySchema);

module.exports = {
    User,
    Climber,
    FacilityOwner,
    PublicBody,
};
