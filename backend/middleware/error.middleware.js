// middleware/error.middleware.js

const errorHandler = (err, req, res, next) => {
    if (process.env.NODE_ENV !== "test") {
        console.error(err);
    }

    const statusCode = err.statusCode || 500;

    res.status(statusCode).json({
        error: err.message,
    });
};

module.exports = errorHandler;
