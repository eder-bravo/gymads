-- Impide que un cliente acumule varias entradas/salidas en una misma
-- jornada, incluso si dos teléfonos o dos procesos intentan insertar al
-- mismo tiempo. La jornada del gimnasio cambia a la 1:00 AM, igual que en la
-- aplicación.
--
-- No se borran registros históricos. El guardián se aplica únicamente a
-- inserciones nuevas.

CREATE INDEX IF NOT EXISTS idx_access_logs_branch_user_time
  ON public.access_logs (branch_id, user_id, access_time DESC);

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

  NEW.access_time := COALESCE(NEW.access_time, now());
  v_dia_local :=
    ((NEW.access_time AT TIME ZONE 'America/Monterrey') - interval '1 hour')::date;
  v_inicio_jornada :=
    ((v_dia_local::timestamp + interval '1 hour')
      AT TIME ZONE 'America/Monterrey');
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

COMMENT ON FUNCTION public.validar_access_log_jornada() IS
  'Máximo una entrada y, si está habilitada, una salida por cliente, sucursal y jornada.';

DROP TRIGGER IF EXISTS trg_access_logs_validar_jornada ON public.access_logs;
CREATE TRIGGER trg_access_logs_validar_jornada
  BEFORE INSERT ON public.access_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.validar_access_log_jornada();
