import {
  Request,
  Response,
  NextFunction,
} from "express";

import { randomUUID } from "crypto";

export function correlationId(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const existing =
    req.headers[
      "x-correlation-id"
    ];

  const id =
    typeof existing === "string" &&
    existing.trim()
      ? existing
      : randomUUID();

  res.setHeader(
    "X-Correlation-ID",
    id
  );

  next();
}