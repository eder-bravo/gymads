-- Recorridos guiados del personal: por ROL y pantalla, no solo por pantalla.
--
-- Con la cuenta solo por pantalla, alguien que fue Encargado (que ve todas las
-- pantallas) y pasa a Almacén no veía nada: Inventario ya contaba como visto.
-- Pero un rol que nunca usó debe enseñarle sus recorridos, y regresar a un rol
-- que ya tuvo, no. Ahora cada entrada de `staff_accesos.tours_vistos` es
-- 'rol:recorrido' (p. ej. 'almacen:inventario'):
--   - empleado nuevo: nada visto, ve los recorridos de su rol;
--   - código nuevo: la misma fila, no vuelve a ver nada;
--   - rol que nunca usó: ve los recorridos de ese rol;
--   - de regreso a un rol que ya tuvo: ya estaban vistos.

-- Las funciones cambian de forma: se borran las anteriores para que no haya
-- dos candidatas al llamarlas sin parámetros.
drop function if exists public.mis_tours_vistos();
drop function if exists public.marcar_tour_visto(text);

-- Los recorridos que quien llama ya vio con el rol [p_rol] (por defecto, su
-- rol actual), sin el prefijo. NULL si no es un empleado con acceso (el dueño,
-- que se guarda en su teléfono).
--
-- p_rol es opcional para que la versión anterior de la app, que no lo manda,
-- siga funcionando.
create function public.mis_tours_vistos(p_rol text default null)
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select array(
    select substr(t, length(coalesce(p_rol, a.role)) + 2)
    from unnest(a.tours_vistos) t
    where left(t, length(coalesce(p_rol, a.role)) + 1) = coalesce(p_rol, a.role) || ':'
  )
  from public.staff_accesos a
  where a.user_id = auth.uid()
  limit 1;
$$;

-- Da por visto un recorrido de quien llama, con el rol [p_rol] (por defecto,
-- su rol actual). La app manda el rol con el que lo mostró: si el dueño le
-- cambió el rol en ese momento, cuenta el que vio. Solo toca su propia fila.
create function public.marcar_tour_visto(p_tour text, p_rol text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_tour is null or p_tour !~ '^[a-z_]{1,40}$' then
    raise exception 'Recorrido inválido';
  end if;
  if p_rol is not null and p_rol !~ '^[a-z_]{1,40}$' then
    raise exception 'Rol inválido';
  end if;

  update public.staff_accesos a
  set tours_vistos = array_append(
        a.tours_vistos, coalesce(p_rol, a.role) || ':' || p_tour)
  where a.user_id = auth.uid()
    and not ((coalesce(p_rol, a.role) || ':' || p_tour) = any (a.tours_vistos));
end;
$$;

-- Los datos, al formato nuevo.
--
-- La migración anterior marcó TODO como visto a quien ya trabajaba, incluso
-- las pantallas que su rol no tiene. Se corrige: solo las pantallas de su rol,
-- vistas con ese rol. Las pantallas de cada rol son las de kPermisosPorRol
-- (lib/app/core/permissions/permissions.dart) según el permiso que abre cada
-- módulo (HomeController.permisoPorModulo); Inicio y Configuración, todos.
update public.staff_accesos a
set tours_vistos = array(
  select a.role || ':' || t
  from unnest(case a.role
    when 'mostrador' then array[
      'home', 'clientes', 'abonar', 'punto_de_venta',
      'ingresos', 'entradas', 'configuracion'
    ]
    when 'almacen' then array['home', 'inventario', 'configuracion']
    else array[
      'home', 'clientes', 'abonar', 'punto_de_venta',
      'inventario', 'ingresos', 'entradas', 'configuracion'
    ]
  end) t
)
where a.tours_vistos @> array[
  'home', 'clientes', 'abonar', 'punto_de_venta',
  'inventario', 'ingresos', 'entradas', 'configuracion'
];

-- Lo que alguien vio después, aún sin rol: se le pone su rol actual.
update public.staff_accesos a
set tours_vistos = array(
  select case when strpos(t, ':') > 0 then t else a.role || ':' || t end
  from unnest(a.tours_vistos) t
)
where exists (
  select 1 from unnest(a.tours_vistos) t where strpos(t, ':') = 0
);
