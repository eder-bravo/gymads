-- =============================================
-- Migración: precios fijos de abono por periodo
-- Fecha: 2026-08-06
-- Descripción: Precio por día, semana, mes y año a nivel gimnasio.
--   Se guardan como columnas de `gyms` (igual que el branding) para
--   reutilizar sus políticas RLS. NULL = periodo sin precio configurado.
-- =============================================

ALTER TABLE public.gyms
    ADD COLUMN IF NOT EXISTS price_day   numeric,
    ADD COLUMN IF NOT EXISTS price_week  numeric,
    ADD COLUMN IF NOT EXISTS price_month numeric,
    ADD COLUMN IF NOT EXISTS price_year  numeric;

COMMENT ON COLUMN public.gyms.price_day   IS 'Precio fijo de abono por día';
COMMENT ON COLUMN public.gyms.price_week  IS 'Precio fijo de abono por semana';
COMMENT ON COLUMN public.gyms.price_month IS 'Precio fijo de abono por mes';
COMMENT ON COLUMN public.gyms.price_year  IS 'Precio fijo de abono por año';
