import { Response } from "express";

import {
  AuthenticatedRequest,
} from "../middleware/auth";

import {
  queryAsUser,
} from "../../../infrastructure/database/postgres";

/**
 * Valida si un valor tiene formato UUID.
 */
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value
  );
}

/**
 * Express 5 puede entregar los parámetros
 * como string | string[].
 *
 * Nosotros solamente necesitamos un string.
 */
function getParam(
  value: string | string[] | undefined
): string {
  return typeof value === "string"
    ? value
    : "";
}

/**
 * Convierte errores conocidos de PostgreSQL
 * en respuestas HTTP.
 */
function mapDatabaseError(
  error: unknown
): {
  status: number;
  message: string;
} | null {
  if (
    !error ||
    typeof error !== "object"
  ) {
    return null;
  }

  const databaseError = error as {
    code?: string;
  };

  switch (databaseError.code) {
    case "22P02":
      return {
        status: 400,
        message: "Identificador inválido",
      };

    case "23503":
      return {
        status: 404,
        message:
          "Recurso relacionado no encontrado",
      };

    case "23505":
      return {
        status: 409,
        message: "Conflicto de datos",
      };

    case "23514":
      return {
        status: 422,
        message: "Datos inválidos",
      };

    case "42501":
      return {
        status: 403,
        message:
          "No tienes permisos para realizar esta acción",
      };

    default:
      return null;
  }
}

/**
 * ============================================================
 * GET /api/channels/:channelId/messages
 * ============================================================
 *
 * Obtiene los mensajes de un canal.
 *
 * Utiliza paginación KEYSET.
 */
export async function getMessages(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    const userId = req.user!.id;

    const channelId = getParam(
      req.params.channelId
    );

    if (!isUuid(channelId)) {
      return res.status(400).json({
        error: "channelId inválido",
      });
    }

    const cursorCreatedAt =
      typeof req.query.cursor_created_at ===
      "string"
        ? req.query.cursor_created_at
        : null;

    const cursorMessageId =
      typeof req.query.cursor_message_id ===
      "string"
        ? req.query.cursor_message_id
        : null;

    if (
      cursorMessageId !== null &&
      !isUuid(cursorMessageId)
    ) {
      return res.status(400).json({
        error:
          "cursor_message_id inválido",
      });
    }

    let limit = Number(
      req.query.limit ?? 20
    );

    if (
      !Number.isFinite(limit) ||
      limit <= 0
    ) {
      limit = 20;
    }

    limit = Math.min(
      Math.floor(limit),
      100
    );

    const result =
      await queryAsUser(
        userId,
        async (client) => {
          return client.query(
            `
            SELECT
              m.rw_message_id,
              m.rw_channel_id,
              m.rw_author_id,
              u.rw_full_name AS author_name,
              m.rw_body,
              m.rw_is_edited,
              m.rw_created_at,
              m.rw_edited_at
            FROM public.rw_messages m
            JOIN public.rw_users u
              ON u.rw_user_id =
                 m.rw_author_id
            WHERE
              m.rw_channel_id = $1
              AND m.rw_deleted_at IS NULL
              AND (
                $2::timestamptz IS NULL
                OR (
                  m.rw_created_at,
                  m.rw_message_id
                ) < (
                  $2::timestamptz,
                  $3::uuid
                )
              )
            ORDER BY
              m.rw_created_at DESC,
              m.rw_message_id DESC
            LIMIT $4
            `,
            [
              channelId,
              cursorCreatedAt,
              cursorMessageId,
              limit,
            ]
          );
        }
      );

    const rows = result.rows;

    let nextCursor = null;

    if (rows.length > 0) {
      const lastMessage =
        rows[rows.length - 1];

      nextCursor = {
        created_at:
          lastMessage.rw_created_at,
        message_id:
          lastMessage.rw_message_id,
      };
    }

    return res.status(200).json({
      data: rows,
      next_cursor: nextCursor,
    });
  } catch (error) {
    const mappedError =
      mapDatabaseError(error);

    if (mappedError) {
      return res
        .status(mappedError.status)
        .json({
          error: mappedError.message,
        });
    }

    console.error(
      "Error obteniendo mensajes:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}

/**
 * ============================================================
 * POST /api/messages
 * ============================================================
 *
 * Crea un mensaje.
 *
 * Body:
 *
 * {
 *   "channel_id": "UUID",
 *   "body": "Hola"
 * }
 *
 * El autor se obtiene del JWT.
 */
export async function createMessage(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    const userId = req.user!.id;

    const {
      channel_id,
      body,
    } = req.body;

    if (
      typeof channel_id !== "string" ||
      !channel_id.trim() ||
      !isUuid(channel_id.trim())
    ) {
      return res.status(400).json({
        error:
          "channel_id es requerido y debe ser un UUID válido",
      });
    }

    if (
      typeof body !== "string" ||
      !body.trim()
    ) {
      return res.status(400).json({
        error: "body es requerido",
      });
    }

    const messageBody =
      body.trim();

    const result =
      await queryAsUser(
        userId,
        async (client) => {
          return client.query(
            `
            SELECT app.create_message(
              $1::uuid,
              $2::text
            ) AS message_id
            `,
            [
              channel_id.trim(),
              messageBody,
            ]
          );
        }
      );

    return res.status(201).json({
      message_id:
        result.rows[0].message_id,
    });
  } catch (error) {
    const mappedError =
      mapDatabaseError(error);

    if (mappedError) {
      return res
        .status(mappedError.status)
        .json({
          error: mappedError.message,
        });
    }

    console.error(
      "Error creando mensaje:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}

/**
 * ============================================================
 * PATCH /api/messages/:messageId
 * ============================================================
 *
 * Edita un mensaje.
 *
 * Body:
 *
 * {
 *   "body": "Mensaje actualizado"
 * }
 */
export async function editMessage(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    const userId = req.user!.id;

    const messageId = getParam(
      req.params.messageId
    );

    if (!isUuid(messageId)) {
      return res.status(400).json({
        error:
          "messageId inválido",
      });
    }

    const { body } = req.body;

    if (
      typeof body !== "string" ||
      !body.trim()
    ) {
      return res.status(400).json({
        error:
          "El mensaje no puede estar vacío",
      });
    }

    const messageBody =
      body.trim();

    const result =
      await queryAsUser(
        userId,
        async (client) => {
          return client.query(
            `
            SELECT app.edit_message(
              $1::uuid,
              $2::text
            ) AS updated
            `,
            [
              messageId,
              messageBody,
            ]
          );
        }
      );

    const updated =
      result.rows[0]?.updated;

    if (!updated) {
      return res.status(404).json({
        error:
          "Mensaje no encontrado",
      });
    }

    return res.status(200).json({
      updated: true,
    });
  } catch (error) {
    const mappedError =
      mapDatabaseError(error);

    if (mappedError) {
      return res
        .status(mappedError.status)
        .json({
          error: mappedError.message,
        });
    }

    console.error(
      "Error editando mensaje:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}

/**
 * ============================================================
 * DELETE /api/messages/:messageId
 * ============================================================
 *
 * Elimina lógicamente un mensaje.
 *
 * No elimina físicamente el registro.
 */
export async function deleteMessage(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    const userId = req.user!.id;

    const messageId = getParam(
      req.params.messageId
    );

    if (!isUuid(messageId)) {
      return res.status(400).json({
        error:
          "messageId inválido",
      });
    }

    const result =
      await queryAsUser(
        userId,
        async (client) => {
          return client.query(
            `
            SELECT app.delete_message(
              $1::uuid
            ) AS deleted
            `,
            [messageId]
          );
        }
      );

    const deleted =
      result.rows[0]?.deleted;

    if (!deleted) {
      return res.status(404).json({
        error:
          "Mensaje no encontrado",
      });
    }

    return res.status(204).send();
  } catch (error) {
    const mappedError =
      mapDatabaseError(error);

    if (mappedError) {
      return res
        .status(mappedError.status)
        .json({
          error: mappedError.message,
        });
    }

    console.error(
      "Error eliminando mensaje:",
      error
    );

    return res.status(500).json({
      error:
        "Error interno del servidor",
    });
  }
}