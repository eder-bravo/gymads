-- =============================================
-- MIGRATION 005: UPDATED_AT TRIGGERS
-- Automatically sets updated_at on UPDATE
-- =============================================

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to gyms
DROP TRIGGER IF EXISTS set_updated_at_gyms ON public.gyms;
CREATE TRIGGER set_updated_at_gyms
    BEFORE UPDATE ON public.gyms
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to branches
DROP TRIGGER IF EXISTS set_updated_at_branches ON public.branches;
CREATE TRIGGER set_updated_at_branches
    BEFORE UPDATE ON public.branches
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to staff_profiles
DROP TRIGGER IF EXISTS set_updated_at_staff_profiles ON public.staff_profiles;
CREATE TRIGGER set_updated_at_staff_profiles
    BEFORE UPDATE ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to users
DROP TRIGGER IF EXISTS set_updated_at_users ON public.users;
CREATE TRIGGER set_updated_at_users
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to ingresos
DROP TRIGGER IF EXISTS set_updated_at_ingresos ON public.ingresos;
CREATE TRIGGER set_updated_at_ingresos
    BEFORE UPDATE ON public.ingresos
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to products
DROP TRIGGER IF EXISTS set_updated_at_products ON public.products;
CREATE TRIGGER set_updated_at_products
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to promotions
DROP TRIGGER IF EXISTS set_updated_at_promotions ON public.promotions;
CREATE TRIGGER set_updated_at_promotions
    BEFORE UPDATE ON public.promotions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to membership_types
DROP TRIGGER IF EXISTS set_updated_at_membership_types ON public.membership_types;
CREATE TRIGGER set_updated_at_membership_types
    BEFORE UPDATE ON public.membership_types
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Apply to product_categories
DROP TRIGGER IF EXISTS set_updated_at_product_categories ON public.product_categories;
CREATE TRIGGER set_updated_at_product_categories
    BEFORE UPDATE ON public.product_categories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
