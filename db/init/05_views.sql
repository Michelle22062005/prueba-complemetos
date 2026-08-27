BEGIN;

-- ============================================================
-- VISTA DE CONVERSACIONES
-- ============================================================
--
-- Devuelve una fila por cada canal al que pertenece
-- el usuario actual.
--
-- Incluye:
--   - información del canal
--   - último mensaje visible
--   - autor del último mensaje
--   - fecha del último mensaje
--
-- El usuario actual se obtiene mediante:
--
--     app.current_user_id()
--
-- ============================================================

CREATE OR REPLACE VIEW public.vw_conversations
WITH (security_invoker = true)
AS
SELECT
    c.rw_channel_id,
    c.rw_name,
    c.rw_is_private,
    c.rw_created_at,

    m.rw_message_id AS last_message_id,
    m.rw_body AS last_message_body,
    m.rw_author_id AS last_message_author_id,

    u.rw_full_name AS last_message_author_name,

    m.rw_created_at AS last_message_created_at,
    m.rw_is_edited AS last_message_is_edited

FROM public.rw_channels c

LEFT JOIN LATERAL (
    SELECT
        m.rw_message_id,
        m.rw_body,
        m.rw_author_id,
        m.rw_created_at,
        m.rw_is_edited
    FROM public.rw_messages m
    WHERE m.rw_channel_id = c.rw_channel_id
      AND m.rw_deleted_at IS NULL
    ORDER BY
        m.rw_created_at DESC,
        m.rw_message_id DESC
    LIMIT 1
) m ON true

LEFT JOIN public.rw_users u
    ON u.rw_user_id = m.rw_author_id
   AND u.rw_deleted_at IS NULL

WHERE EXISTS (
    SELECT 1
    FROM public.rw_channel_members cm
    WHERE cm.rw_channel_id = c.rw_channel_id
      AND cm.rw_user_id = app.current_user_id()
);

-- ============================================================
-- PERMISO DE LECTURA
-- ============================================================

GRANT SELECT ON public.vw_conversations TO rw_app_role;

COMMIT;