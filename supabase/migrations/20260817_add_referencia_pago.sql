-- =============================================
-- Migración: folio / referencia de la operación de pago
-- Fecha: 2026-08-16
-- Descripción: Guarda el folio de terminal, número de referencia o
--   autorización de los cobros con tarjeta y transferencia, para poder
--   conciliar la venta contra el estado de cuenta. Opcional: NULL en
--   efectivo y en cobros sin folio a la mano.
--   Se añade a `ingresos` (la tabla única de ventas y abonos), así que
--   reutiliza sus políticas RLS sin cambios.
--   Nota: la versión es 20260817 y no 20260816 porque esa ya la ocupa
--   20260816_drop_gym_branding.sql, aplicada el mismo día.
-- =============================================

ALTER TABLE public.ingresos
    ADD COLUMN IF NOT EXISTS referencia_pago text;

COMMENT ON COLUMN public.ingresos.referencia_pago IS 'Folio, referencia o autorización del pago con tarjeta/transferencia';
