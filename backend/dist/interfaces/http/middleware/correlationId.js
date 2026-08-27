"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.correlationId = correlationId;
const crypto_1 = require("crypto");
function correlationId(req, res, next) {
    const existing = req.headers["x-correlation-id"];
    const id = typeof existing === "string" &&
        existing.trim()
        ? existing
        : (0, crypto_1.randomUUID)();
    res.setHeader("X-Correlation-ID", id);
    next();
}
