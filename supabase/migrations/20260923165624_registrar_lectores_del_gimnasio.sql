-- =============================================
-- LECTORES DE TARJETAS DE CADA GIMNASIO
-- =============================================
-- Qué lector (ESP32) tiene cada gimnasio y en qué IP se le vio por última
-- vez.
--
-- Hasta ahora eso vivía SOLO en la memoria del teléfono que lo configuró.
-- Cualquier otro teléfono del gimnasio (el de mostrador, que es justo el que
-- recibe los avisos), una reinstalación o un teléfono nuevo no sabían que el
-- gimnasio tenía lector: la app decía "Sin lector" y no lo buscaba.
--
-- Con esta tabla, todos los teléfonos del gimnasio saben qué lector buscar y
-- lo encuentran en la red por su id aunque el router le cambie la IP.
--
-- La tabla es un ESPEJO: quien decide a qué gimnasio pertenece un lector es
-- el propio aparato (guarda el gym_id y solo contesta a ese gimnasio). Por
-- eso la clave es (gym_id, id) y no solo el id: si un lector pasa a otro
-- gimnasio, la fila del anterior se queda y el aparato le contesta "no es
-- tuyo", que es la verdad. Un gimnasio no puede tocar las filas de otro.
--
-- Idempotente.
-- =============================================

CREATE TABLE IF NOT EXISTS public.lectores (
    gym_id       uuid NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
    -- MAC del aparato, 12 hexadecimales en mayúscula. Es su identidad física:
    -- no cambia con la IP ni con un reset de fábrica.
    id           text NOT NULL CHECK (id ~ '^[0-9A-F]{12}$'),
    ultima_ip    text CHECK (ultima_ip IS NULL
                             OR ultima_ip ~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'),
    version      text,
    vinculado_en timestamptz NOT NULL DEFAULT now(),
    visto_en     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (gym_id, id)
);

COMMENT ON TABLE public.lectores IS
    'Lectores de tarjetas (ESP32) de cada gimnasio. Espejo de lo que el
     aparato guarda: el lector decide a quién contesta.';

ALTER TABLE public.lectores ENABLE ROW LEVEL SECURITY;

-- Todo el personal del gimnasio lo ve: el teléfono de mostrador necesita
-- saber qué lector buscar para recibir los avisos.
DROP POLICY IF EXISTS "Staff can view gym readers" ON public.lectores;
CREATE POLICY "Staff can view gym readers"
    ON public.lectores FOR SELECT
    TO authenticated
    USING (gym_id = public.current_gym_id());

-- Dar de alta o quitar un lector es de quien administra la pantalla del
-- lector (dueño y encargado).
DROP POLICY IF EXISTS "Staff can register gym readers" ON public.lectores;
CREATE POLICY "Staff can register gym readers"
    ON public.lectores FOR INSERT
    TO authenticated
    WITH CHECK (gym_id = public.current_gym_id()
                AND public.staff_puede('gestionar_control_accesos'));

DROP POLICY IF EXISTS "Staff can remove gym readers" ON public.lectores;
CREATE POLICY "Staff can remove gym readers"
    ON public.lectores FOR DELETE
    TO authenticated
    USING (gym_id = public.current_gym_id()
           AND public.staff_puede('gestionar_control_accesos'));

-- Actualizar (la IP nueva cuando el router se la cambia) lo puede cualquiera
-- del personal: quien lo reencuentra suele ser el teléfono de mostrador. No
-- puede sacarlo de su gimnasio (WITH CHECK).
DROP POLICY IF EXISTS "Staff can update gym readers" ON public.lectores;
CREATE POLICY "Staff can update gym readers"
    ON public.lectores FOR UPDATE
    TO authenticated
    USING (gym_id = public.current_gym_id())
    WITH CHECK (gym_id = public.current_gym_id());

REVOKE ALL ON public.lectores FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lectores TO authenticated;
