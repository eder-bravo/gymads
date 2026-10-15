-- Accesos de personal en vivo.
--
-- Cuando un empleado usaba su código, la pantalla de Accesos de personal del
-- dueño seguía mostrándolo "pendiente" hasta salir y volver a entrar. Con la
-- tabla en la publicación de Realtime, la app se entera del canje (y de lo que
-- otro teléfono cree, revoque o regenere) y recarga sola.
--
-- Realtime respeta RLS: solo reciben estos cambios quienes pueden leer la
-- tabla, es decir, quienes tienen staff_puede('gestionar_accesos_staff')
-- (el dueño y el encargado). El resto del personal no recibe nada.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'staff_accesos'
  ) then
    alter publication supabase_realtime add table public.staff_accesos;
  end if;
end $$;
