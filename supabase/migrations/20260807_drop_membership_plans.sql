-- =============================================
-- Migración: eliminar membership_plans (abonos fijos por plan)
-- Fecha: 2026-08-06
-- Descripción: Se descarta el modelo de "planes de membresía" (nombre +
--   cantidad de periodos + precio total) en favor de un precio fijo por
--   unidad de periodo, guardado en columnas de `gyms`
--   (ver 20260806_abono_prices.sql).
-- =============================================

DROP TABLE IF EXISTS public.membership_plans CASCADE;
