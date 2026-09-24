-- El teléfono de cada persona se entera al momento cuando cambia su perfil:
-- si el dueño le cambia el rol, la app muestra el menú del rol nuevo sin
-- cerrar sesión; si le retira el acceso, la app sale.
--
-- Realtime respeta RLS: cada quien solo recibe su propia fila ("Staff can
-- view own profile"). La app además filtra por su user_id, así que el dueño
-- tampoco recibe los cambios de los perfiles de su equipo.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'staff_profiles'
  ) then
    alter publication supabase_realtime add table public.staff_profiles;
  end if;
end $$;
