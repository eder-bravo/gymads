-- =============================================
-- Migración: membership_plans (abonos fijos)
-- Fecha: 2026-07-24
-- Descripción: Planes de abono con precio fijo por gimnasio
--   (nombre, tipo de periodo, cantidad de periodos, precio total).
--   Tabla gym-level: compartida entre sucursales del gimnasio.
-- =============================================

-- 1) Tabla
CREATE TABLE IF NOT EXISTS public.membership_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    gym_id uuid REFERENCES public.gyms(id),
    name text NOT NULL,
    period_type text NOT NULL,        -- 'Meses' | 'Semanas' | 'Días' | 'Años'
    period_count int NOT NULL DEFAULT 1,
    price numeric NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2) Índice
CREATE INDEX IF NOT EXISTS idx_membership_plans_gym_id
    ON public.membership_plans(gym_id);

-- 3) RLS (patrón gym-level)
ALTER TABLE public.membership_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view gym membership_plans" ON public.membership_plans;
CREATE POLICY "Staff can view gym membership_plans"
    ON public.membership_plans FOR SELECT
    USING (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Owner can manage membership_plans" ON public.membership_plans;
CREATE POLICY "Owner can manage membership_plans"
    ON public.membership_plans FOR ALL
    USING (gym_id = public.current_gym_id() AND public.is_owner_admin());

DROP POLICY IF EXISTS "Staff can insert gym membership_plans" ON public.membership_plans;
CREATE POLICY "Staff can insert gym membership_plans"
    ON public.membership_plans FOR INSERT
    WITH CHECK (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can update gym membership_plans" ON public.membership_plans;
CREATE POLICY "Staff can update gym membership_plans"
    ON public.membership_plans FOR UPDATE
    USING (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can delete gym membership_plans" ON public.membership_plans;
CREATE POLICY "Staff can delete gym membership_plans"
    ON public.membership_plans FOR DELETE
    USING (gym_id = public.current_gym_id());

-- 4) Trigger de tenant (gym-level)
DROP TRIGGER IF EXISTS trg_membership_plans_set_gym ON public.membership_plans;
CREATE TRIGGER trg_membership_plans_set_gym
    BEFORE INSERT ON public.membership_plans
    FOR EACH ROW EXECUTE FUNCTION public.set_gym_on_insert();

-- 5) Trigger de updated_at
DROP TRIGGER IF EXISTS set_updated_at_membership_plans ON public.membership_plans;
CREATE TRIGGER set_updated_at_membership_plans
    BEFORE UPDATE ON public.membership_plans
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
