-- =============================================
-- MIGRATION 017: DELETE GYM CASCADE FUNCTION
-- Safely deletes a gym and ALL its data, then the owner user.
-- Only the owner_admin can call this function.
-- =============================================

CREATE OR REPLACE FUNCTION public.delete_gym_cascade(p_gym_id uuid)
RETURNS jsonb AS $$
DECLARE
    v_owner_user_id uuid;
    v_caller_id uuid;
    v_deleted jsonb := '{}'::jsonb;
    v_count int;
BEGIN
    -- 1. Get the caller's user ID
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Verify caller is the owner_admin of this gym
    IF NOT EXISTS (
        SELECT 1 FROM public.staff_profiles
        WHERE user_id = v_caller_id
          AND gym_id = p_gym_id
          AND role = 'owner_admin'
    ) THEN
        RAISE EXCEPTION 'Only the gym owner can delete the gym';
    END IF;

    -- 3. Get the gym owner's user_id
    SELECT owner_user_id INTO v_owner_user_id
    FROM public.gyms WHERE id = p_gym_id;

    IF v_owner_user_id IS NULL THEN
        RAISE EXCEPTION 'Gym not found';
    END IF;

    -- 4. Delete all related records in correct order (children first)
    
    -- Access logs
    DELETE FROM public.access_logs WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('access_logs', v_count);

    -- Payments
    DELETE FROM public.payments WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('payments', v_count);

    -- Ingresos
    DELETE FROM public.ingresos WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('ingresos', v_count);

    -- Product transactions (via product_id)
    DELETE FROM public.product_transactions
    WHERE product_id IN (SELECT id FROM public.products WHERE gym_id = p_gym_id);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('product_transactions', v_count);

    -- Products
    DELETE FROM public.products WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('products', v_count);

    -- Product categories
    DELETE FROM public.product_categories WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('product_categories', v_count);

    -- Promotions
    DELETE FROM public.promotions WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('promotions', v_count);

    -- Clients (public.users)
    DELETE FROM public.users WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('clients', v_count);

    -- Staff profiles
    DELETE FROM public.staff_profiles WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('staff_profiles', v_count);

    -- Membership types
    DELETE FROM public.membership_types WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('membership_types', v_count);

    -- Branches
    DELETE FROM public.branches WHERE gym_id = p_gym_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_deleted := v_deleted || jsonb_build_object('branches', v_count);

    -- Gym itself
    DELETE FROM public.gyms WHERE id = p_gym_id;
    v_deleted := v_deleted || jsonb_build_object('gym_deleted', true);

    -- 5. Delete auth identity and user
    DELETE FROM auth.identities WHERE user_id = v_owner_user_id;
    DELETE FROM auth.users WHERE id = v_owner_user_id;
    v_deleted := v_deleted || jsonb_build_object('auth_user_deleted', true);

    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Only authenticated users can call this
GRANT EXECUTE ON FUNCTION public.delete_gym_cascade(uuid) TO authenticated;
