-- =============================================
-- MIGRATION 021: ELIMINAR QR POR COMPLETO
-- =============================================
-- La app ya no usa códigos QR. Se elimina:
--   • la columna users.qr_code (+ su índice único)
--   • el bucket de storage 'qrcodes' (y sus objetos)
--   • las referencias a 'qrcodes' en las políticas de storage de la 020
--     (quedan solo para el bucket 'users')
--
-- Idempotente y no destructivo de datos vigentes (la BD está pre-lanzamiento).
-- Revisar antes de ejecutar en producción.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Quitar columna qr_code de users (+ índice único de la 004)
-- ---------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_users_branch_qr_code;
ALTER TABLE public.users DROP COLUMN IF EXISTS qr_code;


-- ---------------------------------------------------------------
-- 2. Bucket 'qrcodes': se elimina por la Storage API, NO por SQL.
--    (Supabase bloquea DELETE directo en storage.objects/buckets:
--     "Direct deletion from storage tables is not allowed".)
--    Se hace con la CLI:  supabase storage rm -r ss:///qrcodes
--    o desde el panel de Storage. Ya quedó privado en la 020.
-- ---------------------------------------------------------------


-- ---------------------------------------------------------------
-- 3. Rehacer las políticas de storage: solo bucket 'users'
--    (antes incluían 'qrcodes' — ver migración 020)
-- ---------------------------------------------------------------
DROP POLICY IF EXISTS "Auth can read app storage" ON storage.objects;
CREATE POLICY "Auth can read app storage"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'users');

DROP POLICY IF EXISTS "Auth can insert app storage" ON storage.objects;
CREATE POLICY "Auth can insert app storage"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'users');

DROP POLICY IF EXISTS "Auth can update app storage" ON storage.objects;
CREATE POLICY "Auth can update app storage"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'users')
    WITH CHECK (bucket_id = 'users');

DROP POLICY IF EXISTS "Auth can delete app storage" ON storage.objects;
CREATE POLICY "Auth can delete app storage"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'users');
