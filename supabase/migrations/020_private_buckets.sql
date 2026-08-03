-- =============================================
-- MIGRATION 020: BUCKETS PRIVADOS + URLs FIRMADAS
-- =============================================
-- ⚠️  REVISAR ANTES DE EJECUTAR EN PRODUCCIÓN.
--
-- PROBLEMA (auditoría, crítico C2/C6):
--   Los buckets 'users' (fotos de clientes) y 'qrcodes' eran PÚBLICOS: cualquiera
--   con la URL podía leer las fotos de clientes de CUALQUIER gimnasio.
--
-- SOLUCIÓN:
--   1. Volver los buckets privados.
--   2. Solo usuarios AUTENTICADOS pueden leer/escribir vía la API de Storage.
--   3. La app ya no usa URLs públicas: genera URLs firmadas de corta duración
--      (StorageService.signedUrl) y descarga los QR con la API autenticada.
--
-- AISLAMIENTO POR TENANT:
--   El path actual de las fotos (`users/{userId}.jpg`) no incluye gym_id/branch_id,
--   así que el scoping fino por gimnasio en el path es un paso posterior (requeriría
--   cambiar la convención de rutas y mover archivos). El aislamiento efectivo hoy lo
--   da la RLS de la tabla `users`: un staff solo obtiene los `photoUrl` de su sucursal,
--   por lo que solo puede firmar rutas de sus propios clientes. Esto ELIMINA la
--   exposición pública, que era el riesgo crítico.
--
-- Idempotente. Ejecutar en el SQL Editor de Supabase o vía CLI.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Volver los buckets privados
-- ---------------------------------------------------------------
UPDATE storage.buckets SET public = false WHERE id IN ('users', 'qrcodes');


-- ---------------------------------------------------------------
-- 2. Eliminar políticas antiguas (públicas / atadas a user_id fijo)
-- ---------------------------------------------------------------
DROP POLICY IF EXISTS "Acceso público de lectura" ON storage.objects;
DROP POLICY IF EXISTS "Usuario autorizado puede administrar archivos" ON storage.objects;
DROP POLICY IF EXISTS "QR codes son accesibles públicamente" ON storage.objects;
DROP POLICY IF EXISTS "Staff puede subir QR codes" ON storage.objects;
DROP POLICY IF EXISTS "Staff puede actualizar QR codes" ON storage.objects;
DROP POLICY IF EXISTS "Staff puede eliminar QR codes" ON storage.objects;


-- ---------------------------------------------------------------
-- 3. Nuevas políticas: solo autenticados, sobre los buckets de la app
-- ---------------------------------------------------------------
-- (Nombres nuevos con DROP IF EXISTS para que la migración sea idempotente.)

-- Lectura (SELECT) — necesaria para createSignedUrl y para download() de QR
DROP POLICY IF EXISTS "Auth can read app storage" ON storage.objects;
CREATE POLICY "Auth can read app storage"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id IN ('users', 'qrcodes'));

-- Subir (INSERT)
DROP POLICY IF EXISTS "Auth can insert app storage" ON storage.objects;
CREATE POLICY "Auth can insert app storage"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id IN ('users', 'qrcodes'));

-- Actualizar (UPDATE) — para upsert de fotos/QR
DROP POLICY IF EXISTS "Auth can update app storage" ON storage.objects;
CREATE POLICY "Auth can update app storage"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id IN ('users', 'qrcodes'))
    WITH CHECK (bucket_id IN ('users', 'qrcodes'));

-- Eliminar (DELETE) — para borrar foto/QR al actualizar o eliminar cliente
DROP POLICY IF EXISTS "Auth can delete app storage" ON storage.objects;
CREATE POLICY "Auth can delete app storage"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id IN ('users', 'qrcodes'));


-- ---------------------------------------------------------------
-- 4. (Opcional a futuro) Scoping por tenant en el path
-- ---------------------------------------------------------------
-- Cuando se migren las rutas a `{gym_id}/{userId}.jpg`, endurecer así
-- (requiere que el path empiece por el gym del usuario):
--
--   USING (
--     bucket_id = 'users'
--     AND (storage.foldername(name))[1] = public.current_gym_id()::text
--   )
