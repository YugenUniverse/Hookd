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

## API reference

All protected endpoints require an `Authorization: Bearer <token>` header.

### Auth — `/auth`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | — | Register a new user (`Climber` by default) |
| POST | `/auth/login` | — | Login; returns `accessToken` + `refreshToken` |
| POST | `/auth/refresh` | — | Exchange a refresh token for a new access token |
| POST | `/auth/logout` | — | Revoke the refresh token |
| GET  | `/auth/me` | ✓ | Returns the authenticated user's profile |
| POST | `/auth/google` | — | Verify a Firebase ID token and issue app JWTs |

### Walls — `/walls`

| Method | Path | Auth | Roles | Description |
|--------|------|------|-------|-------------|
| GET | `/walls` | — | — | List all walls |
| GET | `/walls/search?q=` | — | — | Search walls by name |
| GET | `/walls/nearby?lng=&lat=&radius=` | — | — | Walls within radius (metres) |
| GET | `/walls/owned` | ✓ | FacilityOwner, PublicBody | Walls owned by the authenticated user |
| GET | `/walls/:id` | — | — | Get a single wall |
| GET | `/walls/:id/leaderboard?limit=&offset=` | — | — | Seasonal leaderboard for a wall |
| POST | `/walls` | ✓ | FacilityOwner, PublicBody | Create a wall |
| PUT | `/walls/:id` | ✓ | FacilityOwner, PublicBody | Update a wall |
| DELETE | `/walls/:id` | ✓ | FacilityOwner, PublicBody | Delete a wall |

### POIs — `/pois`

Unified map layer that merges `OutdoorWall` and `Facility` documents. Use these endpoints for map display instead of `/walls` directly.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/pois/nearby?lng=&lat=&radius=` | — | POIs near a location |
| GET | `/pois/search?q=&type=&difficulty=` | — | Search POIs by name with optional filters |
| GET | `/pois/all` | — | All POIs |

### Facilities — `/facilities`

| Method | Path | Auth | Roles | Description |
|--------|------|------|-------|-------------|
| GET | `/facilities/search?q=` | — | — | Search unclaimed facilities by name |
| POST | `/facilities/:id/claim` | ✓ | FacilityOwner | Claim an unclaimed facility |
| PUT | `/facilities/:id` | ✓ | FacilityOwner | Update facility details |
| POST | `/facilities/:id/unpair` | ✓ | FacilityOwner | Unpair from a facility |

### Sessions — `/sessions` ✓

All session endpoints require authentication.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/sessions` | Log a new climbing session (optionally with a review) |
| GET | `/sessions` | List the authenticated user's sessions |
| GET | `/sessions/:id` | Get a single session |
| PUT | `/sessions/:id` | Update a session |
| DELETE | `/sessions/:id` | Delete a session |
| POST | `/sessions/:id/reviews` | Add a review to an existing session |

### Reviews — `/reviews`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/reviews/wall/:wallId` | — | Reviews for a wall |
| GET | `/reviews/user/:userId` | — | Reviews by a user |

### Issues — `/issues` ✓

All issue endpoints require authentication.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/issues` | Report an issue on a wall |
| GET | `/issues/walls/:wallId` | Issues for a wall |
| GET | `/issues/my-issues` | Issues reported by the authenticated user |
| PUT | `/issues/:id/status` | Update issue status (`OPEN`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`) |
| DELETE | `/issues/:id` | Delete an issue |

### Reports — `/reports` ✓

Restricted to `FacilityOwner` and `PublicBody`.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/reports/wall/:wallId` | Generate a live analytics report for a wall |
| POST | `/reports/wall/:wallId/save` | Save a report snapshot |
| GET | `/reports/saved` | List saved reports |
| GET | `/reports/saved/:id` | Get a saved report |
| DELETE | `/reports/saved/:id` | Delete a saved report |

### Climbers — `/climbers`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/climbers/leaderboard` | — | Global climber leaderboard |

### Users — `/users`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/users/me` | ✓ | Full profile of the authenticated user |
| GET | `/users/:id` | — | Public profile of a user |

## Testing

```bash
npm test                        # run all tests
npm test -- models/User         # run a single model suite
npm test -- routes/auth         # run a single route suite
```

Tests use an in-memory MongoDB instance and run serially. No `.env` file or running database is required.
