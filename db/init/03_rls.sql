BEGIN;

-- ============================================================
-- 1. ESQUEMA PARA FUNCIONES DE SEGURIDAD
-- ============================================================

CREATE SCHEMA IF NOT EXISTS app;

GRANT USAGE ON SCHEMA app TO rw_app_role;


-- ============================================================
-- 2. CONTEXTO DEL USUARIO ACTUAL
-- ============================================================
--
-- El backend establecerá:
--
-- SET LOCAL app.current_user_id = 'UUID_DEL_USUARIO';
--
-- Esta función recupera ese valor.
--
-- current_setting(..., true):
--   - devuelve NULL si la variable no existe
--   - evita que PostgreSQL lance un error
--
-- ============================================================

CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(
        current_setting('app.current_user_id', true),
        ''
    )::uuid;
$$;

GRANT EXECUTE ON FUNCTION app.current_user_id() TO rw_app_role;


-- ============================================================
-- 3. ACTIVAR ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE rw_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE rw_messages ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- 4. RLS - CHANNELS
-- ============================================================
--
-- Un usuario solamente puede consultar canales
-- donde existe una membresía para ese usuario.
--
-- ============================================================

DROP POLICY IF EXISTS channels_select_member
ON rw_channels;

CREATE POLICY channels_select_member
ON rw_channels
FOR SELECT
TO rw_app_role
USING (
    EXISTS (
        SELECT 1
        FROM rw_channel_members cm
        WHERE cm.rw_channel_id = rw_channels.rw_channel_id
          AND cm.rw_user_id = app.current_user_id()
    )
);


-- ============================================================
-- 5. RLS - MESSAGES / SELECT
-- ============================================================
--
-- Un usuario solamente puede leer mensajes de canales
-- donde es miembro.
--
-- También excluimos mensajes con soft delete.
--
-- ============================================================

DROP POLICY IF EXISTS messages_select_member
ON rw_messages;

CREATE POLICY messages_select_member
ON rw_messages
FOR SELECT
TO rw_app_role
USING (
    rw_deleted_at IS NULL
    AND EXISTS (
        SELECT 1
        FROM rw_channel_members cm
        WHERE cm.rw_channel_id = rw_messages.rw_channel_id
          AND cm.rw_user_id = app.current_user_id()
    )
);



-- ============================================================
-- 6. RLS - MESSAGES / INSERT
-- ============================================================
--
-- Para crear un mensaje:
--
-- 1. El usuario debe ser miembro del canal.
-- 2. El autor del mensaje debe ser el usuario actual.
--
-- ============================================================

DROP POLICY IF EXISTS messages_insert_member
ON rw_messages;

CREATE POLICY messages_insert_member
ON rw_messages
FOR INSERT
TO rw_app_role
WITH CHECK (
    rw_author_id = app.current_user_id()
    AND EXISTS (
        SELECT 1
        FROM rw_channel_members cm
        WHERE cm.rw_channel_id = rw_messages.rw_channel_id
          AND cm.rw_user_id = app.current_user_id()
    )
);


-- ============================================================
-- 7. RLS - MESSAGES / UPDATE
-- ============================================================
--
-- Un usuario solamente puede modificar sus propios mensajes
-- y solamente si pertenece al canal.
--
-- ============================================================

DROP POLICY IF EXISTS messages_update_member
ON rw_messages;

CREATE POLICY messages_update_member
ON rw_messages
FOR UPDATE
TO rw_app_role
USING (
    rw_author_id = app.current_user_id()
    AND EXISTS (
        SELECT 1
        FROM rw_channel_members cm
        WHERE cm.rw_channel_id = rw_messages.rw_channel_id
          AND cm.rw_user_id = app.current_user_id()
    )
)
WITH CHECK (
    rw_author_id = app.current_user_id()
);


-- ============================================================
-- 8. RLS - MESSAGES / DELETE
-- ============================================================
--
-- El borrado físico será tratado posteriormente mediante
-- funciones/procedimientos.
--
-- Por ahora permitimos DELETE únicamente sobre mensajes
-- propios y accesibles.
--
-- ============================================================

DROP POLICY IF EXISTS messages_delete_member
ON rw_messages;

CREATE POLICY messages_delete_member
ON rw_messages
FOR DELETE
TO rw_app_role
USING (
    rw_author_id = app.current_user_id()
    AND EXISTS (
        SELECT 1
        FROM rw_channel_members cm
        WHERE cm.rw_channel_id = rw_messages.rw_channel_id
          AND cm.rw_user_id = app.current_user_id()
    )
);


COMMIT;