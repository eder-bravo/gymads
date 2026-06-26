-- =============================================
-- MIGRATION 016: DEFAULT PRODUCT CATEGORIES
-- Adds default product categories for all existing and new gyms.
-- Updates register_gym_owner to auto-create categories on registration.
-- =============================================

-- 1. Insert default categories for ALL existing gyms that don't have them yet
DO $$
DECLARE
    v_gym RECORD;
    v_categories TEXT[] := ARRAY[
        'Suplementos',
        'Bebidas',
        'Ropa',
        'Accesorios',
        'Snacks',
        'Equipamiento',
        'Otros'
    ];
    v_descriptions TEXT[] := ARRAY[
        'Proteínas, creatina, pre-entrenos y más',
        'Aguas, jugos, bebidas energéticas',
        'Playeras, shorts, leggins y más',
        'Guantes, cinturones, vendas, bolsas',
        'Barras de proteína, frutos secos',
        'Cuerdas, ligas, tapetes y equipo',
        'Productos varios'
    ];
    v_cat TEXT;
    v_idx INT;
BEGIN
    -- Disable trigger that overwrites gym_id using auth.uid()
    ALTER TABLE public.product_categories DISABLE TRIGGER trg_product_categories_set_gym;
    
    FOR v_gym IN SELECT id FROM public.gyms WHERE is_active = true
    LOOP
        FOR v_idx IN 1..array_length(v_categories, 1)
        LOOP
            v_cat := v_categories[v_idx];
            -- Only insert if this gym doesn't already have a category with that name
            IF NOT EXISTS (
                SELECT 1 FROM public.product_categories
                WHERE gym_id = v_gym.id AND name = v_cat
            ) THEN
                INSERT INTO public.product_categories (name, description, gym_id, is_active)
                VALUES (v_cat, v_descriptions[v_idx], v_gym.id, true);
            END IF;
        END LOOP;
    END LOOP;
    
    -- Re-enable trigger
    ALTER TABLE public.product_categories ENABLE TRIGGER trg_product_categories_set_gym;
    
    RAISE NOTICE 'Default categories inserted for all existing gyms';
END $$;


-- 2. Update register_gym_owner to also create default categories
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text[]);

CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_user_id uuid,
    p_owner_name text,
    p_gym_name text,
    p_main_branch_name text,
    p_additional_branches text[] DEFAULT '{}'
)
RETURNS jsonb AS $$
DECLARE
    v_gym_id uuid;
    v_main_branch_id uuid;
    v_staff_id uuid;
    v_branch_name text;
    v_result jsonb;
BEGIN
    -- Validate: user must NOT already have a staff_profile (prevent duplicates)
    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a gym registered';
    END IF;
    
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
    
    -- 4. Create staff_profile (owner_admin, assigned to main branch)
    INSERT INTO public.staff_profiles (user_id, gym_id, branch_id, role, display_name, is_active)
    VALUES (p_user_id, v_gym_id, v_main_branch_id, 'owner_admin', p_owner_name, true)
    RETURNING id INTO v_staff_id;
    
    -- 5. Create default product categories for the new gym
    INSERT INTO public.product_categories (name, description, gym_id, is_active) VALUES
        ('Suplementos', 'Proteínas, creatina, pre-entrenos y más', v_gym_id, true),
        ('Bebidas', 'Aguas, jugos, bebidas energéticas', v_gym_id, true),
        ('Ropa', 'Playeras, shorts, leggins y más', v_gym_id, true),
        ('Accesorios', 'Guantes, cinturones, vendas, bolsas', v_gym_id, true),
        ('Snacks', 'Barras de proteína, frutos secos', v_gym_id, true),
        ('Equipamiento', 'Cuerdas, ligas, tapetes y equipo', v_gym_id, true),
        ('Otros', 'Productos varios', v_gym_id, true);
    
    -- 6. Build result JSON
    v_result := jsonb_build_object(
        'gym_id', v_gym_id,
        'branch_id', v_main_branch_id,
        'staff_profile_id', v_staff_id,
        'user_id', p_user_id,
        'role', 'owner_admin',
        'display_name', p_owner_name,
        'gym_name', p_gym_name,
        'branch_name', p_main_branch_name
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant to BOTH anon and authenticated
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text[]) TO authenticated;
