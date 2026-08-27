"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticate = authenticate;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const env_1 = require("../../../config/env");
function authenticate(req, res, next) {
    try {
        const authorization = req.headers.authorization;
        if (!authorization) {
            return res.status(401).json({
                error: "Token de autenticación requerido",
            });
        }
        const [scheme, token] = authorization.split(" ");
        if (scheme !== "Bearer" ||
            !token) {
            return res.status(401).json({
                error: "Formato de autorización inválido",
            });
        }
        const payload = jsonwebtoken_1.default.verify(token, env_1.env.jwt.secret);
        if (typeof payload === "string" ||
            !payload.sub) {
            return res.status(401).json({
                error: "Token inválido",
            });
        }
        req.user = {
            id: payload.sub,
        };
        next();
    }
    catch {
        return res.status(401).json({
            error: "Token inválido o expirado",
        });
    }
}
