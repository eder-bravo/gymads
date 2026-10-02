-- Recorridos guiados del personal: se recuerdan por persona, no por teléfono.
--
-- Antes vivían en el disco de cada teléfono y el canje de un código los
-- marcaba TODOS como pendientes. Regenerarle el código a alguien (que borra
-- su staff_profiles y su usuario anónimo) le volvía a mostrar todo.
--
-- La identidad estable de un empleado es su fila de staff_accesos: sobrevive
-- a los códigos nuevos y a los cambios de rol. Ahí se guardan los recorridos
-- (uno por pantalla) que ya vio:
--   - empleado nuevo: ninguno visto, ve cada recorrido una vez;
--   - código nuevo: la misma fila, no vuelve a ver nada;
--   - cambio a un rol que nunca usó: las pantallas nuevas tienen su recorrido
--     pendiente; al regresar a un rol anterior, sus pantallas ya estaban vistas.
--
-- Los ids son los de AppTours (lib/app/data/services/welcome_tour_service.dart).
alter table public.staff_accesos
  add column if not exists tours_vistos text[] not null default '{}';

-- Quien ya trabajaba con la app no es "nuevo": no debe ver los recorridos de
-- golpe con la actualización. Los accesos pendientes (aún sin canjear) sí se
-- tratan como nuevos.
update public.staff_accesos
set tours_vistos = array[
  'home', 'clientes', 'abonar', 'punto_de_venta',
  'inventario', 'ingresos', 'entradas', 'configuracion'
]
where estado <> 'pendiente';

-- Los recorridos ya vistos por quien llama. NULL si no es un empleado con
-- acceso (el dueño, que se guarda en su teléfono). El empleado no puede leer
-- staff_accesos por RLS: por eso es SECURITY DEFINER y solo devuelve su fila.
create or replace function public.mis_tours_vistos()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select tours_vistos
  from public.staff_accesos
  where user_id = auth.uid()
  limit 1;
$$;

-- Da por visto un recorrido de quien llama. Solo toca su propia fila.
create or replace function public.marcar_tour_visto(p_tour text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_tour is null or p_tour !~ '^[a-z_]{1,40}$' then
    raise exception 'Recorrido inválido';
  end if;

  update public.staff_accesos
  set tours_vistos = array_append(tours_vistos, p_tour)
  where user_id = auth.uid()
    and not (p_tour = any (tours_vistos));
end;
$$;
