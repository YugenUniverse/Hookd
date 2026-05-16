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

## Unit testing

To run the unit tests, run this command in the terminal:
```bash
npm test
```

To specify which module to test (e.g. `User.js`), run:
```bash
npm test -- models/User
```
