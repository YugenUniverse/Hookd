const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const admin = require("firebase-admin");

const { User, Facility, PublicBody } = require("../models/User");
const RefreshToken = require("../models/RefreshToken");

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "1h";
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || "7d";
const ISSUER = "hookd";

// Initialize Firebase Admin SDK for verifying Firebase ID tokens.
if (!admin.apps.length) {
    const firebaseProjectId = process.env.FIREBASE_PROJECT_ID;

    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        try {
            const serviceAccount = JSON.parse(
                process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
            );
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
        } catch (err) {
            console.error(
                "Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:",
                err.message,
            );
        }
    } else if (firebaseProjectId) {
        // For local/non-GCP environments: initialize with project ID only
        // This requires GOOGLE_APPLICATION_CREDENTIALS to be set separately
        try {
            admin.initializeApp({
                projectId: firebaseProjectId,
            });
        } catch (err) {
            console.warn(
                "Firebase initialization with projectId:",
                err.message,
            );
        }
    } else {
        // Last resort: try default initialization (requires GOOGLE_APPLICATION_CREDENTIALS env var)
        try {
            admin.initializeApp();
        } catch (err) {
            console.warn("firebase-admin default initialization:", err.message);
        }
    }
}

const getJwtSecret = () => {
    if (!process.env.JWT_SECRET) {
        const error = new Error("JWT_SECRET is not configured");
        error.statusCode = 500;
        throw error;
    }

    return process.env.JWT_SECRET;
};

const getRefreshTokenSecret = () => {
    return process.env.REFRESH_TOKEN_SECRET || getJwtSecret();
};

const parseExpiresInToDate = (expiresIn) => {
    if (typeof expiresIn === "number") {
        return new Date(Date.now() + expiresIn * 1000);
    }

    const match = String(expiresIn)
        .trim()
        .match(/^(\d+)([smhd])$/i);

    if (!match) {
        throw new Error("Invalid token expiration format");
    }

    const amount = Number(match[1]);
    const unit = match[2].toLowerCase();

    const multipliers = {
        s: 1000,
        m: 60 * 1000,
        h: 60 * 60 * 1000,
        d: 24 * 60 * 60 * 1000,
    };

    return new Date(Date.now() + amount * multipliers[unit]);
};

const generateAccessToken = (user) => {
    return jwt.sign(
        {
            sub: user._id.toString(),
            email: user.email,
            userType: user.userType,
        },
        getJwtSecret(),
        {
            expiresIn: JWT_EXPIRES_IN,
            issuer: ISSUER,
        },
    );
};

const createRefreshToken = async (user) => {
    const tokenId = crypto.randomUUID();

    const refreshToken = jwt.sign(
        {
            sub: user._id.toString(),
            type: "refresh",
            jti: tokenId,
        },
        getRefreshTokenSecret(),
        {
            expiresIn: REFRESH_TOKEN_EXPIRES_IN,
            issuer: ISSUER,
        },
    );

    await RefreshToken.create({
        tokenId,
        userId: user._id,
        expiresAt: parseExpiresInToDate(REFRESH_TOKEN_EXPIRES_IN),
    });

    return refreshToken;
};

exports.register = async ({
    email,
    password,
    username,
    userType,
    ...restData
}) => {
    if (!email || !password || !username) {
        const error = new Error("Missing fields");
        error.statusCode = 400;
        throw error;
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
        const error = new Error("User already exists with that email");
        error.statusCode = 409;
        throw error;
    }

    let user;
    const baseUserData = {
        email,
        password,
        username,
        authMethods: ["local"],
        ...restData,
    };

    if (userType === "Facility") {
        user = await Facility.create(baseUserData);
    } else if (userType === "PublicBody") {
        user = await PublicBody.create(baseUserData);
    } else {
        user = await User.create(baseUserData);
    }

    return { id: user._id, email: user.email };
};

exports.login = async ({ email, password }) => {
    if (!email || !password) {
        const error = new Error("Missing fields");
        error.statusCode = 400;
        throw error;
    }

    const user = await User.findOne({ email }).select("+password");

    if (!user) {
        const error = new Error("Invalid credentials");
        error.statusCode = 401;
        throw error;
    }

    if (!user.password) {
        const error = new Error("Invalid login method for this account");
        error.statusCode = 400;
        throw error;
    }

    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
        const error = new Error("Invalid credentials");
        error.statusCode = 401;
        throw error;
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = await createRefreshToken(user);

    return {
        accessToken,
        refreshToken,
    };
};

exports.refreshTokens = async ({ refreshToken }) => {
    if (!refreshToken) {
        const error = new Error("Refresh token is required");
        error.statusCode = 400;
        throw error;
    }

    try {
        const payload = jwt.verify(refreshToken, getRefreshTokenSecret(), {
            issuer: ISSUER,
        });

        const refreshTokenDoc = await RefreshToken.findOne({
            tokenId: payload.jti,
            userId: payload.sub,
            revokedAt: null,
            expiresAt: { $gt: new Date() },
        }).populate("userId");

        if (!refreshTokenDoc) {
            const error = new Error(
                "Refresh token has been revoked or expired",
            );
            error.statusCode = 401;
            throw error;
        }

        refreshTokenDoc.revokedAt = new Date();
        await refreshTokenDoc.save();

        const user = refreshTokenDoc.userId;
        const accessToken = generateAccessToken(user);
        const newRefreshToken = await createRefreshToken(user);

        return {
            accessToken,
            refreshToken: newRefreshToken,
        };
    } catch (err) {
        if (err.statusCode) {
            throw err;
        }
        const error = new Error("Invalid refresh token");
        error.statusCode = 401;
        throw error;
    }
};

exports.logout = async ({ refreshToken }) => {
    if (!refreshToken) {
        return;
    }

    try {
        const payload = jwt.verify(refreshToken, getRefreshTokenSecret(), {
            issuer: ISSUER,
            ignoreExpiration: true,
        });

        if (!payload.jti) {
            return;
        }

        await RefreshToken.updateOne(
            { tokenId: payload.jti, revokedAt: null },
            { $set: { revokedAt: new Date() } },
        );
    } catch (err) {
        return;
    }
};

exports.googleLogin = async ({ idToken }) => {
    if (!idToken) {
        const error = new Error("Firebase ID token is required");
        error.statusCode = 400;
        throw error;
    }

    let decoded;
    try {
        if (!admin.apps.length) {
            throw new Error(
                "Firebase Admin SDK not initialized. Check FIREBASE_PROJECT_ID or FIREBASE_SERVICE_ACCOUNT_JSON env vars.",
            );
        }
        decoded = await admin.auth().verifyIdToken(idToken);
    } catch (err) {
        const errorMsg = err.message || String(err);
        const error = new Error("Invalid Firebase ID token: " + errorMsg);
        error.statusCode = 401;
        throw error;
    }

    const uid = decoded.uid;
    let email = decoded.email;
    let name = decoded.name;
    let picture = decoded.picture;

    try {
        const userRecord = await admin.auth().getUser(uid);
        email = email || userRecord.email;
        name = name || userRecord.displayName;
        picture = picture || userRecord.photoURL;
    } catch (e) {
        // ignore - profile info is optional
    }

    let user = await User.findOne({ $or: [{ googleId: uid }, { email }] });

    if (!user) {
        user = await User.create({
            email,
            username: name,
            avatar: picture,
            googleId: uid,
            authMethods: ["google"],
        });
    } else if (!user.googleId) {
        user.googleId = uid;

        if (!user.avatar || user.avatar === "") {
            user.avatar = picture;
        }

        if (!user.authMethods.includes("google")) {
            user.authMethods.push("google");
        }
        await user.save();
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = await createRefreshToken(user);

    return {
        accessToken,
        refreshToken,
    };
};
