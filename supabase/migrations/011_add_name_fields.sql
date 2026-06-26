-- =============================================
-- MIGRATION 011: ADD NAME FIELDS TO STAFF_PROFILES
-- Splits display_name into first_name + last_name
-- =============================================

-- Add name columns
ALTER TABLE public.staff_profiles
ADD COLUMN IF NOT EXISTS first_name text,
ADD COLUMN IF NOT EXISTS last_name text;

-- Migrate existing display_name data into first_name
UPDATE public.staff_profiles
SET first_name = display_name
WHERE display_name IS NOT NULL AND first_name IS NULL;

-- Update the register_gym_owner function with simplified name fields
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text, text, text[]);
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text[]);

CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_user_id uuid,
    p_first_name text,
    p_last_name text,
    p_gym_name text DEFAULT '',
    p_main_branch_name text DEFAULT 'Sucursal Principal',
    p_additional_branches text[] DEFAULT '{}'
)
RETURNS jsonb AS $$
DECLARE
    v_gym_id uuid;
    v_main_branch_id uuid;
    v_staff_id uuid;
    v_branch_name text;
    v_display_name text;
    v_result jsonb;
BEGIN
    -- Validate: user must NOT already have a staff_profile
    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a gym registered';
    END IF;

    -- Build display_name
    v_display_name := trim(p_first_name || ' ' || p_last_name);

    -- 1. Create the gym
    INSERT INTO public.gyms (name, owner_user_id, is_active)
    VALUES (p_gym_name, p_user_id, true)
    RETURNING id INTO v_gym_id;

    -- 2. Create the main branch
    INSERT INTO public.branches (gym_id, name, is_active)
    VALUES (v_gym_id, p_main_branch_name, true)
    RETURNING id INTO v_main_branch_id;

    -- 3. Create additional branches (if any)
    IF p_additional_branches IS NOT NULL AND array_length(p_additional_branches, 1) > 0 THEN
        FOREACH v_branch_name IN ARRAY p_additional_branches
        LOOP
            IF v_branch_name IS NOT NULL AND trim(v_branch_name) <> '' THEN
                INSERT INTO public.branches (gym_id, name, is_active)
                VALUES (v_gym_id, trim(v_branch_name), true);
            END IF;
        END LOOP;
    END IF;

    -- 4. Create staff_profile
    INSERT INTO public.staff_profiles (
        user_id, gym_id, branch_id, role,
        first_name, last_name,
        display_name, is_active
    )
    VALUES (
        p_user_id, v_gym_id, v_main_branch_id, 'owner_admin',
        p_first_name, p_last_name,
        v_display_name, true
    )
    RETURNING id INTO v_staff_id;

    -- 5. Build result JSON
    v_result := jsonb_build_object(
        'gym_id', v_gym_id,
        'branch_id', v_main_branch_id,
        'staff_profile_id', v_staff_id,
        'user_id', p_user_id,
        'role', 'owner_admin',
        'first_name', p_first_name,
        'last_name', p_last_name,
        'display_name', v_display_name,
        'gym_name', p_gym_name,
        'branch_name', p_main_branch_name
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant to both anon and authenticated
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text, text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text, text[]) TO authenticated;
