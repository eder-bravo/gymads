-- =============================================
-- MIGRATION 004: UPDATE UNIQUE CONSTRAINTS FOR MULTI-TENANT
-- Converts global uniques to per-branch uniques
-- =============================================

-- Drop old unique constraints on users (if they exist)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_user_number_key;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_qr_code_key;

-- Create new unique constraints per branch
DROP INDEX IF EXISTS idx_users_branch_user_number;
CREATE UNIQUE INDEX idx_users_branch_user_number 
    ON public.users(branch_id, user_number);

DROP INDEX IF EXISTS idx_users_branch_qr_code;
CREATE UNIQUE INDEX idx_users_branch_qr_code 
    ON public.users(branch_id, qr_code) 
    WHERE qr_code IS NOT NULL;

-- RFID cards unique per branch (partial index for non-null)
DROP INDEX IF EXISTS idx_users_branch_rfid_card;
CREATE UNIQUE INDEX idx_users_branch_rfid_card 
    ON public.users(branch_id, rfid_card) 
    WHERE rfid_card IS NOT NULL;

-- Update access_type constraint to allow 'salida'
ALTER TABLE public.access_logs 
    DROP CONSTRAINT IF EXISTS access_logs_access_type_check;
    
ALTER TABLE public.access_logs 
    ADD CONSTRAINT access_logs_access_type_check 
    CHECK (access_type IN ('entrada', 'salida'));

-- Unique product name per branch
DROP INDEX IF EXISTS products_name_key;
DROP INDEX IF EXISTS idx_products_branch_name;
CREATE UNIQUE INDEX idx_products_branch_name 
    ON public.products(branch_id, name);

-- Unique membership type name per gym
ALTER TABLE public.membership_types 
    DROP CONSTRAINT IF EXISTS membership_types_name_key;

DROP INDEX IF EXISTS idx_membership_types_gym_name;
CREATE UNIQUE INDEX idx_membership_types_gym_name 
    ON public.membership_types(gym_id, name);

-- Unique product category name per gym
ALTER TABLE public.product_categories 
    DROP CONSTRAINT IF EXISTS product_categories_name_key;

DROP INDEX IF EXISTS idx_product_categories_gym_name;
CREATE UNIQUE INDEX idx_product_categories_gym_name 
    ON public.product_categories(gym_id, name);
