-- =============================================
-- MIGRATION 002: HELPER FUNCTIONS FOR RLS
-- Functions: current_branch_id(), current_gym_id(), current_role(), is_owner_admin()
-- =============================================

-- Get current user's branch_id from staff_profiles
CREATE OR REPLACE FUNCTION public.current_branch_id()
RETURNS uuid AS $$
    SELECT branch_id 
    FROM public.staff_profiles 
    WHERE user_id = auth.uid() 
      AND is_active = true
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Get current user's gym_id from staff_profiles
CREATE OR REPLACE FUNCTION public.current_gym_id()
RETURNS uuid AS $$
    SELECT gym_id 
    FROM public.staff_profiles 
    WHERE user_id = auth.uid() 
      AND is_active = true
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Get current user's role from staff_profiles
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS text AS $$
    SELECT role 
    FROM public.staff_profiles 
    WHERE user_id = auth.uid() 
      AND is_active = true
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Check if current user is owner_admin
CREATE OR REPLACE FUNCTION public.is_owner_admin()
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.staff_profiles 
        WHERE user_id = auth.uid() 
          AND role = 'owner_admin'
          AND is_active = true
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
