-- =============================================
-- MIGRATION 012: REMOVE LEGACY WIDE-OPEN RLS POLICIES
-- These old policies allow all authenticated users to access data,
-- bypassing the tenant-scoped policies added in migration 007.
-- In PostgreSQL, multiple permissive policies use OR logic,
-- so these must be dropped for tenant isolation to work.
-- =============================================

-- ACCESS_LOGS: drop legacy policies
DROP POLICY IF EXISTS "Allow insert access to authenticated users" ON public.access_logs;
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON public.access_logs;
DROP POLICY IF EXISTS "Allow update to creator" ON public.access_logs;
DROP POLICY IF EXISTS "Permitir acceso completo a logs" ON public.access_logs;
DROP POLICY IF EXISTS "Permitir lectura y escritura a usuarios autenticados" ON public.access_logs;
DROP POLICY IF EXISTS "Super Admin tiene acceso total" ON public.access_logs;
DROP POLICY IF EXISTS "admin_policy" ON public.access_logs;

-- INGRESOS: drop legacy policies
DROP POLICY IF EXISTS "Permitir actualización de ingresos a usuarios autenticados" ON public.ingresos;
DROP POLICY IF EXISTS "Permitir eliminación de ingresos a usuarios autenticados" ON public.ingresos;
DROP POLICY IF EXISTS "Permitir inserción de ingresos a usuarios autenticados" ON public.ingresos;
DROP POLICY IF EXISTS "Permitir lectura de ingresos a usuarios autenticados" ON public.ingresos;

-- MEMBERSHIP_TYPES: drop legacy policies
DROP POLICY IF EXISTS "Permitir lectura de tipos de membresía" ON public.membership_types;
DROP POLICY IF EXISTS "Permitir lectura pública de tipos de membresía" ON public.membership_types;
DROP POLICY IF EXISTS "Permitir modificar tipos de membresía" ON public.membership_types;
DROP POLICY IF EXISTS "Super Admin tiene acceso total" ON public.membership_types;
DROP POLICY IF EXISTS "admin_policy" ON public.membership_types;

-- PAYMENTS: drop legacy policies
DROP POLICY IF EXISTS "Permitir acceso completo a pagos" ON public.payments;
DROP POLICY IF EXISTS "Permitir lectura y escritura a usuarios autenticados" ON public.payments;
DROP POLICY IF EXISTS "Super Admin tiene acceso total" ON public.payments;
DROP POLICY IF EXISTS "admin_policy" ON public.payments;

-- PROMOTIONS: drop legacy policies
DROP POLICY IF EXISTS "Permitir lectura de promociones" ON public.promotions;
DROP POLICY IF EXISTS "Permitir modificar promociones" ON public.promotions;
DROP POLICY IF EXISTS "admin_policy" ON public.promotions;

-- USERS: drop legacy admin_policy
DROP POLICY IF EXISTS "admin_policy" ON public.users;

-- =============================================
-- ADD MISSING POLICIES (fill gaps left by removing legacy ones)
-- =============================================

-- membership_types: staff needs insert/update (already exists from 007 but re-ensure)
DROP POLICY IF EXISTS "Staff can insert gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can insert gym membership_types"
    ON public.membership_types FOR INSERT
    WITH CHECK (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can update gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can update gym membership_types"
    ON public.membership_types FOR UPDATE
    USING (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can delete gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can delete gym membership_types"
    ON public.membership_types FOR DELETE
    USING (gym_id = public.current_gym_id());

-- staff_profiles: allow user to update own profile
DROP POLICY IF EXISTS "Staff can update own profile" ON public.staff_profiles;
CREATE POLICY "Staff can update own profile"
    ON public.staff_profiles FOR UPDATE
    USING (user_id = auth.uid());

-- payments: staff needs update/delete
DROP POLICY IF EXISTS "Staff can update branch payments" ON public.payments;
CREATE POLICY "Staff can update branch payments"
    ON public.payments FOR UPDATE
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can delete branch payments" ON public.payments;
CREATE POLICY "Staff can delete branch payments"
    ON public.payments FOR DELETE
    USING (branch_id = public.current_branch_id());

-- promotions: staff needs delete
DROP POLICY IF EXISTS "Staff can delete branch promotions" ON public.promotions;
CREATE POLICY "Staff can delete branch promotions"
    ON public.promotions FOR DELETE
    USING (
        gym_id = public.current_gym_id()
        AND (branch_id IS NULL OR branch_id = public.current_branch_id())
    );
