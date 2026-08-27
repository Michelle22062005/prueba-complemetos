BEGIN;

CREATE OR REPLACE FUNCTION app.sync_message_search_vector()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE public.rw_message_embeddings
    SET
        rw_search_vector =
            CASE
                WHEN NEW.rw_deleted_at IS NULL
                THEN to_tsvector(
                    'simple',
                    COALESCE(NEW.rw_body, '')
                )
                ELSE NULL
            END,
        rw_updated_at = now()
    WHERE rw_message_id = NEW.rw_message_id;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_sync_message_search_vector
ON public.rw_messages;

CREATE TRIGGER trg_sync_message_search_vector
AFTER INSERT OR UPDATE OF rw_body, rw_deleted_at
ON public.rw_messages
FOR EACH ROW
EXECUTE FUNCTION app.sync_message_search_vector();


-- Sincronizar registros existentes
UPDATE public.rw_message_embeddings e
SET
    rw_search_vector =
        CASE
            WHEN m.rw_deleted_at IS NULL
            THEN to_tsvector(
                'simple',
                COALESCE(m.rw_body, '')
            )
            ELSE NULL
        END,
    rw_updated_at = now()
FROM public.rw_messages m
WHERE m.rw_message_id = e.rw_message_id;


GRANT EXECUTE ON FUNCTION app.sync_message_search_vector()
TO rw_app_role;

COMMIT;



-- ============================================================
-- Consulta 3: recuperación de contexto para el copiloto
-- Solo recupera mensajes de canales donde el actor autenticado
-- es miembro.
-- ============================================================

CREATE OR REPLACE FUNCTION app.search_rag_context(
    p_query_embedding vector(1536),
    p_limit integer DEFAULT 5
)
RETURNS TABLE (
    rw_message_id uuid,
    rw_channel_id uuid,
    channel_name text,
    rw_author_id uuid,
    author_name text,
    rw_body text,
    rw_created_at timestamptz,
    relevance_score double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        m.rw_message_id,
        m.rw_channel_id,
        c.rw_name AS channel_name,
        m.rw_author_id,
        u.rw_full_name AS author_name,
        m.rw_body,
        m.rw_created_at,
        (1 - (e.rw_embedding <=> p_query_embedding))::double precision
            AS relevance_score
    FROM public.rw_messages m
    INNER JOIN public.rw_channels c
        ON c.rw_channel_id = m.rw_channel_id
    INNER JOIN public.rw_users u
        ON u.rw_user_id = m.rw_author_id
    INNER JOIN public.rw_message_embeddings e
        ON e.rw_message_id = m.rw_message_id
    WHERE m.rw_deleted_at IS NULL
      AND EXISTS (
          SELECT 1
          FROM public.rw_channel_members cm
          WHERE cm.rw_channel_id = m.rw_channel_id
            AND cm.rw_user_id = app.current_user_id()
      )
    ORDER BY e.rw_embedding <=> p_query_embedding
    LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION app.search_rag_context(vector(1536), integer)
TO rw_app_role;