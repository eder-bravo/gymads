-- =============================================================
-- Migración: Reestructuración a Sistema de Abonos
-- Fecha: 2026-05-06
-- Descripción:
--   1. Agregar columnas email y address a users
--   2. Hacer membership_type nullable
--   3. Eliminar tabla membership_types
-- =============================================================

-- Paso 1: Agregar columnas nuevas a users
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT NULL;

-- Paso 2: Hacer membership_type nullable
ALTER TABLE users ALTER COLUMN membership_type DROP NOT NULL;
ALTER TABLE users ALTER COLUMN membership_type SET DEFAULT NULL;

-- Paso 3: Eliminar tabla membership_types
DROP TABLE IF EXISTS membership_types CASCADE;
