"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = errorHandler;
function errorHandler(error, _req, res, _next) {
    console.error(error);
    if (error &&
        typeof error === "object" &&
        "statusCode" in error) {
        const httpError = error;
        return res
            .status(httpError.statusCode)
            .json({
            error: httpError.message,
        });
    }
    return res.status(500).json({
        error: "Error interno del servidor",
    });
}
