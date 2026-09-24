-- Actualización automática entre teléfonos.
--
-- Lo que registra un teléfono (un cliente, un abono, una venta, una entrada)
-- no aparecía en los demás hasta refrescar a mano. Con estas tablas en la
-- publicación de Realtime la app se entera del cambio y recarga sola.
--
-- Realtime respeta RLS: cada teléfono solo recibe los cambios que su sesión
-- puede leer, es decir, los de su gimnasio.
do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'users', 'products', 'product_categories', 'ingresos', 'access_logs'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = tabla
    ) then
      execute format('alter publication supabase_realtime add table public.%I', tabla);
    end if;
  end loop;
end $$;
