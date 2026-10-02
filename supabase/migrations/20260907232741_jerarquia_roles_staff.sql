-- =============================================
-- JERARQUÍA DE ROLES DEL PERSONAL
-- =============================================
-- Hasta ahora solo había dos roles: owner_admin y branch_staff. Todo lo que no
-- fuera del dueño lo podía hacer cualquier empleado, y el menú de la app no
-- filtraba nada.
--
-- Quedan cinco, de más a menos mando:
--
--   owner_admin  Dueño. Todo, incluido borrar el gimnasio.
--   encargado    Todo menos borrar el gimnasio y tocar accesos de su nivel.
--   branch_staff El staff de siempre: atiende y vende, ajusta stock, NO precios.
--   almacen      Solo inventario: productos, precios de producto y stock.
--   mostrador    Recepción. El único que recibe el aviso del lector de tarjetas.
--
-- El permiso vive en public.staff_puede(). Es el espejo exacto de
-- lib/app/core/permissions/permissions.dart: los dos se editan JUNTOS, porque
-- ocultar un botón sin cerrar la política no protege nada, y cerrar la política
-- sin ocultar el botón deja al empleado chocando contra un error.
--
-- NOTA: la escalada de privilegios por "Staff can update own profile" ya la
-- cerró 20260817205201 con permisos por columna (solo first_name, last_name y
-- display_name). Esta migración NO vuelve a otorgar UPDATE sobre la tabla.
--
-- Idempotente.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Los roles nuevos
-- ---------------------------------------------------------------
-- El CHECK de 001 se declaró en la columna, así que su nombre lo puso
-- Postgres. Confiar en que se llame `staff_profiles_role_check` es lo que
-- convertiría esto en un fallo silencioso: el DROP no encontraría nada, el ADD
-- crearía un segundo CHECK y el viejo seguiría rechazando los roles nuevos.
-- Se busca por su definición, que es lo único estable.
DO $ctb$
DECLARE
    v_nombre text;
BEGIN
    FOR v_nombre IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel     ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'staff_profiles'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) LIKE '%owner_admin%'
    LOOP
        EXECUTE format(
            'ALTER TABLE public.staff_profiles DROP CONSTRAINT %I', v_nombre);
    END LOOP;
END
$ctb$;

ALTER TABLE public.staff_profiles
    ADD CONSTRAINT staff_profiles_role_check
    CHECK (role IN ('owner_admin', 'encargado', 'branch_staff', 'almacen', 'mostrador'));


-- ---------------------------------------------------------------
-- 2. Cada acceso entrega un rol
-- ---------------------------------------------------------------
-- El DEFAULT deja como staff a los accesos que ya existían, que es justo lo
-- que son hoy. owner_admin no está en la lista: se es dueño registrando el
-- gimnasio, nunca canjeando un código.
ALTER TABLE public.staff_accesos
    ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'branch_staff';

ALTER TABLE public.staff_accesos
    DROP CONSTRAINT IF EXISTS staff_accesos_role_check;

ALTER TABLE public.staff_accesos
    ADD CONSTRAINT staff_accesos_role_check
    CHECK (role IN ('encargado', 'branch_staff', 'almacen', 'mostrador'));


-- ---------------------------------------------------------------
-- 3. Helpers de permiso
-- ---------------------------------------------------------------

-- Quién manda sobre quién. Solo se puede asignar o modificar un rol de rango
-- ESTRICTAMENTE menor al propio, así que dos roles del mismo rango no pueden
-- tocarse entre sí y un encargado no puede nombrar a otro encargado.
CREATE OR REPLACE FUNCTION public.rango_staff(p_role text)
RETURNS int AS $$
    SELECT CASE p_role
        WHEN 'owner_admin' THEN 100
        WHEN 'encargado'   THEN 80
        WHEN 'branch_staff' THEN 50
        WHEN 'almacen'     THEN 50
        WHEN 'mostrador'   THEN 50
        ELSE 0
    END;
$$ LANGUAGE sql IMMUTABLE
   SET search_path = public, pg_temp;


-- El permiso del usuario actual.
--
-- Se lee el rol con una subconsulta en vez de con public.current_role() para
-- no depender de una función cuyo nombre choca con la palabra reservada
-- current_role de SQL.
CREATE OR REPLACE FUNCTION public.staff_puede(p_permiso text)
RETURNS boolean AS $$
    SELECT CASE (
        SELECT role
        FROM public.staff_profiles
        WHERE user_id = auth.uid()
          AND is_active = true
        LIMIT 1
    )
        WHEN 'owner_admin' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'gestionar_productos', 'ajustar_stock',
            'gestionar_categorias', 'ver_ingresos', 'ver_accesos',
            'gestionar_precios_abonos', 'gestionar_control_accesos',
            'editar_gimnasio', 'gestionar_accesos_staff', 'eliminar_gimnasio'
        ])
        WHEN 'encargado' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'gestionar_productos', 'ajustar_stock',
            'gestionar_categorias', 'ver_ingresos', 'ver_accesos',
            'gestionar_precios_abonos', 'gestionar_control_accesos',
            'editar_gimnasio', 'gestionar_accesos_staff'
        ])
        WHEN 'branch_staff' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'ajustar_stock',
            'ver_ingresos', 'ver_accesos'
        ])
        WHEN 'almacen' THEN p_permiso = ANY (ARRAY[
            'ver_inventario', 'gestionar_productos', 'ajustar_stock',
            'gestionar_categorias'
        ])
        WHEN 'mostrador' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_ingresos', 'ver_accesos', 'recibir_alertas_nfc'
        ])
        -- Sin perfil activo no se puede nada.
        ELSE false
    END;
$$ LANGUAGE sql STABLE SECURITY DEFINER
   SET search_path = public, pg_temp;


-- Si el usuario actual puede entregar o modificar un acceso con rol p_role.
CREATE OR REPLACE FUNCTION public.puede_gestionar_rol(p_role text)
RETURNS boolean AS $$
    SELECT public.staff_puede('gestionar_accesos_staff')
       AND public.rango_staff((
               SELECT role FROM public.staff_profiles
               WHERE user_id = auth.uid() AND is_active = true LIMIT 1
           )) > public.rango_staff(p_role);
$$ LANGUAGE sql STABLE SECURITY DEFINER
   SET search_path = public, pg_temp;


GRANT EXECUTE ON FUNCTION public.rango_staff(text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_puede(text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.puede_gestionar_rol(text) TO authenticated;


-- ---------------------------------------------------------------
-- 4. Políticas RLS por permiso
-- ---------------------------------------------------------------
-- Sustituyen a las de 007, que solo acotaban por sucursal.

-- 4.a USERS (clientes) -------------------------------------------------------
-- Almacén no atiende clientes: no los ve ni los toca.
DROP POLICY IF EXISTS "Staff can view branch users" ON public.users;
CREATE POLICY "Staff can view branch users"
    ON public.users FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('gestionar_clientes'));

DROP POLICY IF EXISTS "Staff can insert branch users" ON public.users;
CREATE POLICY "Staff can insert branch users"
    ON public.users FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND public.staff_puede('gestionar_clientes'));

DROP POLICY IF EXISTS "Staff can update branch users" ON public.users;
CREATE POLICY "Staff can update branch users"
    ON public.users FOR UPDATE
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('gestionar_clientes'));

DROP POLICY IF EXISTS "Staff can delete branch users" ON public.users;
CREATE POLICY "Staff can delete branch users"
    ON public.users FOR DELETE
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('gestionar_clientes'));


-- 4.b INGRESOS ---------------------------------------------------------------
-- Las ventas del punto de venta también escriben aquí, de ahí el OR 'vender'.
DROP POLICY IF EXISTS "Staff can view branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can view branch ingresos"
    ON public.ingresos FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('ver_ingresos'));

DROP POLICY IF EXISTS "Staff can insert branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can insert branch ingresos"
    ON public.ingresos FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND (public.staff_puede('cobrar_abonos')
                     OR public.staff_puede('vender')));

DROP POLICY IF EXISTS "Staff can update branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can update branch ingresos"
    ON public.ingresos FOR UPDATE
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('cobrar_abonos')
                OR public.staff_puede('vender')));

DROP POLICY IF EXISTS "Staff can delete branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can delete branch ingresos"
    ON public.ingresos FOR DELETE
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('cobrar_abonos')
                OR public.staff_puede('vender')));


-- 4.c PAYMENTS ---------------------------------------------------------------
DROP POLICY IF EXISTS "Staff can view branch payments" ON public.payments;
CREATE POLICY "Staff can view branch payments"
    ON public.payments FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('ver_ingresos'));

DROP POLICY IF EXISTS "Staff can insert branch payments" ON public.payments;
CREATE POLICY "Staff can insert branch payments"
    ON public.payments FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND (public.staff_puede('cobrar_abonos')
                     OR public.staff_puede('vender')));

DROP POLICY IF EXISTS "Staff can update branch payments" ON public.payments;
CREATE POLICY "Staff can update branch payments"
    ON public.payments FOR UPDATE
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('cobrar_abonos')
                OR public.staff_puede('vender')));

DROP POLICY IF EXISTS "Staff can delete branch payments" ON public.payments;
CREATE POLICY "Staff can delete branch payments"
    ON public.payments FOR DELETE
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('cobrar_abonos')
                OR public.staff_puede('vender')));


-- 4.d ACCESS_LOGS ------------------------------------------------------------
DROP POLICY IF EXISTS "Staff can view branch access_logs" ON public.access_logs;
CREATE POLICY "Staff can view branch access_logs"
    ON public.access_logs FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('ver_accesos'));

DROP POLICY IF EXISTS "Staff can insert branch access_logs" ON public.access_logs;
CREATE POLICY "Staff can insert branch access_logs"
    ON public.access_logs FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND public.staff_puede('ver_accesos'));


-- 4.e PRODUCTS ---------------------------------------------------------------
-- El punto de venta necesita LEER productos aunque mostrador no entre al
-- inventario. Escribir (incluido el precio) exige 'gestionar_productos': el
-- staff solo mueve stock, y eso pasa por ajustar_stock_producto (sección 5).
DROP POLICY IF EXISTS "Staff can view branch products" ON public.products;
CREATE POLICY "Staff can view branch products"
    ON public.products FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('ver_inventario')
                OR public.staff_puede('vender')));

DROP POLICY IF EXISTS "Staff can insert branch products" ON public.products;
CREATE POLICY "Staff can insert branch products"
    ON public.products FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND public.staff_puede('gestionar_productos'));

DROP POLICY IF EXISTS "Staff can update branch products" ON public.products;
CREATE POLICY "Staff can update branch products"
    ON public.products FOR UPDATE
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('gestionar_productos'));

DROP POLICY IF EXISTS "Staff can delete branch products" ON public.products;
CREATE POLICY "Staff can delete branch products"
    ON public.products FOR DELETE
    USING (branch_id = public.current_branch_id()
           AND public.staff_puede('gestionar_productos'));


-- 4.f PRODUCT_TRANSACTIONS ---------------------------------------------------
DROP POLICY IF EXISTS "Staff can view branch product_transactions" ON public.product_transactions;
CREATE POLICY "Staff can view branch product_transactions"
    ON public.product_transactions FOR SELECT
    USING (branch_id = public.current_branch_id()
           AND (public.staff_puede('ver_inventario')
                OR public.staff_puede('ver_ingresos')));

DROP POLICY IF EXISTS "Staff can insert branch product_transactions" ON public.product_transactions;
CREATE POLICY "Staff can insert branch product_transactions"
    ON public.product_transactions FOR INSERT
    WITH CHECK (branch_id = public.current_branch_id()
                AND gym_id = public.current_gym_id()
                AND (public.staff_puede('ajustar_stock')
                     OR public.staff_puede('vender')));


-- 4.g PRODUCT_CATEGORIES -----------------------------------------------------
-- La lectura sigue abierta a todo el gimnasio: el punto de venta agrupa por
-- categoría aunque quien vende no pueda editarlas.
DROP POLICY IF EXISTS "Staff can insert product_categories" ON public.product_categories;
CREATE POLICY "Staff can insert product_categories"
    ON public.product_categories FOR INSERT
    WITH CHECK (gym_id = public.current_gym_id()
                AND public.staff_puede('gestionar_categorias'));

DROP POLICY IF EXISTS "Staff can update product_categories" ON public.product_categories;
CREATE POLICY "Staff can update product_categories"
    ON public.product_categories FOR UPDATE
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('gestionar_categorias'));

-- Reemplaza a la política owner-only de 20260824214915.
DROP POLICY IF EXISTS "Owner can delete product_categories" ON public.product_categories;
CREATE POLICY "Owner can delete product_categories"
    ON public.product_categories FOR DELETE
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('gestionar_categorias'));


-- 4.h GYMS y BRANCHES --------------------------------------------------------
-- Los precios de abono viven en gyms, así que esto es también lo que habilita
-- al encargado a fijarlos.
DROP POLICY IF EXISTS "Owner can update their gym" ON public.gyms;
CREATE POLICY "Owner can update their gym"
    ON public.gyms FOR UPDATE
    USING (id = public.current_gym_id()
           AND public.staff_puede('editar_gimnasio'))
    WITH CHECK (id = public.current_gym_id());

DROP POLICY IF EXISTS "Owner can update their branches" ON public.branches;
CREATE POLICY "Owner can update their branches"
    ON public.branches FOR UPDATE
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('editar_gimnasio'))
    WITH CHECK (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Owner can view all gym branches" ON public.branches;
CREATE POLICY "Owner can view all gym branches"
    ON public.branches FOR SELECT
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('editar_gimnasio'));


-- 4.i STAFF_ACCESOS y el equipo ----------------------------------------------
DROP POLICY IF EXISTS "Owner can view gym staff access" ON public.staff_accesos;
CREATE POLICY "Owner can view gym staff access"
    ON public.staff_accesos FOR SELECT
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('gestionar_accesos_staff'));

-- El dueño (y ahora el encargado) necesita ver a su propio equipo. Además, el
-- dueño consulta esta tabla para saber si ya hay alguien en mostrador y así
-- decidir si él mismo debe seguir recibiendo los avisos del lector.
DROP POLICY IF EXISTS "Owner can view gym staff profiles" ON public.staff_profiles;
CREATE POLICY "Owner can view gym staff profiles"
    ON public.staff_profiles FOR SELECT
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('gestionar_accesos_staff'));


-- ---------------------------------------------------------------
-- 5. ajustar_stock_producto pasa a SECURITY DEFINER
-- ---------------------------------------------------------------
-- Antes era INVOKER y se apoyaba en la política UPDATE de products para acotar
-- por sucursal. Esa política ahora exige 'gestionar_productos', así que el
-- staff habría perdido el ajuste de stock y el punto de venta habría dejado de
-- descontar. La función asume la comprobación que antes hacía la RLS: valida
-- la sucursal por dentro y exige el permiso que corresponde.
--
-- Sigue admitiendo resultados NEGATIVOS a propósito: es el faltante, lo
-- vendido sin existencias, y se salda al reponer (-3 + 10 = 7).
CREATE OR REPLACE FUNCTION public.ajustar_stock_producto(
  p_product_id uuid,
  p_delta int
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_stock int;
BEGIN
  IF NOT (public.staff_puede('ajustar_stock') OR public.staff_puede('vender')) THEN
    RAISE EXCEPTION 'No autorizado: no puedes mover el stock';
  END IF;

  -- El filtro por sucursal es lo que antes daba la RLS. Sin él, DEFINER
  -- dejaría mover el stock de cualquier gimnasio.
  UPDATE public.products
     SET stock = stock + p_delta,
         updated_at = now()
   WHERE id = p_product_id
     AND branch_id = public.current_branch_id()
  RETURNING stock INTO v_stock;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado o sin permiso: %', p_product_id
      USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_stock;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ajustar_stock_producto(uuid, int) TO authenticated;


-- ---------------------------------------------------------------
-- 6. Gestión de accesos con rol
-- ---------------------------------------------------------------

-- 6.a La guarda común deja de ser owner-only: ahora hay que MANDAR sobre el
--     rol del acceso que se quiere tocar.
CREATE OR REPLACE FUNCTION public._acceso_staff_del_owner(p_acceso_id uuid)
RETURNS public.staff_accesos AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    IF NOT public.staff_puede('gestionar_accesos_staff') THEN
        RAISE EXCEPTION 'No autorizado: no puedes gestionar los accesos';
    END IF;

    SELECT * INTO v_acceso
    FROM public.staff_accesos
    WHERE id = p_acceso_id
      AND gym_id = public.current_gym_id()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Acceso no encontrado';
    END IF;

    IF NOT public.puede_gestionar_rol(v_acceso.role) THEN
        RAISE EXCEPTION 'No autorizado: ese acceso está fuera de tu alcance';
    END IF;

    RETURN v_acceso;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 6.b Crear un acceso, ahora con rol.
--     La firma cambia, así que la de dos argumentos desaparece: dejarla viva
--     seguiría creando personal sin rol explícito.
DROP FUNCTION IF EXISTS public.crear_acceso_staff(text, text);

CREATE OR REPLACE FUNCTION public.crear_acceso_staff(
    p_nombre text,
    p_codigo_hash text,
    p_role text
)
RETURNS uuid AS $$
DECLARE
    v_id uuid;
    v_nombre text;
BEGIN
    IF NOT public.puede_gestionar_rol(p_role) THEN
        RAISE EXCEPTION 'No autorizado: no puedes entregar ese rol';
    END IF;

    v_nombre := nullif(btrim(p_nombre), '');
    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'El nombre es obligatorio';
    END IF;

    IF p_codigo_hash IS NULL OR length(p_codigo_hash) <> 64 THEN
        RAISE EXCEPTION 'Código inválido';
    END IF;

    INSERT INTO public.staff_accesos (gym_id, branch_id, nombre, codigo_hash, role, created_by)
    VALUES (
        public.current_gym_id(),
        public.current_branch_id(),
        v_nombre,
        p_codigo_hash,
        p_role,
        auth.uid()
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 6.c Cambiar el rol de alguien que ya está trabajando.
--     Si el acceso ya fue canjeado, el perfil cambia con él y el empleado ve
--     el menú nuevo en cuanto su app relee el perfil.
CREATE OR REPLACE FUNCTION public.cambiar_rol_staff(
    p_acceso_id uuid,
    p_role text
)
RETURNS void AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    -- Valida el permiso y que se mande sobre el rol ACTUAL del acceso.
    v_acceso := public._acceso_staff_del_owner(p_acceso_id);

    -- Y además sobre el rol NUEVO: nadie asciende a nadie a su propio nivel.
    IF NOT public.puede_gestionar_rol(p_role) THEN
        RAISE EXCEPTION 'No autorizado: no puedes entregar ese rol';
    END IF;

    UPDATE public.staff_accesos
    SET role = p_role
    WHERE id = p_acceso_id;

    IF v_acceso.user_id IS NOT NULL THEN
        UPDATE public.staff_profiles
        SET role = p_role
        WHERE user_id = v_acceso.user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 6.d El canje entrega el rol que guarda el acceso, no un branch_staff fijo.
CREATE OR REPLACE FUNCTION public.canjear_codigo_staff(p_codigo_hash text)
RETURNS jsonb AS $$
DECLARE
    v_acceso public.staff_accesos;
    v_staff  public.staff_profiles;
    v_gym    public.gyms;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión activa';
    END IF;

    IF p_codigo_hash IS NULL OR length(p_codigo_hash) <> 64 THEN
        RAISE EXCEPTION 'Código inválido o ya utilizado';
    END IF;

    -- Un usuario solo puede pertenecer a un gimnasio (user_id es UNIQUE)
    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Esta sesión ya tiene un acceso asignado';
    END IF;

    SELECT * INTO v_acceso
    FROM public.staff_accesos
    WHERE codigo_hash = p_codigo_hash
      AND estado = 'pendiente'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Código inválido o ya utilizado';
    END IF;

    INSERT INTO public.staff_profiles (
        user_id, gym_id, branch_id, role, display_name, first_name, is_active
    )
    VALUES (
        auth.uid(), v_acceso.gym_id, v_acceso.branch_id, v_acceso.role,
        v_acceso.nombre, v_acceso.nombre, true
    )
    RETURNING * INTO v_staff;

    -- El código se consume: deja de existir incluso como hash.
    UPDATE public.staff_accesos
    SET estado      = 'activo',
        user_id     = auth.uid(),
        redeemed_at = now(),
        codigo_hash = NULL
    WHERE id = v_acceso.id;

    SELECT * INTO v_gym FROM public.gyms WHERE id = v_acceso.gym_id;

    RETURN jsonb_build_object(
        'id',           v_staff.id,
        'user_id',      v_staff.user_id,
        'gym_id',       v_staff.gym_id,
        'branch_id',    v_staff.branch_id,
        'role',         v_staff.role,
        'first_name',   v_staff.first_name,
        'last_name',    v_staff.last_name,
        'display_name', v_staff.display_name,
        'is_active',    v_staff.is_active,
        'created_at',   v_staff.created_at,
        'updated_at',   v_staff.updated_at,
        'gyms', jsonb_build_object(
            'name',         v_gym.name,
            'created_at',   v_gym.created_at,
            'payment_mode', v_gym.payment_mode
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- ---------------------------------------------------------------
-- 7. GRANTs
-- ---------------------------------------------------------------
REVOKE ALL ON FUNCTION public._acceso_staff_del_owner(uuid) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.crear_acceso_staff(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cambiar_rol_staff(uuid, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.canjear_codigo_staff(text)           TO authenticated;


-- ---------------------------------------------------------------
-- 8. Borrar el gimnasio sigue siendo solo del dueño
-- ---------------------------------------------------------------
-- delete_gym_cascade conserva su guarda is_owner_admin() de 017/20260817205201:
-- es la única cosa que el encargado NO puede hacer, y no se toca aquí.
