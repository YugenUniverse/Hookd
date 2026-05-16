Backend directory

## Environment variables

Create a `.env` file in `backend/` with:

```
JWT_SECRET=replace-with-a-strong-random-secret
JWT_EXPIRES_IN=1h
REFRESH_TOKEN_SECRET=replace-with-a-different-strong-random-secret
REFRESH_TOKEN_EXPIRES_IN=7d
```

`JWT_SECRET` is required for login token signing.

To generate a secure secret in terminal:
```
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## Auth endpoints

- `POST /auth/login` → returns `accessToken` and `refreshToken`
- `POST /auth/refresh` with `{ "refreshToken": "..." }` → rotates refresh token and returns a new pair
- `POST /auth/logout` with `{ "refreshToken": "..." }` → revokes refresh token
- `GET /auth/me` with `Authorization: Bearer <accessToken>` → returns authenticated user payload

## Wall endpoints

All read endpoints are public. Write endpoints require a valid `Authorization: Bearer <token>` header and the caller's `userType` must be `FacilityOwner` or `PublicBody`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/walls` | — | Return all walls |
| `GET` | `/walls/search?q=<query>` | — | Full-text search by name |
| `GET` | `/walls/nearby?lng=&lat=&radius=` | — | Walls within `radius` metres of coordinates |
| `GET` | `/walls/:id` | — | Single wall by id |
| `GET` | `/walls/:id/leaderboard` | — | Season leaderboard for a wall |
| `POST` | `/walls` | ✅ FacilityOwner / PublicBody | Create a wall. Body: `{ name, description, difficulty, location: { coordinates: [lng, lat], address? } }`. A `FacilityOwner` creates an `IndoorWall` linked to their claimed `Facility`; a `PublicBody` creates an `OutdoorWall` linked to their account. |
| `PUT` | `/walls/:id` | ✅ owner only | Update `name`, `description`, `difficulty`, `status`, or `location`. Returns 403 if the caller does not own the wall. |
| `DELETE` | `/walls/:id` | ✅ owner only | Delete a wall and remove it from the owning entity's walls array. Returns 403 if the caller does not own the wall. |

### Ownership rules

- **FacilityOwner**: the call is authorised only when the wall's `facility` field matches the `Facility` document whose `ownerAccount` is the authenticated user.
- **PublicBody**: the call is authorised only when the wall's `publicBody` field matches the authenticated user's id.

## Facility endpoints

The `/facilities` router is mounted **before** the global JWT middleware, so the search endpoint is intentionally public.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/facilities/search?q=<query>` | — | Search unclaimed facilities by name (min 2 chars). Returns up to 10 results. |
| `POST` | `/facilities/:id/claim` | ✅ FacilityOwner | Link a facility to the authenticated account. If the account was previously linked to a different facility, that link is transferred. Returns 409 if the facility already has a different owner. |
| `PUT` | `/facilities/:id` | ✅ owner only | Update `name`, `description`, `location` of the owned facility. Returns 403 if the caller is not the facility's owner. |
| `POST` | `/facilities/:id/unpair` | ✅ owner only | Remove the link between the authenticated account and the facility. The facility document remains in the database. Returns 403 if the caller is not the facility's owner. |

## Unit testing

To run the unit tests, run this command in the terminal:
```bash
npm test
```

To specify which module to test (e.g. `User.js`), run:
```bash
npm test -- models/User
```
