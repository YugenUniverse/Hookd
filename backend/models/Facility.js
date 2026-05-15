const mongoose = require("mongoose");

const facilitySchema = new mongoose.Schema(
    {
        name: { type: String, required: true, trim: true },
        description: {
            type: String,
            trim: true,
            maxLength: [1000, "Description cannot be more than 1000 characters"],
        },
        location: {
            type: {
                type: String,
                enum: ["Point"],
                default: "Point",
            },
            coordinates: {
                type: [Number],
                required: [true, "Coordinates are required"],
                validate: {
                    validator: (val) => val.length === 2,
                    message: "Coordinates must be [longitude, latitude]",
                },
            },
            address: String,
        },
        walls: [{ type: mongoose.Schema.Types.ObjectId, ref: "IndoorWall" }],
        ownerAccount: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    },
    {
        timestamps: true,
        toJSON: {
            transform: (doc, ret) => {
                ret.id = ret._id;
                delete ret._id;
                delete ret.__v;
                return ret;
            },
        },
    },
);

facilitySchema.index({ location: "2dsphere" });

module.exports = mongoose.model("Facility", facilitySchema);
