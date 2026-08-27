import {
  Request,
  Response,
} from "express";

import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { v4 as uuidv4 } from "uuid";

import {
  pool,
} from "../../../infrastructure/database/postgres";

import { env } from "../../../config/env";

function createAccessToken(
  userId: string
): string {
  return jwt.sign(
    {},
    env.jwt.secret,
    {
      subject: userId,
      expiresIn:
        env.jwt.expiresIn as jwt.SignOptions["expiresIn"],
    }
  );
}

function createRefreshToken(): string {
  return crypto
    .randomBytes(64)
    .toString("hex");
}

function hashRefreshToken(
  token: string
): string {
  return crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
}

export async function login(
  req: Request,
  res: Response
) {
  try {
    const {
      email,
      password,
    } = req.body;

    if (
      typeof email !== "string" ||
      typeof password !== "string" ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        error:
          "Email y contraseña son requeridos",
      });
    }

    const result = await pool.query(
      `
      SELECT
        rw_user_id,
        rw_email,
        rw_password_hash,
        rw_full_name,
        rw_role_title
      FROM public.rw_users
      WHERE lower(rw_email) = lower($1)
        AND rw_deleted_at IS NULL
      `,
      [email.trim()]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: "Credenciales inválidas",
      });
    }

    const user = result.rows[0];

    const validPassword =
      await bcrypt.compare(
        password,
        user.rw_password_hash
      );

    if (!validPassword) {
      return res.status(401).json({
        error: "Credenciales inválidas",
      });
    }

    const accessToken =
      createAccessToken(
        user.rw_user_id
      );

    const refreshToken =
      createRefreshToken();

    const refreshTokenHash =
      hashRefreshToken(
        refreshToken
      );

    await pool.query(
      `
      INSERT INTO public.rw_refresh_tokens (
        rw_token_id,
        rw_user_id,
        rw_token_hash,
        rw_expires_at
      )
      VALUES (
        $1,
        $2,
        $3,
        now() + interval '7 days'
      )
      `,
      [
        uuidv4(),
        user.rw_user_id,
        refreshTokenHash,
      ]
    );

    return res.status(200).json({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: {
        id: user.rw_user_id,
        email: user.rw_email,
        full_name:
          user.rw_full_name,
        role_title:
          user.rw_role_title,
      },
    });
  } catch (error) {
    console.error(
      "Error en login:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}

export async function refresh(
  req: Request,
  res: Response
) {
  try {
    const {
      refresh_token,
    } = req.body;

    if (
      typeof refresh_token !==
      "string" ||
      !refresh_token
    ) {
      return res.status(400).json({
        error:
          "Refresh token requerido",
      });
    }

    const tokenHash =
      hashRefreshToken(
        refresh_token
      );

    const client =
      await pool.connect();

    try {
      await client.query(
        "BEGIN"
      );

      const result =
        await client.query(
          `
          SELECT
            rt.rw_token_id,
            rt.rw_user_id
          FROM public.rw_refresh_tokens rt
          JOIN public.rw_users u
            ON u.rw_user_id =
               rt.rw_user_id
          WHERE rt.rw_token_hash = $1
            AND rt.rw_revoked = false
            AND rt.rw_expires_at > now()
            AND u.rw_deleted_at IS NULL
          FOR UPDATE
          `,
          [tokenHash]
        );

      if (
        result.rows.length === 0
      ) {
        await client.query(
          "ROLLBACK"
        );

        return res.status(401).json({
          error:
            "Refresh token inválido o expirado",
        });
      }

      const tokenRecord =
        result.rows[0];

      await client.query(
        `
        UPDATE public.rw_refresh_tokens
        SET rw_revoked = true
        WHERE rw_token_id = $1
        `,
        [
          tokenRecord.rw_token_id,
        ]
      );

      const newRefreshToken =
        createRefreshToken();

      const newHash =
        hashRefreshToken(
          newRefreshToken
        );

      await client.query(
        `
        INSERT INTO public.rw_refresh_tokens (
          rw_token_id,
          rw_user_id,
          rw_token_hash,
          rw_expires_at
        )
        VALUES (
          $1,
          $2,
          $3,
          now() + interval '7 days'
        )
        `,
        [
          uuidv4(),
          tokenRecord.rw_user_id,
          newHash,
        ]
      );

      const accessToken =
        createAccessToken(
          tokenRecord.rw_user_id
        );

      await client.query(
        "COMMIT"
      );

      return res.json({
        access_token:
          accessToken,
        refresh_token:
          newRefreshToken,
      });
    } catch (error) {
      await client.query(
        "ROLLBACK"
      );
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error(
      "Error renovando token:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}

export async function logout(
  req: Request,
  res: Response
) {
  try {
    const {
      refresh_token,
    } = req.body;

    if (
      typeof refresh_token !==
      "string" ||
      !refresh_token
    ) {
      return res.status(400).json({
        error:
          "Refresh token requerido",
      });
    }

    const tokenHash =
      hashRefreshToken(
        refresh_token
      );

    await pool.query(
      `
      UPDATE public.rw_refresh_tokens
      SET rw_revoked = true
      WHERE rw_token_hash = $1
      `,
      [tokenHash]
    );

    return res.status(204).send();
  } catch (error) {
    console.error(
      "Error cerrando sesión:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}