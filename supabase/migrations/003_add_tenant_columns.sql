-- =============================================
-- MIGRATION 003: ADD TENANT COLUMNS + CLEAN DATA + ADD FKs
-- =============================================

-- USERS (clientes)
ALTER TABLE public.users 
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- INGRESOS
ALTER TABLE public.ingresos
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- ACCESS_LOGS
ALTER TABLE public.access_logs
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- PRODUCTS
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- PRODUCT_TRANSACTIONS
ALTER TABLE public.product_transactions
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- PROMOTIONS (branch_id nullable = applies to whole gym)
ALTER TABLE public.promotions
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- MEMBERSHIP_TYPES (only gym_id, no branch)
ALTER TABLE public.membership_types
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id);

-- PRODUCT_CATEGORIES (only gym_id, no branch)
ALTER TABLE public.product_categories
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id);

-- PAYMENTS
ALTER TABLE public.payments
    ADD COLUMN IF NOT EXISTS gym_id uuid REFERENCES public.gyms(id),
    ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);

-- =============================================
-- CLEAN ORPHANED DATA BEFORE ADDING FKs
-- =============================================

-- Fix orphaned cliente_id in ingresos (references deleted users)
UPDATE public.ingresos 
SET cliente_id = NULL 
WHERE cliente_id IS NOT NULL 
  AND cliente_id NOT IN (SELECT id FROM public.users);

-- Fix orphaned promocion_id in ingresos (references deleted promotions)
UPDATE public.ingresos 
SET promocion_id = NULL 
WHERE promocion_id IS NOT NULL 
  AND promocion_id NOT IN (SELECT id FROM public.promotions);

-- Fix orphaned user_id in access_logs (if any)
UPDATE public.access_logs 
SET user_id = NULL 
WHERE user_id IS NOT NULL 
  AND user_id NOT IN (SELECT id FROM public.users);

-- Fix orphaned user_id in payments (if any)
UPDATE public.payments 
SET user_id = NULL 
WHERE user_id IS NOT NULL 
  AND user_id NOT IN (SELECT id FROM public.users);

-- =============================================
-- ADD FKs TO INGRESOS (after cleanup)
-- =============================================

-- Only add if constraint doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'ingresos_cliente_id_fkey'
          AND table_name = 'ingresos'
    ) THEN
        ALTER TABLE public.ingresos
            ADD CONSTRAINT ingresos_cliente_id_fkey 
            FOREIGN KEY (cliente_id) REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'ingresos_promocion_id_fkey'
          AND table_name = 'ingresos'
    ) THEN
        ALTER TABLE public.ingresos
            ADD CONSTRAINT ingresos_promocion_id_fkey 
            FOREIGN KEY (promocion_id) REFERENCES public.promotions(id) ON DELETE SET NULL;
    END IF;
END $$;
