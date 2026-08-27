import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { env } from "../../../config/env";

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
  };
}

export function authenticate(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({
      error: "Token de autenticación requerido",
    });
  }

  const token = header.substring(7);

  try {
    const payload = jwt.verify(token, env.jwt.secret) as {
      sub: string;
    };

    if (!payload.sub) {
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
      error: "Token inválido o expirado",
    });
  }
}