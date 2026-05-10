const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");

const User = require("../models/User");
const RefreshToken = require("../models/RefreshToken");

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "1h";
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || "7d";
const ISSUER = "hookd";

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

exports.register = async ({ email, password, username }) => {
    if (!email || !password) {
        throw new Error("Missing fields");
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
        const error = new Error("User already exists with that email");
        error.statusCode = 409;
        throw error;
    }

    const user = await User.create({
        email,
        password,
        username,
        authMethods: ["local"],
    });

    return { id: user._id, email: user.email };
};

exports.login = async ({ email, password }) => {
    if (!email || !password) {
        throw new Error("Missing fields");
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
        const error = new Error("Refresh token has been revoked or expired");
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
        const error = new Error("Google ID token is  required");
        error.statusCode = 400;
        throw error;
    }

    let payload;
    try {
        const ticket = await googlClient.verifyIdToken({
            idToken,
            audiance: process.env.GOOGLE_CLIENT_ID,
        });
        payload = ticket.getPayload();
    } catch (err) {
        const error = new Error("Invalid Google token");
        error.statusCode = 401;
        throw error;
    }

    const { sub, email, name, picture } = payload;

    let user = await User.findOne({ $or: [{ googleId: sub }, { email }] });

    if (!user) {
        user = await User.create({
            email,
            username: name,
            avatar: picture,
            authMethods: ["google"],
        });
    } else if (!user.googleId) {
        user.googleId = sub;

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
