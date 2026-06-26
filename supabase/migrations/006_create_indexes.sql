-- =============================================
-- MIGRATION 006: PERFORMANCE INDEXES
-- Indexes optimized for multi-tenant queries
-- =============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON public.users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_gym_id ON public.users(gym_id);
CREATE INDEX IF NOT EXISTS idx_users_branch_active ON public.users(branch_id, is_active);

-- Access logs indexes
CREATE INDEX IF NOT EXISTS idx_access_logs_branch_id ON public.access_logs(branch_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_branch_time 
    ON public.access_logs(branch_id, access_time DESC);

-- Ingresos indexes
CREATE INDEX IF NOT EXISTS idx_ingresos_branch_id ON public.ingresos(branch_id);
CREATE INDEX IF NOT EXISTS idx_ingresos_branch_fecha 
    ON public.ingresos(branch_id, fecha DESC);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_branch_id ON public.products(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_branch_active 
    ON public.products(branch_id, is_active);

-- Product transactions indexes
CREATE INDEX IF NOT EXISTS idx_product_transactions_branch_id 
    ON public.product_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_product_transactions_branch_product_date 
    ON public.product_transactions(branch_id, product_id, transaction_date DESC);

-- Promotions indexes
CREATE INDEX IF NOT EXISTS idx_promotions_gym_id ON public.promotions(gym_id);
CREATE INDEX IF NOT EXISTS idx_promotions_branch_id 
    ON public.promotions(branch_id) WHERE branch_id IS NOT NULL;

-- Membership types index
CREATE INDEX IF NOT EXISTS idx_membership_types_gym_id ON public.membership_types(gym_id);

-- Payments indexes
CREATE INDEX IF NOT EXISTS idx_payments_branch_id ON public.payments(branch_id);
CREATE INDEX IF NOT EXISTS idx_payments_gym_id ON public.payments(gym_id);
