"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getChannels = getChannels;
const postgres_1 = require("../../../infrastructure/database/postgres");
async function getChannels(req, res) {
    try {
        const userId = req.user.id;
        const channels = await (0, postgres_1.queryAsUser)(userId, async (client) => {
            const result = await client.query(`
              SELECT
                rw_channel_id,
                rw_name,
                rw_is_private,
                rw_created_at
              FROM public.rw_channels
              ORDER BY rw_name;
            `);
            return result.rows;
        });
        return res.status(200).json({
            data: channels,
        });
    }
    catch (error) {
        console.error("Error obteniendo canales:", error);
        return res.status(500).json({
            error: "Error interno del servidor",
        });
    }
}
