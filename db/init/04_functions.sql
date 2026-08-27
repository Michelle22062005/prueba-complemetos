BEGIN;

-- ============================================================
-- 1. CREAR MENSAJE
-- ============================================================

CREATE OR REPLACE FUNCTION app.create_message(
    p_channel_id uuid,
    p_body text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_message_id uuid;
BEGIN

    -- Validación básica
    IF p_body IS NULL OR char_length(trim(p_body)) = 0 THEN
        RAISE EXCEPTION 'El mensaje no puede estar vacío';
    END IF;

    -- Insertamos utilizando el usuario actual
    INSERT INTO public.rw_messages (
        rw_channel_id,
        rw_author_id,
        rw_body
    )
    VALUES (
        p_channel_id,
        app.current_user_id(),
        trim(p_body)
    )
    RETURNING rw_message_id INTO v_message_id;

    RETURN v_message_id;

END;
$$;


-- ============================================================
-- 2. EDITAR MENSAJE
-- ============================================================

CREATE OR REPLACE FUNCTION app.edit_message(
    p_message_id uuid,
    p_body text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF p_body IS NULL OR char_length(trim(p_body)) = 0 THEN
        RAISE EXCEPTION 'El mensaje no puede estar vacío';
    END IF;

    UPDATE public.rw_messages
    SET
        rw_body = trim(p_body),
        rw_is_edited = true,
        rw_edited_at = now()
    WHERE rw_message_id = p_message_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    RETURN true;

END;
$$;


-- ============================================================
-- 3. SOFT DELETE DE MENSAJE
-- ============================================================

CREATE OR REPLACE FUNCTION app.delete_message(
    p_message_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    UPDATE public.rw_messages
    SET
        rw_deleted_at = now()
    WHERE rw_message_id = p_message_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    RETURN true;

END;
$$;


-- ============================================================
-- 4. MARCAR MENSAJE COMO LEÍDO
-- ============================================================

CREATE OR REPLACE FUNCTION app.mark_message_read(
    p_message_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    INSERT INTO public.rw_message_status (
        rw_message_id,
        rw_user_id,
        rw_read_at
    )
    VALUES (
        p_message_id,
        app.current_user_id(),
        now()
    )
    ON CONFLICT (rw_message_id, rw_user_id)
    DO UPDATE SET
        rw_read_at = now();

    RETURN true;

END;
$$;


-- ============================================================
-- 5. PERMISOS
-- ============================================================

GRANT EXECUTE ON FUNCTION app.create_message(uuid, text)
TO rw_app_role;

GRANT EXECUTE ON FUNCTION app.edit_message(uuid, text)
TO rw_app_role;

GRANT EXECUTE ON FUNCTION app.delete_message(uuid)
TO rw_app_role;

GRANT EXECUTE ON FUNCTION app.mark_message_read(uuid)
TO rw_app_role;


COMMIT;