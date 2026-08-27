-- ============================================================
-- rw_users
-- Soft delete (rw_deleted_at) porque un usuario nunca se borra
-- físicamente: es autor de mensajes y su historial debe preservarse.
-- ============================================================
CREATE TABLE rw_users (
    rw_user_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rw_email         text NOT NULL,
    rw_password_hash text NOT NULL,
    rw_full_name     text NOT NULL,
    rw_role_title    text NOT NULL,
    rw_created_at    timestamptz NOT NULL DEFAULT now(),
    rw_deleted_at    timestamptz,
    CONSTRAINT ck_users_email_not_blank CHECK (char_length(trim(rw_email)) > 0),
    CONSTRAINT ck_users_name_not_blank CHECK (char_length(trim(rw_full_name)) > 0)
);

-- ============================================================
-- rw_channels
-- ============================================================
CREATE TABLE rw_channels (
    rw_channel_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rw_name        text NOT NULL,
    rw_is_private  boolean NOT NULL DEFAULT true,
    rw_created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_channels_name_not_blank CHECK (char_length(trim(rw_name)) > 0)
);

-- ============================================================
-- rw_channel_members (tabla puente N:M users <-> channels)
-- Define quién tiene acceso a un canal: es la tabla que las
-- políticas RLS de rw_channels/rw_messages van a consultar.
-- ON DELETE CASCADE en ambas FK: si el canal o el usuario
-- desaparecen, la membresía deja de tener sentido por sí sola.
-- ============================================================
CREATE TABLE rw_channel_members (
    rw_channel_id      uuid NOT NULL REFERENCES rw_channels(rw_channel_id) ON DELETE CASCADE,
    rw_user_id         uuid NOT NULL REFERENCES rw_users(rw_user_id) ON DELETE CASCADE,
    rw_role_in_channel text NOT NULL DEFAULT 'member',
    rw_joined_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (rw_channel_id, rw_user_id),
    CONSTRAINT ck_channel_members_role CHECK (rw_role_in_channel IN ('member', 'admin'))
);

-- ============================================================
-- rw_messages
-- rw_deleted_at en vez de DELETE físico (requisito explícito).
-- rw_author_id con ON DELETE RESTRICT: no se puede borrar un
-- usuario que sigue siendo autor de mensajes (se fuerza el soft
-- delete de rw_users en su lugar).
-- rw_channel_id con ON DELETE CASCADE: si el canal se elimina
-- de verdad (caso administrativo, no el flujo normal), sus
-- mensajes van con él.
-- ============================================================
CREATE TABLE rw_messages (
    rw_message_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rw_channel_id  uuid NOT NULL REFERENCES rw_channels(rw_channel_id) ON DELETE CASCADE,
    rw_author_id   uuid NOT NULL REFERENCES rw_users(rw_user_id) ON DELETE RESTRICT,
    rw_body        text NOT NULL,
    rw_is_edited   boolean NOT NULL DEFAULT false,
    rw_created_at  timestamptz NOT NULL DEFAULT now(),
    rw_edited_at   timestamptz,
    rw_deleted_at  timestamptz,
    CONSTRAINT ck_messages_body_not_blank CHECK (char_length(trim(rw_body)) > 0)
);

-- ============================================================
-- rw_message_status (estados de lectura por usuario/mensaje)
-- ON DELETE CASCADE: un recibo de lectura no tiene valor propio
-- una vez el mensaje o el usuario desaparecen.
-- ============================================================
CREATE TABLE rw_message_status (
    rw_message_id  uuid NOT NULL REFERENCES rw_messages(rw_message_id) ON DELETE CASCADE,
    rw_user_id     uuid NOT NULL REFERENCES rw_users(rw_user_id) ON DELETE CASCADE,
    rw_read_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (rw_message_id, rw_user_id)
);

-- ============================================================
-- rw_message_embeddings (1:1 con rw_messages, para el RAG)
-- ON DELETE CASCADE: el embedding no existe sin su mensaje.
-- ============================================================
CREATE TABLE rw_message_embeddings (
    rw_message_id    uuid PRIMARY KEY REFERENCES rw_messages(rw_message_id) ON DELETE CASCADE,
    rw_embedding     vector(1536) NOT NULL,
    rw_search_vector tsvector,
    rw_updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- rw_copilot_queries (para la consulta 4: consumo por usuario)
-- ON DELETE CASCADE: el historial de un usuario borrado no se
-- conserva de forma independiente.
-- ============================================================
CREATE TABLE rw_copilot_queries (
    rw_query_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rw_user_id     uuid NOT NULL REFERENCES rw_users(rw_user_id) ON DELETE CASCADE,
    rw_prompt      text NOT NULL,
    rw_response    text,
    rw_tokens_used integer NOT NULL DEFAULT 0,
    rw_created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_copilot_tokens_non_negative CHECK (rw_tokens_used >= 0)
);

-- ============================================================
-- rw_query_sources (tabla puente: citas del copiloto a mensajes fuente)
-- ============================================================
CREATE TABLE rw_query_sources (
    rw_query_id        uuid NOT NULL REFERENCES rw_copilot_queries(rw_query_id) ON DELETE CASCADE,
    rw_message_id      uuid NOT NULL REFERENCES rw_messages(rw_message_id) ON DELETE CASCADE,
    rw_relevance_score numeric(5,4),
    PRIMARY KEY (rw_query_id, rw_message_id),
    CONSTRAINT ck_query_sources_score_range CHECK (
        rw_relevance_score IS NULL OR (rw_relevance_score >= 0 AND rw_relevance_score <= 1)
    )
);

-- ============================================================
-- rw_refresh_tokens
-- ON DELETE CASCADE: los tokens de un usuario borrado no sirven.
-- ============================================================
CREATE TABLE rw_refresh_tokens (
    rw_token_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rw_user_id     uuid NOT NULL REFERENCES rw_users(rw_user_id) ON DELETE CASCADE,
    rw_token_hash  text NOT NULL,
    rw_created_at  timestamptz NOT NULL DEFAULT now(),
    rw_expires_at  timestamptz NOT NULL,
    rw_revoked     boolean NOT NULL DEFAULT false,
    CONSTRAINT ck_refresh_tokens_expiry_future CHECK (rw_expires_at > rw_created_at)
);


-- pgcrypto: gen_random_uuid() para las PK de tipo UUID
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- vector: embeddings para el RAG del copiloto (ya viene compilada en la imagen pgvector/pgvector)
CREATE EXTENSION IF NOT EXISTS vector;



-- Índice único PARCIAL: el correo debe ser único solo entre usuarios
-- activos. Si un usuario se elimina (soft delete), su correo queda
-- libre para que alguien más se registre con él.
CREATE UNIQUE INDEX ux_users_email_active
    ON rw_users (lower(rw_email))
    WHERE rw_deleted_at IS NULL;

-- Apoyo para el listado de canales de un usuario (vista de conversaciones)
CREATE INDEX ix_channel_members_user ON rw_channel_members (rw_user_id);

-- Apoyo para paginación por keyset del historial de un canal
-- (order by rw_created_at, rw_message_id)
CREATE INDEX ix_messages_channel_created
    ON rw_messages (rw_channel_id, rw_created_at, rw_message_id)
    WHERE rw_deleted_at IS NULL;

-- Apoyo para el consumo acumulado del copiloto por usuario (consulta 4)
CREATE INDEX ix_copilot_queries_user ON rw_copilot_queries (rw_user_id);

-- Índice vectorial (ivfflat) para la búsqueda semántica del RAG.
-- lists=100 es un punto de partida razonable para un dataset pequeño;
-- ajústalo según el volumen real de mensajes.
CREATE INDEX ix_message_embeddings_vector
    ON rw_message_embeddings USING ivfflat (rw_embedding vector_cosine_ops)
    WITH (lists = 100);

-- Índice GIN para la búsqueda de texto (Consulta 2: resaltado del término)
CREATE INDEX ix_message_embeddings_search
    ON rw_message_embeddings USING gin (rw_search_vector);





-- Rol de aplicación: el backend se conecta con este rol, NUNCA con el
-- superusuario del contenedor. Al no tener BYPASSRLS, queda sujeto a
-- todas las políticas RLS que se definan sobre rw_channels y rw_messages.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rw_app_role') THEN
        CREATE ROLE rw_app_role WITH LOGIN PASSWORD 'change_me_local_only' NOBYPASSRLS;
    END IF;
END
$$;

-- Permisos mínimos: puede operar sobre los datos, no puede alterar el esquema
GRANT CONNECT ON DATABASE bd_danna_oyola_thompson TO rw_app_role;
GRANT USAGE ON SCHEMA public TO rw_app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rw_app_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO rw_app_role;

-- Para que las tablas que se creen DESPUÉS también hereden estos permisos
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rw_app_role;
