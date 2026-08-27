BEGIN;

-- ============================================================
-- 1. USERS
-- ============================================================

INSERT INTO rw_users (
    rw_user_id,
    rw_email,
    rw_password_hash,
    rw_full_name,
    rw_role_title
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'ana@riwi.io',
    crypt('Password123!', gen_salt('bf')),
    'Ana Martinez',
    'Backend Developer'
),
(
    '22222222-2222-2222-2222-222222222222',
    'carlos@riwi.io',
    crypt('Password123!', gen_salt('bf')),
    'Carlos Gomez',
    'Frontend Developer'
),
(
    '33333333-3333-3333-3333-333333333333',
    'laura@riwi.io',
    crypt('Password123!', gen_salt('bf')),
    'Laura Rodriguez',
    'Data Analyst'
)
ON CONFLICT (rw_user_id) DO NOTHING;


-- ============================================================
-- 2. CHANNELS
-- ============================================================

INSERT INTO rw_channels (
    rw_channel_id,
    rw_name,
    rw_is_private
)
VALUES
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'General',
    false
),
(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Backend',
    true
),
(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Frontend',
    true
),
(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Data',
    true
)
ON CONFLICT (rw_channel_id) DO NOTHING;


-- ============================================================
-- 3. CHANNEL MEMBERS
-- ============================================================

INSERT INTO rw_channel_members (
    rw_channel_id,
    rw_user_id,
    rw_role_in_channel
)
VALUES

-- General
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'admin'
),
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '22222222-2222-2222-2222-222222222222',
    'member'
),
(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '33333333-3333-3333-3333-333333333333',
    'member'
),

-- Backend
(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'admin'
),
(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    'member'
),

-- Frontend
(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '22222222-2222-2222-2222-222222222222',
    'admin'
),
(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '33333333-3333-3333-3333-333333333333',
    'member'
),

-- Data
(
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '33333333-3333-3333-3333-333333333333',
    'admin'
)

ON CONFLICT (rw_channel_id, rw_user_id) DO NOTHING;


-- ============================================================
-- 4. MESSAGES
-- ============================================================

INSERT INTO rw_messages (
    rw_message_id,
    rw_channel_id,
    rw_author_id,
    rw_body,
    rw_created_at
)
VALUES

-- ----------------------------
-- GENERAL
-- ----------------------------

(
    '10000000-0000-0000-0000-000000000001',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111111',
    'Bienvenidos al canal General.',
    '2026-08-25 09:00:00-05'
),
(
    '10000000-0000-0000-0000-000000000002',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '22222222-2222-2222-2222-222222222222',
    'Gracias Ana. Estoy listo para comenzar el proyecto.',
    '2026-08-25 09:05:00-05'
),
(
    '10000000-0000-0000-0000-000000000003',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '33333333-3333-3333-3333-333333333333',
    'Yo estare trabajando en la parte de datos.',
    '2026-08-25 09:10:00-05'
),

-- ----------------------------
-- BACKEND
-- ----------------------------

(
    '20000000-0000-0000-0000-000000000001',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'El backend utilizara PostgreSQL como base de datos principal.',
    '2026-08-25 10:00:00-05'
),
(
    '20000000-0000-0000-0000-000000000002',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    'Tambien debemos implementar autenticacion mediante JWT.',
    '2026-08-25 10:05:00-05'
),
(
    '20000000-0000-0000-0000-000000000003',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'La autorizacion debe validarse dentro de PostgreSQL mediante RLS.',
    '2026-08-25 10:10:00-05'
),

-- ----------------------------
-- FRONTEND
-- ----------------------------

(
    '30000000-0000-0000-0000-000000000001',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '22222222-2222-2222-2222-222222222222',
    'El frontend sera construido con Next.js.',
    '2026-08-25 11:00:00-05'
),
(
    '30000000-0000-0000-0000-000000000002',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '33333333-3333-3333-3333-333333333333',
    'La interfaz debe ser responsive para escritorio y movil.',
    '2026-08-25 11:05:00-05'
),

-- ----------------------------
-- DATA
-- ----------------------------

(
    '40000000-0000-0000-0000-000000000001',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '33333333-3333-3333-3333-333333333333',
    'El copiloto utilizara embeddings para realizar busquedas semanticas.',
    '2026-08-25 12:00:00-05'
),
(
    '40000000-0000-0000-0000-000000000002',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '33333333-3333-3333-3333-333333333333',
    'Los mensajes accesibles deben utilizarse como contexto para el RAG.',
    '2026-08-25 12:05:00-05'
)

ON CONFLICT (rw_message_id) DO NOTHING;


-- ============================================================
-- 5. MESSAGE STATUS
-- ============================================================

INSERT INTO rw_message_status (
    rw_message_id,
    rw_user_id,
    rw_read_at
)
VALUES
(
    '10000000-0000-0000-0000-000000000001',
    '22222222-2222-2222-2222-222222222222',
    '2026-08-25 09:06:00-05'
),
(
    '10000000-0000-0000-0000-000000000001',
    '33333333-3333-3333-3333-333333333333',
    '2026-08-25 09:11:00-05'
),
(
    '20000000-0000-0000-0000-000000000001',
    '22222222-2222-2222-2222-222222222222',
    '2026-08-25 10:06:00-05'
)
ON CONFLICT (rw_message_id, rw_user_id) DO NOTHING;


COMMIT;