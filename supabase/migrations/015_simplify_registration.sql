-- =============================================
-- MIGRATION 015: SIMPLIFY REGISTRATION FUNCTION
-- Remove additional_branches parameter (single-branch model)
-- Rename p_owner_name to p_first_name + p_last_name
-- =============================================

-- Drop ALL overloaded versions
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text[]);
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text, text[]);

CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_user_id uuid,
    p_first_name text,
    p_last_name text,
    p_gym_name text,
    p_main_branch_name text
)
RETURNS jsonb AS $$
DECLARE
    v_gym_id uuid;
    v_branch_id uuid;
    v_staff_id uuid;
    v_display_name text;
    v_result jsonb;
BEGIN
    -- Validate: user must NOT already have a staff_profile (prevent duplicates)
    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a gym registered';
    END IF;

    -- Build display name
    v_display_name := trim(p_first_name || ' ' || p_last_name);

    -- 1. Create the gym
    INSERT INTO public.gyms (name, owner_user_id, is_active)
    VALUES (p_gym_name, p_user_id, true)
    RETURNING id INTO v_gym_id;

    -- 2. Create the single branch (location)
    INSERT INTO public.branches (gym_id, name, is_active)
    VALUES (v_gym_id, p_main_branch_name, true)
    RETURNING id INTO v_branch_id;

    -- 3. Create staff_profile (owner_admin, assigned to branch)
    INSERT INTO public.staff_profiles (user_id, gym_id, branch_id, role, display_name, first_name, last_name, is_active)
    VALUES (p_user_id, v_gym_id, v_branch_id, 'owner_admin', v_display_name, p_first_name, p_last_name, true)
    RETURNING id INTO v_staff_id;

    -- 4. Build result JSON
    v_result := jsonb_build_object(
        'gym_id', v_gym_id,
        'branch_id', v_branch_id,
        'staff_profile_id', v_staff_id,
        'user_id', p_user_id,
        'role', 'owner_admin',
        'display_name', v_display_name,
        'gym_name', p_gym_name,
        'branch_name', p_main_branch_name
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant to BOTH anon and authenticated (anon needed when email confirmation is on)
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO authenticated;
