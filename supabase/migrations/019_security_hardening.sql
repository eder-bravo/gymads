-- =============================================
-- MIGRATION 019: SECURITY HARDENING
-- =============================================
-- ⚠️  REVISAR ANTES DE EJECUTAR EN PRODUCCIÓN.
-- Cada bloque es idempotente y NO destruye datos. Ejecutar en el
-- SQL Editor de Supabase (o vía `supabase db push`) tras revisar.
-- Cada cambio está justificado en el comentario que lo precede.
-- =============================================


-- ---------------------------------------------------------------
-- 1. gyms UPDATE debe ser solo del owner_admin
-- ---------------------------------------------------------------
-- PROBLEMA: la política actual (migración 014) permite que CUALQUIER
-- staff del gimnasio (incluido branch_staff) modifique el gimnasio
-- (nombre, branding, is_active). La configuración del gimnasio debe
-- ser responsabilidad del dueño.
-- NOTA: si tu personal de sucursal edita el branding, omite este bloque
-- o ajusta la condición.
DROP POLICY IF EXISTS "Staff can update their gym" ON public.gyms;
DROP POLICY IF EXISTS "Owner can update their gym" ON public.gyms;
CREATE POLICY "Owner can update their gym"
    ON public.gyms FOR UPDATE
    USING (id = public.current_gym_id() AND public.is_owner_admin())
    WITH CHECK (id = public.current_gym_id());


-- ---------------------------------------------------------------
-- 2. Endurecer register_gym_owner (evitar suplantación de user_id)
-- ---------------------------------------------------------------
-- PROBLEMA: la función es SECURITY DEFINER y está GRANTeada a `anon`
-- (necesario cuando la confirmación de email está activa). Recibe
-- p_user_id como parámetro; un llamador AUTENTICADO podría pasar el
-- uuid de OTRO usuario y crearle un gimnasio/perfil.
-- SOLUCIÓN: si hay sesión (auth.uid() no es null), forzar que
-- p_user_id == auth.uid(). El flujo anónimo (email sin confirmar)
-- sigue funcionando. No rompe compatibilidad con el registro normal.
CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_user_id uuid,
    p_first_name text,
    p_last_name text,
    p_gym_name text,
    p_main_branch_name text
)
RETURNS jsonb AS $$
DECLARE
    v_gym_id uuid;
    v_branch_id uuid;
    v_staff_id uuid;
    v_display_name text;
    v_result jsonb;
BEGIN
    -- NUEVO: si el llamador está autenticado, solo puede registrarse a sí mismo
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'No autorizado: p_user_id no coincide con el usuario autenticado';
    END IF;

    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a gym registered';
    END IF;

    v_display_name := trim(p_first_name || ' ' || p_last_name);

    INSERT INTO public.gyms (name, owner_user_id, is_active)
    VALUES (p_gym_name, p_user_id, true)
    RETURNING id INTO v_gym_id;

    INSERT INTO public.branches (gym_id, name, is_active)
    VALUES (v_gym_id, p_main_branch_name, true)
    RETURNING id INTO v_branch_id;

    INSERT INTO public.staff_profiles (user_id, gym_id, branch_id, role, display_name, first_name, last_name, is_active)
    VALUES (p_user_id, v_gym_id, v_branch_id, 'owner_admin', v_display_name, p_first_name, p_last_name, true)
    RETURNING id INTO v_staff_id;

    v_result := jsonb_build_object(
        'gym_id', v_gym_id,
        'branch_id', v_branch_id,
        'staff_profile_id', v_staff_id,
        'user_id', p_user_id,
        'role', 'owner_admin',
        'display_name', v_display_name,
        'gym_name', p_gym_name,
        'branch_name', p_main_branch_name
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   -- search_path fijo: evita ataques de secuestro de search_path en SECURITY DEFINER
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO authenticated;


-- ---------------------------------------------------------------
-- 3. Fijar search_path en las funciones helper SECURITY DEFINER
-- ---------------------------------------------------------------
-- BUENA PRÁCTICA: las funciones SECURITY DEFINER sin search_path fijo
-- son vulnerables a secuestro de search_path. Fijarlo a public, pg_temp.
ALTER FUNCTION public.current_branch_id()  SET search_path = public, pg_temp;
ALTER FUNCTION public.current_gym_id()     SET search_path = public, pg_temp;
ALTER FUNCTION public.current_role()       SET search_path = public, pg_temp;
ALTER FUNCTION public.is_owner_admin()     SET search_path = public, pg_temp;
ALTER FUNCTION public.delete_gym_cascade(uuid) SET search_path = public, pg_temp;


-- ---------------------------------------------------------------
-- 4. Índices útiles que faltan (búsquedas frecuentes)
-- ---------------------------------------------------------------
-- La búsqueda de clientes por RFID y por teléfono se hace en cada
-- escaneo / búsqueda. Sin índice, es un scan secuencial por sucursal.
CREATE INDEX IF NOT EXISTS idx_users_branch_rfid
    ON public.users(branch_id, rfid_card);
CREATE INDEX IF NOT EXISTS idx_users_branch_phone
    ON public.users(branch_id, phone);
-- staff_profiles se consulta por user_id en CADA request (RLS helpers).
CREATE INDEX IF NOT EXISTS idx_staff_profiles_user_active
    ON public.staff_profiles(user_id, is_active);


-- ===============================================================
-- PENDIENTES QUE REQUIEREN DECISIÓN MANUAL (NO ejecutados aquí)
-- ===============================================================
--
-- A) STORAGE BUCKET 'users' ES PÚBLICO (lectura).
--    Las fotos de clientes de TODOS los gimnasios son accesibles
--    con solo la URL pública. La app usa URLs públicas
--    (SupabaseConfig.storageUrl → /object/public), así que
--    volver el bucket privado ROMPERÍA la carga de imágenes hasta
--    migrar a URLs firmadas (createSignedUrl). Plan sugerido:
--      1. Cambiar el proveedor de storage para generar signed URLs.
--      2. Volver el bucket privado + política por tenant en el path.
--    Ver storage/storage_policies.sql (política 'FOR ALL' atada a un
--    user_id HARDCODEADO 8037aa52-... — legado single-tenant, revisar
--    en el panel de Storage cuáles políticas están REALMENTE activas).
--
-- B) BUCKET 'qrcodes' PÚBLICO y cualquier usuario autenticado puede
--    subir/actualizar/eliminar CUALQUIER objeto (sin scoping por
--    tenant ni por path). Añadir verificación de path por gym_id.
