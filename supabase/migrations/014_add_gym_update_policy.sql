-- =============================================
-- MIGRATION 014: Add UPDATE policy for gyms
-- =============================================

DROP POLICY IF EXISTS "Staff can update their gym" ON public.gyms;
CREATE POLICY "Staff can update their gym"
    ON public.gyms FOR UPDATE
    USING (id = public.current_gym_id());
