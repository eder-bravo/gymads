-- =============================================
-- MIGRATION 009: MIGRATE EXISTING DATA
-- Creates default gym/branch and assigns all existing records
-- =============================================

-- This script creates a default gym and branch, then migrates
-- all existing data to belong to them.

DO $$
DECLARE
    default_gym_id uuid;
    default_branch_id uuid;
    orphan_count integer;
BEGIN
    -- Check if default gym already exists
    SELECT id INTO default_gym_id 
    FROM public.gyms 
    WHERE name = 'Default Gym' 
    LIMIT 1;
    
    -- Create default gym if not exists
    IF default_gym_id IS NULL THEN
        INSERT INTO public.gyms (name, is_active)
        VALUES ('Default Gym', true)
        RETURNING id INTO default_gym_id;
        
        RAISE NOTICE 'Created default gym: %', default_gym_id;
    ELSE
        RAISE NOTICE 'Using existing default gym: %', default_gym_id;
    END IF;
    
    -- Check if default branch already exists
    SELECT id INTO default_branch_id 
    FROM public.branches 
    WHERE gym_id = default_gym_id AND name = 'Sucursal Principal' 
    LIMIT 1;
    
    -- Create default branch if not exists
    IF default_branch_id IS NULL THEN
        INSERT INTO public.branches (gym_id, name, is_active)
        VALUES (default_gym_id, 'Sucursal Principal', true)
        RETURNING id INTO default_branch_id;
        
        RAISE NOTICE 'Created default branch: %', default_branch_id;
    ELSE
        RAISE NOTICE 'Using existing default branch: %', default_branch_id;
    END IF;
    
    -- Migrate users
    UPDATE public.users 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % users', orphan_count;
    
    -- Migrate ingresos
    UPDATE public.ingresos 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % ingresos', orphan_count;
    
    -- Migrate access_logs
    UPDATE public.access_logs 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % access_logs', orphan_count;
    
    -- Migrate products
    UPDATE public.products 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % products', orphan_count;
    
    -- Migrate product_transactions
    UPDATE public.product_transactions 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % product_transactions', orphan_count;
    
    -- Migrate promotions (only gym_id, branch_id stays NULL for gym-wide)
    UPDATE public.promotions 
    SET gym_id = default_gym_id
    WHERE gym_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % promotions', orphan_count;
    
    -- Migrate membership_types (only gym_id)
    UPDATE public.membership_types 
    SET gym_id = default_gym_id
    WHERE gym_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % membership_types', orphan_count;
    
    -- Migrate product_categories (only gym_id)
    UPDATE public.product_categories 
    SET gym_id = default_gym_id
    WHERE gym_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % product_categories', orphan_count;
    
    -- Migrate payments
    UPDATE public.payments 
    SET gym_id = default_gym_id, branch_id = default_branch_id
    WHERE gym_id IS NULL OR branch_id IS NULL;
    GET DIAGNOSTICS orphan_count = ROW_COUNT;
    RAISE NOTICE 'Updated % payments', orphan_count;
    
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Migration complete!';
    RAISE NOTICE 'Default gym ID: %', default_gym_id;
    RAISE NOTICE 'Default branch ID: %', default_branch_id;
    RAISE NOTICE '====================================';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Create a staff_profile for your admin user';
    RAISE NOTICE '2. Update the gym name to your actual gym name';
    RAISE NOTICE '====================================';
END $$;
