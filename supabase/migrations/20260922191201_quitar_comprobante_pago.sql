-- =============================================
-- QUITAR EL COMPROBANTE DE PAGO GUARDADO
-- =============================================
-- Revierte 20260921213438_comprobante_pago.sql. La foto del comprobante ya
-- no se guarda: la app solo la usa para leer la referencia por OCR y llenar
-- `ingresos.referencia_pago`, que sigue igual.
--
-- Esa migración ya se aplicó en remoto, por eso se revierte con una nueva en
-- vez de borrar el archivo.
--
-- Idempotente.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Políticas del bucket `comprobantes`
-- ---------------------------------------------------------------
DROP POLICY IF EXISTS "Staff can read gym comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Staff can insert gym comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Staff can update gym comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Staff can delete gym comprobantes" ON storage.objects;
DROP POLICY IF EXISTS "Auth can read comprobantes bucket" ON storage.buckets;


-- ---------------------------------------------------------------
-- 2. La columna en `ingresos`
-- ---------------------------------------------------------------
ALTER TABLE public.ingresos
    DROP CONSTRAINT IF EXISTS ingresos_comprobante_path_not_blank;

ALTER TABLE public.ingresos
    DROP COLUMN IF EXISTS comprobante_path;


-- ---------------------------------------------------------------
-- 3. El bucket
-- ---------------------------------------------------------------
-- Supabase puede bloquear los borrados directos sobre las tablas de storage
-- (hay que pasar por la API). Si ocurre, no se aborta la migración: sin
-- políticas, el bucket privado ya es inaccesible para la app, y queda
-- borrarlo desde el dashboard.
DO $$
BEGIN
    DELETE FROM storage.objects WHERE bucket_id = 'comprobantes';
    DELETE FROM storage.buckets WHERE id = 'comprobantes';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'No se pudo borrar el bucket comprobantes (%). Bórralo desde el dashboard.', SQLERRM;
END
$$;
