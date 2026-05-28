const mongoose = require("mongoose");
const { Schema, Types: { ObjectId } } = mongoose;

const attendeeSchema = new Schema(
    {
        user: { type: ObjectId, ref: "User", required: true },
        status: { type: String, enum: ["going", "not_going"], required: true },
    },
    { _id: false },
);

const plannedClimbSchema = new Schema(
    {
        group: { type: ObjectId, ref: "Group", required: true },
        createdBy: { type: ObjectId, ref: "User", required: true },
        date: { type: Date, required: true },
        wall: { type: ObjectId, ref: "Wall" },
        facility: { type: ObjectId, ref: "Facility" },
        wallName: { type: String, trim: true, maxlength: 200 },
        notes: { type: String, trim: true, maxlength: 500 },
        attendees: { type: [attendeeSchema], default: [] },
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

plannedClimbSchema.index({ group: 1, date: 1 });

module.exports = mongoose.model("PlannedClimb", plannedClimbSchema);
