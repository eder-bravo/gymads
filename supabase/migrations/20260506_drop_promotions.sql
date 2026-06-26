-- =============================================================
-- Migración: Eliminar sistema de promociones
-- Fecha: 2026-05-06
-- Descripción: Elimina completamente el sistema de promociones.
--   1. Eliminar FK constraints que apuntan a promotions
--   2. Eliminar columnas de promociones en users e ingresos
--   3. Eliminar columna de promociones en payments
--   4. Eliminar la tabla promotions
-- =============================================================

-- Paso 1: Eliminar FK constraints
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_current_promotion_id_fkey;
ALTER TABLE ingresos DROP CONSTRAINT IF EXISTS ingresos_promocion_id_fkey;

-- Paso 2: Eliminar columnas de promoción en la tabla users
ALTER TABLE users
  DROP COLUMN IF EXISTS current_promotion_id,
  DROP COLUMN IF EXISTS current_promotion_name,
  DROP COLUMN IF EXISTS promotion_discount_amount,
  DROP COLUMN IF EXISTS promotion_applied_date,
  DROP COLUMN IF EXISTS promotion_expires_date;

-- Paso 3: Eliminar columnas de promoción en la tabla ingresos
ALTER TABLE ingresos
  DROP COLUMN IF EXISTS promocion_id,
  DROP COLUMN IF EXISTS promocion_nombre;

-- Paso 4: Eliminar columna de promoción en la tabla payments
ALTER TABLE payments
  DROP COLUMN IF EXISTS promotion_applied;

-- Paso 5: Eliminar la tabla promotions
DROP TABLE IF EXISTS promotions CASCADE;
