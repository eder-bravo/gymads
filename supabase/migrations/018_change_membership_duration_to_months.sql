-- =============================================
-- MIGRATION 018: CHANGE MEMBERSHIP DURATION TO MONTHS
-- =============================================

-- Rename the column and keep the same type
ALTER TABLE public.membership_types 
RENAME COLUMN duration_days TO duration_months;

-- Convert existing values (assuming 1 month = 30 days)
UPDATE public.membership_types
SET duration_months = GREATEST(1, ROUND(duration_months / 30.0));
