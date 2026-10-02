-- =============================================================
-- Migración: arreglar el borrado de cuenta y permitir editar la sucursal
-- Fecha: 2026-08-17
--
-- Problemas que resuelve:
--   1. `delete_gym_cascade` borraba `public.promotions` y
--      `public.membership_types`, tablas eliminadas en
--      20260507_drop_promotions.sql. PL/pgSQL resuelve el nombre de la
--      tabla al ejecutar la sentencia, así que la función fallaba con
--      42P01 y hacía rollback: el botón "Borrar datos" nunca funcionó.
--   2. Borrar un usuario desde el panel de Supabase fallaba con
--      "Database error deleting user" (23503): al borrar auth.users se
--      intentaba borrar en cascada la fila de `gyms`, pero sus tablas
--      hijas la referenciaban con NO ACTION.
--   3. No existía política RLS de UPDATE en `branches`, así que el
--      nombre de la sucursal no se podía editar desde la app.
--   4. La política de UPDATE de `staff_profiles` no tenía WITH CHECK,
--      permitiendo que un usuario se subiera el rol a owner_admin.
-- =============================================================

-- -------------------------------------------------------------
-- 1. FKs de tenant en ON DELETE CASCADE
--    Borrar el gimnasio arrastra todos sus datos. Riesgo acotado:
--    `gyms` no tiene política RLS de DELETE, así que solo pueden
--    borrarlo funciones SECURITY DEFINER o el service role.
-- -------------------------------------------------------------

-- Hijas de gyms
ALTER TABLE public.access_logs
    DROP CONSTRAINT IF EXISTS access_logs_gym_id_fkey,
    ADD  CONSTRAINT access_logs_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.ingresos
    DROP CONSTRAINT IF EXISTS ingresos_gym_id_fkey,
    ADD  CONSTRAINT ingresos_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.payments
    DROP CONSTRAINT IF EXISTS payments_gym_id_fkey,
    ADD  CONSTRAINT payments_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.product_categories
    DROP CONSTRAINT IF EXISTS product_categories_gym_id_fkey,
    ADD  CONSTRAINT product_categories_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.product_transactions
    DROP CONSTRAINT IF EXISTS product_transactions_gym_id_fkey,
    ADD  CONSTRAINT product_transactions_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_gym_id_fkey,
    ADD  CONSTRAINT products_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_gym_id_fkey,
    ADD  CONSTRAINT users_gym_id_fkey
        FOREIGN KEY (gym_id) REFERENCES public.gyms(id) ON DELETE CASCADE;

-- Hijas de branches
ALTER TABLE public.access_logs
    DROP CONSTRAINT IF EXISTS access_logs_branch_id_fkey,
    ADD  CONSTRAINT access_logs_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

ALTER TABLE public.ingresos
    DROP CONSTRAINT IF EXISTS ingresos_branch_id_fkey,
    ADD  CONSTRAINT ingresos_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

ALTER TABLE public.payments
    DROP CONSTRAINT IF EXISTS payments_branch_id_fkey,
    ADD  CONSTRAINT payments_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

ALTER TABLE public.product_transactions
    DROP CONSTRAINT IF EXISTS product_transactions_branch_id_fkey,
    ADD  CONSTRAINT product_transactions_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_branch_id_fkey,
    ADD  CONSTRAINT products_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_branch_id_fkey,
    ADD  CONSTRAINT users_branch_id_fkey
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;

-- -------------------------------------------------------------
-- 2. Drift: gyms.owner_user_id ya estaba en CASCADE en producción,
--    pero 001_create_multi_tenant_tables.sql lo declara sin ON DELETE.
--    Se deja explícito para que una BD reconstruida desde cero
--    coincida con producción.
-- -------------------------------------------------------------

ALTER TABLE public.gyms
    DROP CONSTRAINT IF EXISTS gyms_owner_user_id_fkey,
    ADD  CONSTRAINT gyms_owner_user_id_fkey
        FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- -------------------------------------------------------------
-- 3. delete_gym_cascade sin enumerar tablas
--    Al no listar tablas una por una, borrar una tabla en el futuro
--    ya no puede volver a romper esta función.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_gym_cascade(p_gym_id uuid)
RETURNS jsonb AS $$
DECLARE
    v_caller_id      uuid;
    v_staff_user_ids uuid[];
    v_clients        int;
    v_staff          int;
BEGIN
    -- 1. Debe haber sesión
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Solo el dueño del gimnasio puede borrarlo
    IF NOT EXISTS (
        SELECT 1 FROM public.staff_profiles
        WHERE user_id = v_caller_id
          AND gym_id  = p_gym_id
          AND role    = 'owner_admin'
    ) THEN
        RAISE EXCEPTION 'Only the gym owner can delete the gym';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.gyms WHERE id = p_gym_id) THEN
        RAISE EXCEPTION 'Gym not found';
    END IF;

    -- 3. Usuarios auth de TODO el staff del gimnasio, no solo el dueño
    SELECT array_agg(user_id) INTO v_staff_user_ids
    FROM public.staff_profiles WHERE gym_id = p_gym_id;

    SELECT count(*) INTO v_clients FROM public.users          WHERE gym_id = p_gym_id;
    SELECT count(*) INTO v_staff   FROM public.staff_profiles WHERE gym_id = p_gym_id;

    -- 4. Borrar el gimnasio arrastra en cascada sucursales, perfiles de
    --    staff, clientes, ingresos, pagos, productos, categorías,
    --    transacciones y registros de acceso.
    DELETE FROM public.gyms WHERE id = p_gym_id;

    -- 5. Borrar los usuarios auth arrastra identities, sessions, etc.
    IF v_staff_user_ids IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = ANY(v_staff_user_ids);
    END IF;

    RETURN jsonb_build_object(
        'gym_deleted',        true,
        'clients',            v_clients,
        'staff_profiles',     v_staff,
        'auth_users_deleted', coalesce(array_length(v_staff_user_ids, 1), 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.delete_gym_cascade(uuid) TO authenticated;

-- -------------------------------------------------------------
-- 4. Permisos de escritura
-- -------------------------------------------------------------

-- staff_profiles: la política "Staff can update own profile" no tiene
-- WITH CHECK, así que un usuario podía cambiarse el role a owner_admin.
-- Se acota con permisos por columna en vez de con WITH CHECK, porque
-- current_role() es SECURITY DEFINER y dentro de la misma transacción ya
-- vería la fila modificada, volviendo la condición tautológica.
-- register_gym_owner no se ve afectada: corre SECURITY DEFINER.
REVOKE UPDATE ON public.staff_profiles FROM authenticated;
GRANT  UPDATE (first_name, last_name, display_name)
    ON public.staff_profiles TO authenticated;

-- branches: faltaba la política de UPDATE (solo tenía dos de SELECT).
-- Misma forma que la de gyms en 019_security_hardening.sql.
DROP POLICY IF EXISTS "Owner can update their branches" ON public.branches;
CREATE POLICY "Owner can update their branches"
    ON public.branches FOR UPDATE
    USING (gym_id = public.current_gym_id() AND public.is_owner_admin())
    WITH CHECK (gym_id = public.current_gym_id());
