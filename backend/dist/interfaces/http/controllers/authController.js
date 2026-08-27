"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.login = login;
exports.refresh = refresh;
exports.logout = logout;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const crypto_1 = __importDefault(require("crypto"));
const uuid_1 = require("uuid");
const postgres_1 = require("../../../infrastructure/database/postgres");
const env_1 = require("../../../config/env");
function createAccessToken(userId) {
    return jsonwebtoken_1.default.sign({}, env_1.env.jwt.secret, {
        subject: userId,
        expiresIn: env_1.env.jwt.expiresIn,
    });
}
function createRefreshToken() {
    return crypto_1.default
        .randomBytes(64)
        .toString("hex");
}
function hashRefreshToken(token) {
    return crypto_1.default
        .createHash("sha256")
        .update(token)
        .digest("hex");
}
async function login(req, res) {
    try {
        const { email, password, } = req.body;
        if (typeof email !== "string" ||
            typeof password !== "string" ||
            !email.trim() ||
            !password) {
            return res.status(400).json({
                error: "Email y contraseña son requeridos",
            });
        }
        const result = await postgres_1.pool.query(`
      SELECT
        rw_user_id,
        rw_email,
        rw_password_hash,
        rw_full_name,
        rw_role_title
      FROM public.rw_users
      WHERE lower(rw_email) = lower($1)
        AND rw_deleted_at IS NULL
      `, [email.trim()]);
        if (result.rows.length === 0) {
            return res.status(401).json({
                error: "Credenciales inválidas",
            });
        }
        const user = result.rows[0];
        const validPassword = await bcryptjs_1.default.compare(password, user.rw_password_hash);
        if (!validPassword) {
            return res.status(401).json({
                error: "Credenciales inválidas",
            });
        }
        const accessToken = createAccessToken(user.rw_user_id);
        const refreshToken = createRefreshToken();
        const refreshTokenHash = hashRefreshToken(refreshToken);
        await postgres_1.pool.query(`
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
      `, [
            (0, uuid_1.v4)(),
            user.rw_user_id,
            refreshTokenHash,
        ]);
        return res.status(200).json({
            access_token: accessToken,
            refresh_token: refreshToken,
            user: {
                id: user.rw_user_id,
                email: user.rw_email,
                full_name: user.rw_full_name,
                role_title: user.rw_role_title,
            },
        });
    }
    catch (error) {
        console.error("Error en login:", error);
        return res.status(500).json({
            error: "Error interno del servidor",
        });
    }
}
async function refresh(req, res) {
    try {
        const { refresh_token, } = req.body;
        if (typeof refresh_token !==
            "string" ||
            !refresh_token) {
            return res.status(400).json({
                error: "Refresh token requerido",
            });
        }
        const tokenHash = hashRefreshToken(refresh_token);
        const client = await postgres_1.pool.connect();
        try {
            await client.query("BEGIN");
            const result = await client.query(`
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
          `, [tokenHash]);
            if (result.rows.length === 0) {
                await client.query("ROLLBACK");
                return res.status(401).json({
                    error: "Refresh token inválido o expirado",
                });
            }
            const tokenRecord = result.rows[0];
            await client.query(`
        UPDATE public.rw_refresh_tokens
        SET rw_revoked = true
        WHERE rw_token_id = $1
        `, [
                tokenRecord.rw_token_id,
            ]);
            const newRefreshToken = createRefreshToken();
            const newHash = hashRefreshToken(newRefreshToken);
            await client.query(`
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
        `, [
                (0, uuid_1.v4)(),
                tokenRecord.rw_user_id,
                newHash,
            ]);
            const accessToken = createAccessToken(tokenRecord.rw_user_id);
            await client.query("COMMIT");
            return res.json({
                access_token: accessToken,
                refresh_token: newRefreshToken,
            });
        }
        catch (error) {
            await client.query("ROLLBACK");
            throw error;
        }
        finally {
            client.release();
        }
    }
    catch (error) {
        console.error("Error renovando token:", error);
        return res.status(500).json({
            error: "Error interno del servidor",
        });
    }
}
async function logout(req, res) {
    try {
        const { refresh_token, } = req.body;
        if (typeof refresh_token !==
            "string" ||
            !refresh_token) {
            return res.status(400).json({
                error: "Refresh token requerido",
            });
        }
        const tokenHash = hashRefreshToken(refresh_token);
        await postgres_1.pool.query(`
      UPDATE public.rw_refresh_tokens
      SET rw_revoked = true
      WHERE rw_token_hash = $1
      `, [tokenHash]);
        return res.status(204).send();
    }
    catch (error) {
        console.error("Error cerrando sesión:", error);
        return res.status(500).json({
            error: "Error interno del servidor",
        });
    }
}
