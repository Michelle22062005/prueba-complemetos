"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notFound = notFound;
function notFound(_req, res) {
    return res.status(404).json({
        error: "Ruta no encontrada",
    });
}
