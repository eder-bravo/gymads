-- =============================================
-- MIGRATION 007: ROW LEVEL SECURITY POLICIES
-- Enables RLS and creates policies for all tenant tables
-- =============================================

-- Enable RLS on all tenant tables
ALTER TABLE public.gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingresos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- =============================================
-- GYMS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view their gym" ON public.gyms;
CREATE POLICY "Staff can view their gym"
    ON public.gyms FOR SELECT
    USING (id = public.current_gym_id());

-- =============================================
-- BRANCHES POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view their branch" ON public.branches;
CREATE POLICY "Staff can view their branch"
    ON public.branches FOR SELECT
    USING (id = public.current_branch_id());

DROP POLICY IF EXISTS "Owner can view all gym branches" ON public.branches;
CREATE POLICY "Owner can view all gym branches"
    ON public.branches FOR SELECT
    USING (
        gym_id = public.current_gym_id() 
        AND public.is_owner_admin()
    );

-- =============================================
-- STAFF_PROFILES POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view own profile" ON public.staff_profiles;
CREATE POLICY "Staff can view own profile"
    ON public.staff_profiles FOR SELECT
    USING (user_id = auth.uid());

-- =============================================
-- USERS (CLIENTES) POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch users" ON public.users;
CREATE POLICY "Staff can view branch users"
    ON public.users FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch users" ON public.users;
CREATE POLICY "Staff can insert branch users"
    ON public.users FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );

DROP POLICY IF EXISTS "Staff can update branch users" ON public.users;
CREATE POLICY "Staff can update branch users"
    ON public.users FOR UPDATE
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can delete branch users" ON public.users;
CREATE POLICY "Staff can delete branch users"
    ON public.users FOR DELETE
    USING (branch_id = public.current_branch_id());

-- =============================================
-- INGRESOS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can view branch ingresos"
    ON public.ingresos FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can insert branch ingresos"
    ON public.ingresos FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );

DROP POLICY IF EXISTS "Staff can update branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can update branch ingresos"
    ON public.ingresos FOR UPDATE
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can delete branch ingresos" ON public.ingresos;
CREATE POLICY "Staff can delete branch ingresos"
    ON public.ingresos FOR DELETE
    USING (branch_id = public.current_branch_id());

-- =============================================
-- ACCESS_LOGS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch access_logs" ON public.access_logs;
CREATE POLICY "Staff can view branch access_logs"
    ON public.access_logs FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch access_logs" ON public.access_logs;
CREATE POLICY "Staff can insert branch access_logs"
    ON public.access_logs FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );

-- =============================================
-- PRODUCTS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch products" ON public.products;
CREATE POLICY "Staff can view branch products"
    ON public.products FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch products" ON public.products;
CREATE POLICY "Staff can insert branch products"
    ON public.products FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );

DROP POLICY IF EXISTS "Staff can update branch products" ON public.products;
CREATE POLICY "Staff can update branch products"
    ON public.products FOR UPDATE
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can delete branch products" ON public.products;
CREATE POLICY "Staff can delete branch products"
    ON public.products FOR DELETE
    USING (branch_id = public.current_branch_id());

-- =============================================
-- PRODUCT_TRANSACTIONS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch product_transactions" ON public.product_transactions;
CREATE POLICY "Staff can view branch product_transactions"
    ON public.product_transactions FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch product_transactions" ON public.product_transactions;
CREATE POLICY "Staff can insert branch product_transactions"
    ON public.product_transactions FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );

-- =============================================
-- PROMOTIONS POLICIES (gym-level or branch-specific)
-- =============================================
DROP POLICY IF EXISTS "Staff can view applicable promotions" ON public.promotions;
CREATE POLICY "Staff can view applicable promotions"
    ON public.promotions FOR SELECT
    USING (
        gym_id = public.current_gym_id()
        AND (branch_id IS NULL OR branch_id = public.current_branch_id())
    );

DROP POLICY IF EXISTS "Staff can insert branch promotions" ON public.promotions;
CREATE POLICY "Staff can insert branch promotions"
    ON public.promotions FOR INSERT
    WITH CHECK (
        gym_id = public.current_gym_id()
        AND (branch_id IS NULL OR branch_id = public.current_branch_id())
    );

DROP POLICY IF EXISTS "Staff can update branch promotions" ON public.promotions;
CREATE POLICY "Staff can update branch promotions"
    ON public.promotions FOR UPDATE
    USING (
        gym_id = public.current_gym_id()
        AND (branch_id IS NULL OR branch_id = public.current_branch_id())
    );

-- =============================================
-- MEMBERSHIP_TYPES POLICIES (gym-level)
-- =============================================
DROP POLICY IF EXISTS "Staff can view gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can view gym membership_types"
    ON public.membership_types FOR SELECT
    USING (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Owner can manage membership_types" ON public.membership_types;
CREATE POLICY "Owner can manage membership_types"
    ON public.membership_types FOR ALL
    USING (gym_id = public.current_gym_id() AND public.is_owner_admin());

-- Also allow branch_staff to insert/update membership types
DROP POLICY IF EXISTS "Staff can insert gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can insert gym membership_types"
    ON public.membership_types FOR INSERT
    WITH CHECK (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can update gym membership_types" ON public.membership_types;
CREATE POLICY "Staff can update gym membership_types"
    ON public.membership_types FOR UPDATE
    USING (gym_id = public.current_gym_id());

-- =============================================
-- PRODUCT_CATEGORIES POLICIES (gym-level)
-- =============================================
DROP POLICY IF EXISTS "Staff can view gym product_categories" ON public.product_categories;
CREATE POLICY "Staff can view gym product_categories"
    ON public.product_categories FOR SELECT
    USING (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can insert product_categories" ON public.product_categories;
CREATE POLICY "Staff can insert product_categories"
    ON public.product_categories FOR INSERT
    WITH CHECK (gym_id = public.current_gym_id());

DROP POLICY IF EXISTS "Staff can update product_categories" ON public.product_categories;
CREATE POLICY "Staff can update product_categories"
    ON public.product_categories FOR UPDATE
    USING (gym_id = public.current_gym_id());

-- =============================================
-- PAYMENTS POLICIES
-- =============================================
DROP POLICY IF EXISTS "Staff can view branch payments" ON public.payments;
CREATE POLICY "Staff can view branch payments"
    ON public.payments FOR SELECT
    USING (branch_id = public.current_branch_id());

DROP POLICY IF EXISTS "Staff can insert branch payments" ON public.payments;
CREATE POLICY "Staff can insert branch payments"
    ON public.payments FOR INSERT
    WITH CHECK (
        branch_id = public.current_branch_id() 
        AND gym_id = public.current_gym_id()
    );
