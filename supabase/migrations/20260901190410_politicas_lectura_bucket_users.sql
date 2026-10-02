-- Dejar que la app resuelva el bucket 'users'.
--
-- HALLAZGO:
--   storage.buckets tiene RLS activo (lo trae el esquema de Supabase) pero
--   ninguna migración le puso políticas. Medido contra la base real, tanto el
--   dueño como un empleado ven CERO buckets:
--
--     SET LOCAL role authenticated;  -- con el sub de cualquiera de los dos
--     SELECT count(*) FROM storage.buckets;  -->  0
--
--   El bucket 'users' es privado desde 020_private_buckets.sql, así que su URL
--   pública devuelve 400 y la app solo puede mostrar fotos con
--   createSignedUrl. Firmar exige resolver antes el bucket, de modo que sin
--   una política de lectura sobre storage.buckets la firma queda expuesta a
--   fallar y las fotos se caen a las iniciales sin más aviso.
--
--   Las políticas de storage.objects (20260827000107 §7.a) ya estaban bien;
--   lo que faltaba era su equivalente sobre los buckets.
--
-- Se concede SELECT únicamente sobre 'users', y solo a quien ya tiene contexto
-- de gimnasio: la misma condición que guarda los objetos, para no reabrir lo
-- que cerró 20260827000518.

DROP POLICY IF EXISTS "Auth can read users bucket" ON storage.buckets;
CREATE POLICY "Auth can read users bucket"
    ON storage.buckets FOR SELECT
    TO authenticated
    USING (id = 'users' AND public.current_gym_id() IS NOT NULL);
