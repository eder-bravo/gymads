-- =============================================
-- COMPROBANTE DE PAGO (foto del recibo de transferencia)
-- =============================================
-- Al cobrar por transferencia o tarjeta ya se puede anotar la referencia
-- (`ingresos.referencia_pago`, de 20260817000000). Esto añade la foto del
-- comprobante, que además es de donde se lee la referencia por OCR.
--
-- Idempotente.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Dónde quedó guardada la foto
-- ---------------------------------------------------------------
-- Se guarda el PATH del objeto, no la URL.
--
-- El bucket es privado, así que las URLs públicas no resuelven: hay que
-- firmarlas al vuelo. `StorageService._parse` acepta tanto URLs como paths
-- crudos, y el path es lo único que no caduca ni depende del dominio.
ALTER TABLE public.ingresos
    ADD COLUMN IF NOT EXISTS comprobante_path text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ingresos_comprobante_path_not_blank'
          AND conrelid = 'public.ingresos'::regclass
    ) THEN
        ALTER TABLE public.ingresos
            ADD CONSTRAINT ingresos_comprobante_path_not_blank
            CHECK (comprobante_path IS NULL OR btrim(comprobante_path) <> '');
    END IF;
END
$$;

COMMENT ON COLUMN public.ingresos.comprobante_path IS
    'Path en el bucket `comprobantes` de la foto del recibo. NULL en cobros
     en efectivo o sin comprobante a la mano. Se firma al leerlo.';


-- ---------------------------------------------------------------
-- 2. El bucket, privado
-- ---------------------------------------------------------------
-- Aparte del bucket `users`: ahí viven las fotos de perfil de los clientes,
-- y un comprobante bancario es otra cosa. Mezclarlos obligaría a que
-- cualquier permiso sobre uno alcanzara al otro.
INSERT INTO storage.buckets (id, name, public)
VALUES ('comprobantes', 'comprobantes', false)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = false;


-- ---------------------------------------------------------------
-- 3. Políticas sobre los objetos
-- ---------------------------------------------------------------
-- Cada objeto vive bajo `comprobantes/{gym_id}/{archivo}` dentro del bucket.
-- Además de exigir un perfil activo, se compara esa carpeta con el gimnasio
-- de la sesión. Así conocer el path de otro gimnasio no permite leerlo.
--
-- Estas políticas son independientes de las del bucket `users`: ampliarlas
-- con un OR haría más difícil razonar sobre ambos buckets y podría debilitar
-- accidentalmente las reglas existentes de fotos de clientes.
DROP POLICY IF EXISTS "Staff can read gym comprobantes" ON storage.objects;
CREATE POLICY "Staff can read gym comprobantes"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'comprobantes'
        AND (storage.foldername(name))[1] = 'comprobantes'
        AND (storage.foldername(name))[2] = public.current_gym_id()::text
        AND public.staff_puede('ver_ingresos')
    );

DROP POLICY IF EXISTS "Staff can insert gym comprobantes" ON storage.objects;
CREATE POLICY "Staff can insert gym comprobantes"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'comprobantes'
        AND (storage.foldername(name))[1] = 'comprobantes'
        AND (storage.foldername(name))[2] = public.current_gym_id()::text
        AND (public.staff_puede('cobrar_abonos')
             OR public.staff_puede('vender'))
    );

DROP POLICY IF EXISTS "Staff can update gym comprobantes" ON storage.objects;
CREATE POLICY "Staff can update gym comprobantes"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'comprobantes'
        AND (storage.foldername(name))[1] = 'comprobantes'
        AND (storage.foldername(name))[2] = public.current_gym_id()::text
        AND (public.staff_puede('cobrar_abonos')
             OR public.staff_puede('vender'))
    )
    WITH CHECK (
        bucket_id = 'comprobantes'
        AND (storage.foldername(name))[1] = 'comprobantes'
        AND (storage.foldername(name))[2] = public.current_gym_id()::text
        AND (public.staff_puede('cobrar_abonos')
             OR public.staff_puede('vender'))
    );

DROP POLICY IF EXISTS "Staff can delete gym comprobantes" ON storage.objects;
CREATE POLICY "Staff can delete gym comprobantes"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'comprobantes'
        AND (storage.foldername(name))[1] = 'comprobantes'
        AND (storage.foldername(name))[2] = public.current_gym_id()::text
        AND (public.staff_puede('cobrar_abonos')
             OR public.staff_puede('vender'))
    );


-- ---------------------------------------------------------------
-- 4. La política que se olvida: poder VER el bucket
-- ---------------------------------------------------------------
-- Sin permiso de lectura sobre `storage.buckets`, `createSignedUrl` falla:
-- no puede resolver el bucket y la imagen no se muestra nunca, sin un error
-- que apunte a la causa. Ya pasó con `users` y lo arregló 20260901190410;
-- este es el mismo paso para el bucket nuevo.
DROP POLICY IF EXISTS "Auth can read comprobantes bucket" ON storage.buckets;
CREATE POLICY "Auth can read comprobantes bucket"
    ON storage.buckets FOR SELECT
    TO authenticated
    USING (id = 'comprobantes'
           AND public.current_gym_id() IS NOT NULL);
