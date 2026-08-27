BEGIN;

-- ============================================================
-- 06_procedures.sql
-- Procedimientos almacenados requeridos por el assessment
-- ============================================================


-- ============================================================
-- 1. CONSULTA DE USUARIOS
-- ============================================================
--
-- Devuelve los usuarios mediante un cursor.
--
-- Se excluyen usuarios eliminados lógicamente.
--
-- Uso:
--
-- CALL app.get_users('users_cursor');
-- FETCH ALL FROM users_cursor;
--
-- ============================================================

CREATE OR REPLACE PROCEDURE app.get_users(
    IN p_cursor refcursor
)
LANGUAGE plpgsql
AS $$
BEGIN

    OPEN p_cursor FOR
        SELECT
            rw_user_id,
            rw_email,
            rw_full_name,
            rw_role_title,
            rw_created_at
        FROM public.rw_users
        WHERE rw_deleted_at IS NULL
        ORDER BY rw_full_name;

END;
$$;


-- ============================================================
-- 2. EDICIÓN / ELIMINACIÓN LÓGICA DE USUARIOS
-- ============================================================
--
-- p_action:
--   'UPDATE' → modifica nombre y cargo
--   'DELETE' → realiza soft delete
--
-- Nunca se elimina físicamente un usuario.
--
-- ============================================================

CREATE OR REPLACE PROCEDURE app.manage_user(
    IN p_user_id uuid,
    IN p_action text,
    IN p_full_name text DEFAULT NULL,
    IN p_role_title text DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN

    -- Validamos que la acción sea válida
    IF upper(p_action) NOT IN ('UPDATE', 'DELETE') THEN
        RAISE EXCEPTION
            'Accion no valida. Use UPDATE o DELETE';
    END IF;


    -- ========================================================
    -- ACTUALIZAR USUARIO
    -- ========================================================

    IF upper(p_action) = 'UPDATE' THEN

        IF p_full_name IS NULL
           OR char_length(trim(p_full_name)) = 0 THEN

            RAISE EXCEPTION
                'El nombre del usuario no puede estar vacio';

        END IF;

        IF p_role_title IS NULL
           OR char_length(trim(p_role_title)) = 0 THEN

            RAISE EXCEPTION
                'El cargo del usuario no puede estar vacio';

        END IF;


        UPDATE public.rw_users
        SET
            rw_full_name = trim(p_full_name),
            rw_role_title = trim(p_role_title)
        WHERE rw_user_id = p_user_id
          AND rw_deleted_at IS NULL;


        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Usuario no encontrado o ya eliminado';
        END IF;


    -- ========================================================
    -- ELIMINACIÓN LÓGICA
    -- ========================================================

    ELSIF upper(p_action) = 'DELETE' THEN

        UPDATE public.rw_users
        SET
            rw_deleted_at = now()
        WHERE rw_user_id = p_user_id
          AND rw_deleted_at IS NULL;


        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Usuario no encontrado o ya eliminado';
        END IF;

    END IF;

END;
$$;


-- ============================================================
-- PERMISOS
-- ============================================================

GRANT EXECUTE ON PROCEDURE app.get_users(refcursor)
TO rw_app_role;

GRANT EXECUTE ON PROCEDURE app.manage_user(uuid, text, text, text)
TO rw_app_role;


COMMIT;