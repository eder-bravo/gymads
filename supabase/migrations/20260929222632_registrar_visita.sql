-- Cobrar una visita sin registrar al cliente.
--
-- Quien viene a probar el gimnasio paga el día sin darse de alta (sin foto,
-- teléfono ni tarjeta). Aun así queda:
--   - su cobro en `ingresos` (concepto 'visita', sin cliente), y
--   - su entrada en `access_logs` (method 'visita', sin cliente).
-- Las dos cosas en una sola transacción: nunca queda un cobro sin su entrada
-- ni una entrada sin su cobro.
--
-- Una visita solo marca la ENTRADA, aunque el gimnasio registre salidas: no
-- tiene tarjeta para marcar la salida, y ninguna pantalla cuenta quién sigue
-- dentro, así que no queda "pendiente".

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
    coalesce(nullif(btrim(coalesce(p_staff, '')), ''), 'Staff'), 'visita', now(),
    v_gym, v_branch
  )
  returning id into v_id;

  insert into public.access_logs (
    user_id, user_name, user_number, access_type, method, staff_user,
    access_time, gym_id, branch_id
  ) values (
    null, v_mostrar, '', 'entrada', 'visita',
    coalesce(nullif(btrim(coalesce(p_staff, '')), ''), 'Staff'),
    now(), v_gym, v_branch
  );

  return v_id;
end;
$$;

revoke all on function public.registrar_visita(text, numeric, text, text, text)
  from public, anon;
grant execute on function public.registrar_visita(text, numeric, text, text, text)
  to authenticated;
