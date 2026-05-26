const mongoose = require("mongoose");

const badgeSchema = new mongoose.Schema(
    {
        name: { type: String, required: true, trim: true },
        description: { 
            type: String, 
            trim: true,
            maxLength: [1000, "Description cannot be more than 1000 characters"]
        },
        icon: { type: String }, // URL or path to the icon image
        score: { type: Number, default: 0 },
        type: {
            type: String,
            enum: ["system", "custom"],
            default: "system",
        },
        reEarnable: {
            type: Boolean,
            default: false,
        },
        createdBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: "User",
        },
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
    }
);

module.exports = mongoose.model("Badge", badgeSchema);
