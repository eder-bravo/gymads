-- =============================================
-- Migración: modo de cobro de abonos por gimnasio
-- Fecha: 2026-08-24
-- Descripción: Define si el gimnasio cobra con precios fijos ('fijo') o
--   escribiendo el precio en cada cobro ('libre'). Se guarda como columna de
--   `gyms`, igual que los precios de abono, para reutilizar sus políticas RLS.
--
--   NULL significa "asistente de configuración inicial pendiente": es la señal
--   que dispara la bienvenida para gimnasios recién registrados.
-- =============================================

ALTER TABLE public.gyms
    ADD COLUMN IF NOT EXISTS payment_mode text
        CHECK (payment_mode IN ('fijo', 'libre'));

COMMENT ON COLUMN public.gyms.payment_mode IS
    'Modo de cobro por defecto en Abonar: fijo | libre | NULL (asistente inicial pendiente)';

-- Backfill: todo gimnasio que exista al momento de aplicar esta migración
-- queda en 'libre' de forma silenciosa (mismo comportamiento que tenían hasta
-- ahora). Nunca ven el asistente ni el tour de bienvenida.
UPDATE public.gyms
SET payment_mode = 'libre'
WHERE payment_mode IS NULL;

-- IMPORTANTE: la columna NO lleva DEFAULT y register_gym_owner() (definida en
-- 019_security_hardening.sql) NO debe asignarle valor en su INSERT. Los
-- gimnasios creados después de este backfill deben nacer con payment_mode NULL
-- para que la app les muestre el asistente de configuración inicial.
