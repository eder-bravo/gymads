-- La app solo usa el bucket `users` (fotos de clientes). El de comprobantes se
-- quitó (20260922191201): las políticas de la app seguían incluyéndolo en la
-- base de datos real, aunque el archivo 20260827000107 solo dice 'users'.
-- Se dejan como deben ser: nada puede leer, subir, cambiar ni borrar en otro
-- bucket, aunque el de comprobantes todavía exista.

DROP POLICY IF EXISTS "Auth can read app storage" ON storage.objects;
CREATE POLICY "Auth can read app storage"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can insert app storage" ON storage.objects;
CREATE POLICY "Auth can insert app storage"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can update app storage" ON storage.objects;
CREATE POLICY "Auth can update app storage"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL)
    WITH CHECK (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can delete app storage" ON storage.objects;
CREATE POLICY "Auth can delete app storage"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);
