"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const authRoutes_1 = __importDefault(require("./interfaces/http/routes/authRoutes"));
const channelRoutes_1 = __importDefault(require("./interfaces/http/routes/channelRoutes"));
const messageRoutes_1 = __importDefault(require("./interfaces/http/routes/messageRoutes"));
const searchRoutes_1 = __importDefault(require("./interfaces/http/routes/searchRoutes"));
const postgres_1 = require("./infrastructure/database/postgres");
const env_1 = require("./config/env");
const errorHandler_1 = require("./interfaces/http/middleware/errorHandler");
const notFound_1 = require("./interfaces/http/middleware/notFound");
const correlationId_1 = require("./interfaces/http/middleware/correlationId");
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
app.use(correlationId_1.correlationId);
app.get("/health", (_req, res) => {
    res.json({
        status: "ok",
    });
});
app.use("/api/auth", authRoutes_1.default);
app.use("/api/channels", channelRoutes_1.default);
app.use("/api", messageRoutes_1.default);
app.use("/api", searchRoutes_1.default);
app.use(notFound_1.notFound);
app.use(errorHandler_1.errorHandler);
app.listen(env_1.env.port, async () => {
    console.log(`Backend ejecutándose en http://localhost:${env_1.env.port}`);
    try {
        await (0, postgres_1.testDatabaseConnection)();
    }
    catch (error) {
        console.error("Error conectando a PostgreSQL:", error);
    }
});
