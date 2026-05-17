# Hookd — Backend

REST API for the Hookd climbing app. Built with Node.js, Express 4, and MongoDB via Mongoose.

## Stack

- **Runtime:** Node.js
- **Framework:** Express 4
- **Database:** MongoDB + Mongoose 9
- **Auth:** JWT (short-lived access tokens) + rotating refresh tokens; Google Sign-In via Firebase Admin SDK
- **Testing:** Jest + `mongodb-memory-server` (no external DB needed)

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Environment variables

Create a `.env` file in `backend/` with:

```
JWT_SECRET=<strong random secret>
JWT_EXPIRES_IN=1h
REFRESH_TOKEN_SECRET=<different strong random secret>
REFRESH_TOKEN_EXPIRES_IN=7d
MONGO_URI=mongodb://localhost:27017/hookd   # optional, defaults to this

# Required only for Google Sign-In:
FIREBASE_PROJECT_ID=<project-id>
FIREBASE_SERVICE_ACCOUNT_JSON=<json string>  # or set GOOGLE_APPLICATION_CREDENTIALS
```

Generate a secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 3. Seed the database (optional)

```bash
npm run db:init
```

## Running

```bash
npm start   # starts on port 3000 by default
```

## Testing

```bash
npm test                        # run all tests
npm test -- models/User         # run a single model suite
npm test -- routes/auth         # run a single route suite
```

Tests use an in-memory MongoDB instance and run serially. No `.env` file or running database is required.
