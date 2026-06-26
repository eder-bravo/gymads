-- =============================================
-- MIGRATION 008: AUTO-SET TENANT TRIGGERS
-- Prevents client from sending arbitrary gym_id/branch_id values
-- =============================================

-- Function to auto-set gym_id and branch_id on INSERT
CREATE OR REPLACE FUNCTION public.set_tenant_on_insert()
RETURNS trigger AS $$
BEGIN
    -- Always override with current user's tenant context
    NEW.gym_id := public.current_gym_id();
    NEW.branch_id := public.current_branch_id();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply to users table
DROP TRIGGER IF EXISTS trg_users_set_tenant ON public.users;
CREATE TRIGGER trg_users_set_tenant
    BEFORE INSERT ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- Apply to ingresos table
DROP TRIGGER IF EXISTS trg_ingresos_set_tenant ON public.ingresos;
CREATE TRIGGER trg_ingresos_set_tenant
    BEFORE INSERT ON public.ingresos
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- Apply to access_logs table
DROP TRIGGER IF EXISTS trg_access_logs_set_tenant ON public.access_logs;
CREATE TRIGGER trg_access_logs_set_tenant
    BEFORE INSERT ON public.access_logs
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- Apply to products table
DROP TRIGGER IF EXISTS trg_products_set_tenant ON public.products;
CREATE TRIGGER trg_products_set_tenant
    BEFORE INSERT ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- Apply to product_transactions table
DROP TRIGGER IF EXISTS trg_product_transactions_set_tenant ON public.product_transactions;
CREATE TRIGGER trg_product_transactions_set_tenant
    BEFORE INSERT ON public.product_transactions
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- Apply to payments table
DROP TRIGGER IF EXISTS trg_payments_set_tenant ON public.payments;
CREATE TRIGGER trg_payments_set_tenant
    BEFORE INSERT ON public.payments
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_on_insert();

-- =============================================
-- SPECIAL TRIGGER FOR PROMOTIONS
-- Allows NULL branch_id for gym-wide promos
-- =============================================

CREATE OR REPLACE FUNCTION public.set_tenant_promotions()
RETURNS trigger AS $$
BEGIN
    NEW.gym_id := public.current_gym_id();
    -- branch_id can be NULL (gym-wide) or must match current branch
    IF NEW.branch_id IS NOT NULL THEN
        NEW.branch_id := public.current_branch_id();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_promotions_set_tenant ON public.promotions;
CREATE TRIGGER trg_promotions_set_tenant
    BEFORE INSERT ON public.promotions
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_promotions();

-- =============================================
-- TRIGGER FOR GYM-LEVEL TABLES (only gym_id)
-- =============================================

CREATE OR REPLACE FUNCTION public.set_gym_on_insert()
RETURNS trigger AS $$
BEGIN
    NEW.gym_id := public.current_gym_id();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_membership_types_set_gym ON public.membership_types;
CREATE TRIGGER trg_membership_types_set_gym
    BEFORE INSERT ON public.membership_types
    FOR EACH ROW EXECUTE FUNCTION public.set_gym_on_insert();

DROP TRIGGER IF EXISTS trg_product_categories_set_gym ON public.product_categories;
CREATE TRIGGER trg_product_categories_set_gym
    BEFORE INSERT ON public.product_categories
    FOR EACH ROW EXECUTE FUNCTION public.set_gym_on_insert();
