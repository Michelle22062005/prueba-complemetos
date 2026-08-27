import {
  Request,
  Response,
  NextFunction,
} from "express";

import jwt from "jsonwebtoken";

import { env } from "../../../config/env";

export interface AuthenticatedRequest
  extends Request {
  user?: {
    id: string;
  };
}

export function authenticate(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) {
  try {
    const authorization =
      req.headers.authorization;

    if (!authorization) {
      return res.status(401).json({
        error:
          "Token de autenticación requerido",
      });
    }

    const [scheme, token] =
      authorization.split(" ");

    if (
      scheme !== "Bearer" ||
      !token
    ) {
      return res.status(401).json({
        error:
          "Formato de autorización inválido",
      });
    }

    const payload = jwt.verify(
      token,
      env.jwt.secret
    );

    if (
      typeof payload === "string" ||
      !payload.sub
    ) {
      return res.status(401).json({
        error: "Token inválido",
      });
    }

    req.user = {
      id: payload.sub,
    };

    next();
  } catch {
    return res.status(401).json({
      error:
        "Token inválido o expirado",
    });
  }
}