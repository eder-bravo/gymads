-- Código del encargado para el abono libre.
--
-- Con costos fijos, el mostrador (y el staff general) necesitan que el
-- encargado escriba un código para cobrar un abono libre; el dueño y el
-- encargado no. Es un solo código por gimnasio (PIN de 4 a 6 números), lo
-- crean el dueño o el encargado y autoriza un solo cobro.
--
-- El PIN es corto: si el mostrador pudiera leer su hash lo adivinaría en
-- segundos. Por eso la tabla no tiene políticas (nadie la lee ni la escribe
-- directo), todo pasa por funciones SECURITY DEFINER y los intentos
-- fallidos se limitan (5 cada 10 minutos por usuario).

create table if not exists public.gym_codigo_abono_libre (
  gym_id uuid primary key references public.gyms(id) on delete cascade,
  pin_hash text not null,
  actualizado_en timestamptz not null default now()
);
alter table public.gym_codigo_abono_libre enable row level security;

create table if not exists public.intentos_codigo_abono_libre (
  id bigserial primary key,
  user_id uuid not null,
  gym_id uuid not null references public.gyms(id) on delete cascade,
  fecha timestamptz not null default now()
);
create index if not exists idx_intentos_codigo_abono_libre_usuario
  on public.intentos_codigo_abono_libre (user_id, fecha desc);
alter table public.intentos_codigo_abono_libre enable row level security;

-- Además de RLS sin políticas: sin permisos de tabla para la app.
revoke all on table public.gym_codigo_abono_libre from anon, authenticated;
revoke all on table public.intentos_codigo_abono_libre from anon, authenticated;

-- Crea, cambia o quita (p_pin null) el código. Solo dueño y encargado.
create or replace function public.guardar_codigo_abono_libre(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_gym uuid := public.current_gym_id();
begin
  if v_gym is null or not public.staff_puede('editar_gimnasio') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_pin is null then
    delete from public.gym_codigo_abono_libre where gym_id = v_gym;
    return;
  end if;
  if p_pin !~ '^[0-9]{4,6}$' then
    raise exception 'codigo_invalido' using errcode = '22023';
  end if;
  insert into public.gym_codigo_abono_libre (gym_id, pin_hash, actualizado_en)
  values (v_gym, crypt(p_pin, gen_salt('bf')), now())
  on conflict (gym_id) do update
    set pin_hash = excluded.pin_hash, actualizado_en = now();
end;
$$;

-- Si el gimnasio ya tiene código (sin revelarlo).
create or replace function public.hay_codigo_abono_libre()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.gym_codigo_abono_libre
     where gym_id = public.current_gym_id()
  );
$$;

-- Comprueba el código para un cobro. Con 5 fallos en 10 minutos, espera.
create or replace function public.autorizar_abono_libre(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_gym uuid := public.current_gym_id();
  v_usuario uuid := auth.uid();
  v_hash text;
  v_fallos int;
begin
  if v_gym is null or v_usuario is null
     or not public.staff_puede('cobrar_abonos') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;

  select count(*) into v_fallos
    from public.intentos_codigo_abono_libre
   where user_id = v_usuario and fecha > now() - interval '10 minutes';
  if v_fallos >= 5 then
    raise exception 'demasiados_intentos' using errcode = 'P0001';
  end if;

  select pin_hash into v_hash
    from public.gym_codigo_abono_libre where gym_id = v_gym;
  if v_hash is null then
    raise exception 'sin_codigo' using errcode = 'P0001';
  end if;

  if p_pin is not null and crypt(p_pin, v_hash) = v_hash then
    delete from public.intentos_codigo_abono_libre where user_id = v_usuario;
    return true;
  end if;

  insert into public.intentos_codigo_abono_libre (user_id, gym_id)
  values (v_usuario, v_gym);
  return false;
end;
$$;

revoke all on function public.guardar_codigo_abono_libre(text) from public, anon;
revoke all on function public.hay_codigo_abono_libre() from public, anon;
revoke all on function public.autorizar_abono_libre(text) from public, anon;
grant execute on function public.guardar_codigo_abono_libre(text) to authenticated;
grant execute on function public.hay_codigo_abono_libre() to authenticated;
grant execute on function public.autorizar_abono_libre(text) to authenticated;
