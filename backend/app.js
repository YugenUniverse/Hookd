var express = require("express");
require("dotenv").config();
var path = require("path");
var cookieParser = require("cookie-parser");
var logger = require("morgan");
var createError = require("http-errors");
var cors = require("cors");

const connectDB = require("./db");
const { authenticateJwt } = require("./middleware/auth.middleware");

var indexRouter = require("./routes/index");
var authRouter = require("./routes/auth.routes");
var wallRouter = require("./routes/wall.routes");
var reviewRouter = require("./routes/review.routes");
var sessionRouter = require("./routes/session.routes");
var userRouter = require("./routes/user.routes");
const climberRoutes = require("./routes/climber.routes");
var issueRouter = require("./routes/issue.routes");

const errorMiddleware = require("./middleware/error.middleware");

var app = express();

connectDB();

// view engine setup
app.set("views", path.join(__dirname, "views"));
app.set("view engine", "jade");

app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, "public")));
app.use(
    cors({
        origin: function (origin, callback) {
            // Allow requests with no origin (like mobile apps or curl requests)
            if (!origin) return callback(null, true);

            // Allowed origins for development and production
            const allowedOrigins = [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:8080",
                "http://127.0.0.1:8080",
                "http://localhost",
                "http://127.0.0.1",
            ];

            if (
                allowedOrigins.includes(origin) ||
                process.env.NODE_ENV !== "production"
            ) {
                callback(null, true);
            } else {
                callback(new Error("Not allowed by CORS"));
            }
        },
        credentials: true,
        methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: ["Content-Type", "Authorization"],
    }),
);

app.use("/auth", authRouter);
app.use("/walls", wallRouter);
app.use("/reviews", reviewRouter);
app.use("/climbers", climberRoutes);
app.use("/users", userRouter);

// Everything after this point requires a valid access token.
app.use(authenticateJwt);

app.use("/", indexRouter);
app.use("/sessions", sessionRouter);
app.use("/issues", issueRouter);
// catch 404 and forward to error handler
app.use(function (req, res, next) {
    next(createError(404));
});

// error handler
app.use(errorMiddleware);

module.exports = app;
