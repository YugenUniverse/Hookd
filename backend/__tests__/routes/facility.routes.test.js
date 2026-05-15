const request = require("supertest");
const express = require("express");
const mongoose = require("mongoose");

const facilityRoutes = require("../../routes/facility.routes");
const errorMiddleware = require("../../middleware/error.middleware");
const Facility = require("../../models/Facility");
const { User, FacilityOwner } = require("../../models/User");

jest.mock("../../middleware/auth.middleware", () => ({
    authenticateJwt: (req, res, next) => {
        req.user = {
            id: "60d5ecdec021f13528e01369",
            userType: "FacilityOwner",
        };
        next();
    },
    restrictTo:
        (...roles) =>
        (req, res, next) =>
            next(),
}));

jest.setTimeout(30000);

const app = express();
app.use(express.json());
app.use("/facilities", facilityRoutes);
app.use(errorMiddleware);

describe("Facility Routes", () => {
    beforeAll(async () => {
        await mongoose.connect(process.env.MONGO_URI, {
            dbName: "hookd_test",
        });
    });

    beforeEach(async () => {
        await Facility.deleteMany({});
        await User.deleteMany({});

        await FacilityOwner.create({
            _id: "60d5ecdec021f13528e01369",
            email: "owner@test.com",
            username: "facilityowner",
            authMethods: ["local"],
            userType: "FacilityOwner",
        });
    });

    afterEach(async () => {
        await Facility.deleteMany({});
        await User.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
    });

    it("claims an unowned facility", async () => {
        const facility = await Facility.create({
            name: "Vertical Lab",
            location: { coordinates: [11.1, 46.1] },
        });

        const res = await request(app).post(`/facilities/${facility._id}/claim`);

        expect(res.status).toBe(200);
        expect(res.body.message).toBe("Facility claimed successfully");

        const claimedFacility = await Facility.findById(facility._id);
        const owner = await FacilityOwner.findById("60d5ecdec021f13528e01369");

        expect(claimedFacility.ownerAccount.toString()).toBe(
            "60d5ecdec021f13528e01369",
        );
        expect(owner.facility.toString()).toBe(facility._id.toString());
    });

    it("transfers ownership when the same owner claims a different facility", async () => {
        const firstFacility = await Facility.create({
            name: "First Gym",
            location: { coordinates: [11.11, 46.11] },
        });
        const secondFacility = await Facility.create({
            name: "Second Gym",
            location: { coordinates: [11.12, 46.12] },
        });

        await request(app).post(`/facilities/${firstFacility._id}/claim`);
        const res = await request(app).post(`/facilities/${secondFacility._id}/claim`);

        expect(res.status).toBe(200);
        expect(res.body.message).toBe("Facility claimed successfully");

        const refreshedFirstFacility = await Facility.findById(firstFacility._id);
        const refreshedSecondFacility = await Facility.findById(secondFacility._id);
        const owner = await FacilityOwner.findById("60d5ecdec021f13528e01369");

        expect(refreshedFirstFacility.ownerAccount).toBeUndefined();
        expect(refreshedSecondFacility.ownerAccount.toString()).toBe(
            "60d5ecdec021f13528e01369",
        );
        expect(owner.facility.toString()).toBe(secondFacility._id.toString());
    });

    it("updates the claimed facility", async () => {
        const facility = await Facility.create({
            name: "Update Gym",
            description: "Old description",
            location: { coordinates: [11.2, 46.2] },
        });

        await request(app).post(`/facilities/${facility._id}/claim`);

        const res = await request(app)
            .put(`/facilities/${facility._id}`)
            .send({
                name: "Updated Gym",
                description: "New description",
                location: {
                    type: "Point",
                    coordinates: [11.25, 46.25],
                    address: "Updated address",
                },
            });

        expect(res.status).toBe(200);
        expect(res.body.message).toBe("Facility updated successfully");
        expect(res.body.facility.name).toBe("Updated Gym");
        expect(res.body.facility.description).toBe("New description");
        expect(res.body.facility.location.coordinates).toEqual([11.25, 46.25]);

        const updated = await Facility.findById(facility._id);
        expect(updated.name).toBe("Updated Gym");
    });

    it("unpairs the claimed facility", async () => {
        const facility = await Facility.create({
            name: "Unpair Gym",
            location: { coordinates: [11.3, 46.3] },
        });

        await request(app).post(`/facilities/${facility._id}/claim`);
        const res = await request(app).post(`/facilities/${facility._id}/unpair`);

        expect(res.status).toBe(200);
        expect(res.body.message).toBe("Facility unpaired successfully");

        const updatedFacility = await Facility.findById(facility._id);
        const owner = await FacilityOwner.findById("60d5ecdec021f13528e01369");

        expect(updatedFacility.ownerAccount).toBeUndefined();
        expect(owner.facility).toBeUndefined();
    });
});
