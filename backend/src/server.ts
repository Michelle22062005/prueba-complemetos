import express from "express";
import cors from "cors";

import authRoutes from "./interfaces/http/routes/authRoutes";
import channelRoutes from "./interfaces/http/routes/channelRoutes";
import messageRoutes from "./interfaces/http/routes/messageRoutes";
import searchRoutes from "./interfaces/http/routes/searchRoutes";

import { testDatabaseConnection } from "./infrastructure/database/postgres";

import { env } from "./config/env";

import { errorHandler } from "./interfaces/http/middleware/errorHandler";
import { notFound } from "./interfaces/http/middleware/notFound";
import { correlationId } from "./interfaces/http/middleware/correlationId";

const app = express();

app.use(cors());

app.use(express.json());

app.use(correlationId);

app.get(
  "/health",
  (_req, res) => {
    res.json({
      status: "ok",
    });
  }
);

app.use(
  "/api/auth",
  authRoutes
);

app.use(
  "/api/channels",
  channelRoutes
);

app.use(
  "/api",
  messageRoutes
);

app.use(
  "/api",
  searchRoutes
);

app.use(notFound);

app.use(errorHandler);

app.listen(
  env.port,
  async () => {
    console.log(
      `Backend ejecutándose en http://localhost:${env.port}`
    );

    try {
      await testDatabaseConnection();
    } catch (error) {
      console.error(
        "Error conectando a PostgreSQL:",
        error
      );
    }
  }
);