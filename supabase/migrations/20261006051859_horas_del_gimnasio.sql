-- Una sola forma de guardar las horas de entradas y cobros.
--
-- La app guarda la hora del gimnasio sin zona (`DateTime.now()` de México),
-- así que en la base queda escrita como si fuera UTC: una entrada de las
-- 4:23 p. m. se guarda como 16:23+00. Las pantallas la muestran tal cual y
-- las consultas de "hoy" la buscan igual.
--
-- Dos cosas del servidor usaban la hora UTC real (`now()`), 6 horas adelante:
--   - registrar_visita: una visita de las 4:23 p. m. salía a las 10:23 p. m.
--     y, cobrada después de las 6 p. m., quedaba en el día siguiente.
--   - el límite de una entrada por jornada: calculaba el día con 6 horas de
--     diferencia. Quien vino en la noche y regresaba antes de las 7 a. m. era
--     rechazado ("ya fue registrada en esta jornada").
--
-- Aquí todo pasa a la forma de la app: la hora del gimnasio
-- (America/Monterrey) escrita como UTC.

-- La hora del gimnasio, escrita como la guarda la app.
create or replace function public.hora_del_gimnasio()
returns timestamptz
language sql
stable
set search_path = public, pg_temp
as $$
  select (now() at time zone 'America/Monterrey') at time zone 'UTC';
$$;

comment on function public.hora_del_gimnasio() is
  'Hora del gimnasio (America/Monterrey) escrita como UTC, como la guarda la app.';

-- Si alguna vez falta la hora, la del gimnasio, no la UTC real.
alter table public.access_logs
  alter column access_time set default public.hora_del_gimnasio();
alter table public.ingresos
  alter column fecha set default public.hora_del_gimnasio();

-- Visita: igual que antes, con la hora del gimnasio.
create or replace function public.registrar_visita(
  p_nombre      text,
  p_monto       numeric,
  p_metodo_pago text,
  p_referencia  text,
  p_staff       text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_gym     uuid := public.current_gym_id();
  v_branch  uuid := public.current_branch_id();
  v_nombre  text := nullif(btrim(coalesce(p_nombre, '')), '');
  v_ahora   timestamptz := public.hora_del_gimnasio();
  v_mostrar text;
  v_ref     text;
  v_id      uuid;
begin
  if v_gym is null or not public.staff_puede('cobrar_abonos') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_monto is null or p_monto <= 0 then
    raise exception 'monto_invalido' using errcode = '22023';
  end if;
  if p_metodo_pago is null or p_metodo_pago not in
      ('efectivo', 'tarjeta_debito', 'tarjeta_credito', 'transferencia') then
    raise exception 'metodo_invalido' using errcode = '22023';
  end if;

  v_mostrar := case when v_nombre is null then 'Visita'
                    else 'Visita · ' || left(v_nombre, 80) end;
  -- La referencia solo tiene sentido con tarjeta o transferencia.
  v_ref := case when p_metodo_pago = 'efectivo' then null
                else nullif(btrim(coalesce(p_referencia, '')), '') end;

  insert into public.ingresos (
    cliente_id, cliente_nombre, concepto, tipo_membresia,
    monto_base, subtotal, monto_final, metodo_pago, referencia_pago,
    usuario_staff, venta_tipo, fecha, gym_id, branch_id
  ) values (
    null, v_mostrar, 'visita', 'Visita',
    p_monto, p_monto, p_monto, p_metodo_pago, v_ref,
    coalesce(nullif(btrim(coalesce(p_staff, '')), ''), 'Staff'), 'visita', v_ahora,
    v_gym, v_branch
  )
  returning id into v_id;

  insert into public.access_logs (
    user_id, user_name, user_number, access_type, method, staff_user,
    access_time, gym_id, branch_id
  ) values (
    null, v_mostrar, '', 'entrada', 'visita',
    coalesce(nullif(btrim(coalesce(p_staff, '')), ''), 'Staff'),
    v_ahora, v_gym, v_branch
  );

  return v_id;
end;
$$;

revoke all on function public.registrar_visita(text, numeric, text, text, text)
  from public, anon;
grant execute on function public.registrar_visita(text, numeric, text, text, text)
  to authenticated;

-- Una entrada (y una salida) por jornada, contando la jornada con la hora del
-- gimnasio tal como se guardó. La jornada cambia a la 1:00 a. m.
CREATE OR REPLACE FUNCTION public.validar_access_log_jornada()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inicio_jornada timestamptz;
  v_fin_jornada timestamptz;
  v_dia_local date;
  v_registrar_salidas boolean := false;
  v_tiene_entrada boolean := false;
  v_tiene_salida boolean := false;
  v_clave_bloqueo text;
BEGIN
  -- Los históricos pueden tener user_id nulo tras eliminar un cliente. No
  -- participan en el control de pases de un cliente existente.
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  NEW.access_time := COALESCE(NEW.access_time, public.hora_del_gimnasio());
  -- La hora guardada YA es la del gimnasio (escrita como UTC): se lee tal
  -- cual, sin pasarla otra vez a America/Monterrey.
  v_dia_local :=
    ((NEW.access_time AT TIME ZONE 'UTC') - interval '1 hour')::date;
  v_inicio_jornada :=
    ((v_dia_local::timestamp + interval '1 hour') AT TIME ZONE 'UTC');
  v_fin_jornada := v_inicio_jornada + interval '1 day';

  -- Serializa los intentos del mismo cliente/sucursal/jornada. De esta forma
  -- dos apps que consultaron al mismo tiempo no pueden insertar dos entradas.
  v_clave_bloqueo := concat_ws(
    ':',
    COALESCE(NEW.branch_id::text, NEW.gym_id::text, 'sin_sucursal'),
    NEW.user_id::text,
    v_dia_local::text
  );
  PERFORM pg_advisory_xact_lock(hashtextextended(v_clave_bloqueo, 0));

  SELECT COALESCE((
    SELECT g.registrar_salidas
      FROM public.gyms AS g
     WHERE g.id = NEW.gym_id
     LIMIT 1
  ), false)
    INTO v_registrar_salidas;

  SELECT
    COALESCE(bool_or(al.access_type = 'entrada'), false),
    COALESCE(bool_or(al.access_type = 'salida'), false)
    INTO v_tiene_entrada, v_tiene_salida
    FROM public.access_logs AS al
   WHERE al.user_id = NEW.user_id
     AND al.branch_id IS NOT DISTINCT FROM NEW.branch_id
     AND al.access_time >= v_inicio_jornada
     AND al.access_time < v_fin_jornada;

  IF NEW.access_type = 'entrada' THEN
    IF v_tiene_entrada OR v_tiene_salida THEN
      RAISE EXCEPTION 'La entrada de este cliente ya fue registrada en esta jornada'
        USING ERRCODE = '23505', CONSTRAINT = 'access_logs_una_entrada_por_jornada';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.access_type = 'salida' THEN
    IF NOT v_registrar_salidas THEN
      RAISE EXCEPTION 'Este gimnasio no tiene activado el registro de salidas'
        USING ERRCODE = '23514', CONSTRAINT = 'access_logs_salidas_activadas';
    END IF;
    IF NOT v_tiene_entrada THEN
      RAISE EXCEPTION 'No se puede registrar una salida sin una entrada previa'
        USING ERRCODE = '23514', CONSTRAINT = 'access_logs_salida_requiere_entrada';
    END IF;
    IF v_tiene_salida THEN
      RAISE EXCEPTION 'La salida de este cliente ya fue registrada en esta jornada'
        USING ERRCODE = '23505', CONSTRAINT = 'access_logs_una_salida_por_jornada';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Las visitas ya guardadas con la hora UTC real, a la hora del gimnasio.
-- Solo las que guardó registrar_visita: su hora es idéntica a su created_at
-- (las dos son el now() de la misma transacción). Así, correr esto otra vez
-- no las vuelve a mover.
update public.access_logs
   set access_time = (access_time at time zone 'America/Monterrey') at time zone 'UTC'
 where method = 'visita'
   and user_id is null
   and access_time = created_at;

update public.ingresos
   set fecha = (fecha at time zone 'America/Monterrey') at time zone 'UTC'
 where concepto = 'visita'
   and venta_tipo = 'visita'
   and cliente_id is null
   and fecha = created_at;
