-- =============================================================
-- Migración: eliminar users.membership_type
-- Fecha: 2026-09-04
-- Descripción:
--   La columna es el último resto del modelo de "tipos de membresía".
--   La tabla `membership_types` se eliminó en 20260506_abono_restructure
--   y `membership_plans` en 20260807_drop_membership_plans: el cobro se
--   hace con precio por periodo en `gyms` (ver 20260806_abono_prices).
--   Desde entonces la columna quedó nullable y sin nadie que la escriba,
--   así que la app ya no la lee ni la envía.
--
--   Nota: `ingresos.tipo_membresia` NO se toca; se reusó como descripción
--   del abono y sigue en uso.
-- =============================================================

ALTER TABLE public.users DROP COLUMN IF EXISTS membership_type;
