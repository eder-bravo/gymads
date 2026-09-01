-- Control de accesos configurable por gimnasio.
--
-- Revierte remove_salidas_access_type.sql: aquella migración fijó
-- CHECK (access_type = 'entrada'), así que hoy la base RECHAZA cualquier
-- salida. Ahora el registro de salidas es opcional y se decide por gimnasio
-- desde Configuración, no en el esquema.

-- ══════════════════════════════════════════════════════════
-- 1. access_logs vuelve a aceptar salidas
-- ══════════════════════════════════════════════════════════

ALTER TABLE public.access_logs
  DROP CONSTRAINT IF EXISTS access_logs_access_type_check;

ALTER TABLE public.access_logs
  ADD CONSTRAINT access_logs_access_type_check
  CHECK (access_type IN ('entrada', 'salida'));

COMMENT ON COLUMN public.access_logs.access_type IS
  'entrada | salida. Las salidas solo se registran si gyms.registrar_salidas está activo.';
COMMENT ON CONSTRAINT access_logs_access_type_check ON public.access_logs IS
  'Entradas siempre; salidas cuando el gimnasio las tiene activadas.';

-- remove_salidas_access_type_alternative.sql definía este guardián con su
-- trigger comentado. Si alguien lo activó a mano en el dashboard, bloquearía
-- las salidas por debajo del CHECK.
DROP TRIGGER IF EXISTS prevent_salidas_trigger ON public.access_logs;
DROP FUNCTION IF EXISTS public.prevent_new_salidas();

-- ══════════════════════════════════════════════════════════
-- 2. Configuración de accesos a nivel gimnasio
--
-- Viven como columnas de `gyms`, junto a price_day y payment_mode, así que
-- heredan sus políticas RLS: solo el dueño escribe.
-- ══════════════════════════════════════════════════════════

ALTER TABLE public.gyms
  ADD COLUMN IF NOT EXISTS registrar_salidas boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hora_apertura time NOT NULL DEFAULT '06:00',
  ADD COLUMN IF NOT EXISTS hora_cierre time NOT NULL DEFAULT '22:00';

COMMENT ON COLUMN public.gyms.registrar_salidas IS
  'Si está activo, el segundo pase del día marca la salida del cliente.';
COMMENT ON COLUMN public.gyms.hora_apertura IS
  'Apertura del gimnasio. Acota el desglose por franja horaria del reporte de entradas.';
COMMENT ON COLUMN public.gyms.hora_cierre IS
  'Cierre del gimnasio. Acota el desglose por franja horaria del reporte de entradas.';
