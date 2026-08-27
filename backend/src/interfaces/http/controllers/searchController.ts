import { Response } from "express";
import { AuthenticatedRequest } from "../middleware/auth";
import { pool } from "../../../infrastructure/database/postgres";

export async function searchMessages(
  req: AuthenticatedRequest,
  res: Response
) {
  const userId = req.user!.id;
  const q = String(req.query.q ?? "");

  if (!q.trim()) {
    return res.status(400).json({
      error: "El término de búsqueda es requerido",
    });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    await client.query(
      `
      SELECT set_config(
        'app.current_user_id',
        $1,
        true
      )
      `,
      [userId]
    );

    const result = await client.query(
      `
      SELECT
        m.rw_message_id,
        m.rw_channel_id,
        m.rw_author_id,
        m.rw_body,
        ts_headline(
          'simple',
          m.rw_body,
          plainto_tsquery('simple', $1)
        ) AS highlighted_body,
        m.rw_created_at
      FROM public.rw_messages m
      JOIN public.rw_message_embeddings e
        ON e.rw_message_id = m.rw_message_id
      WHERE e.rw_search_vector
            @@ plainto_tsquery('simple', $1)
        AND m.rw_deleted_at IS NULL
      ORDER BY m.rw_created_at DESC
      LIMIT 50
      `,
      [q]
    );

    await client.query("COMMIT");

    return res.json(result.rows);
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}