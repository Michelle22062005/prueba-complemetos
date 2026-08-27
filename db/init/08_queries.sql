BEGIN;

-- ============================================================
-- 08_queries.sql
-- Consultas SQL requeridas por el assessment
-- ============================================================


-- ============================================================
-- CONSULTA 1
-- Historial de mensajes de un canal
-- Paginación por KEYSET
--
-- Esta consulta es parametrizada y será utilizada por el backend.
--
-- Parámetros:
-- $1 = channel_id
-- $2 = cursor_created_at
-- $3 = cursor_message_id
-- $4 = cantidad de mensajes
--
-- NO utiliza OFFSET.
-- ============================================================

-- Consulta lógica para el backend:
--
-- SELECT
--     m.rw_message_id,
--     m.rw_channel_id,
--     m.rw_author_id,
--     u.rw_full_name AS author_name,
--     m.rw_body,
--     m.rw_is_edited,
--     m.rw_created_at,
--     m.rw_edited_at
-- FROM public.rw_messages m
-- JOIN public.rw_users u
--     ON u.rw_user_id = m.rw_author_id
-- WHERE m.rw_channel_id = $1
--   AND m.rw_deleted_at IS NULL
--   AND (
--       $2::timestamptz IS NULL
--       OR (
--           m.rw_created_at,
--           m.rw_message_id
--       ) < (
--           $2::timestamptz,
--           $3::uuid
--       )
--   )
-- ORDER BY
--     m.rw_created_at DESC,
--     m.rw_message_id DESC
-- LIMIT $4;


-- ============================================================
-- CONSULTA 2
-- Búsqueda de mensajes con resaltado
--
-- Esta consulta es parametrizada y será utilizada por el backend.
--
-- Parámetros:
-- $1 = término de búsqueda
-- $2 = límite
-- ============================================================

-- Consulta lógica para el backend:
--
-- SELECT
--     m.rw_message_id,
--     m.rw_channel_id,
--     m.rw_author_id,
--     m.rw_body,
--     ts_headline(
--         'simple',
--         m.rw_body,
--         plainto_tsquery('simple', $1)
--     ) AS highlighted_body,
--     m.rw_created_at
-- FROM public.rw_messages m
-- JOIN public.rw_message_embeddings e
--     ON e.rw_message_id = m.rw_message_id
-- WHERE e.rw_search_vector
--       @@ plainto_tsquery('simple', $1)
--   AND m.rw_deleted_at IS NULL
-- ORDER BY m.rw_created_at DESC
-- LIMIT $2;


-- ============================================================
-- CONSULTA 3
-- Recuperación de contexto para el copiloto
-- CON CONTROL DE PERMISOS EN SQL
--
-- Esta lógica ya está implementada como:
--
-- app.search_rag_context()
--
-- La función recibe:
-- p_query_embedding
-- p_limit
--
-- y utiliza app.current_user_id() para restringir
-- el contexto a los canales permitidos.
-- ============================================================


-- ============================================================
-- CONSULTA 4
-- Consumo acumulado del copiloto por usuario
--
-- Esta lógica está implementada como:
--
-- app.get_copilot_usage()
--
-- El usuario solamente puede consultar su propio consumo.
-- ============================================================


-- ============================================================
-- FUNCIÓN PARA CONSULTAR EL CONSUMO DEL COPILOTO
-- ============================================================

CREATE OR REPLACE FUNCTION app.get_copilot_usage(
    p_user_id uuid
)
RETURNS TABLE (
    rw_user_id uuid,
    total_queries bigint,
    total_tokens bigint
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        q.rw_user_id,
        COUNT(*) AS total_queries,
        COALESCE(
            SUM(q.rw_tokens_used),
            0
        )::bigint AS total_tokens
    FROM public.rw_copilot_queries q
    WHERE q.rw_user_id = p_user_id
      AND q.rw_user_id = app.current_user_id()
    GROUP BY q.rw_user_id;
$$;


GRANT EXECUTE ON FUNCTION app.get_copilot_usage(uuid)
TO rw_app_role;


COMMIT;