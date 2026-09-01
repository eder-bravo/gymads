-- =============================================
-- ACCESOS DE STAFF CON CÓDIGO DE UN SOLO USO
-- =============================================
-- El dueño del gimnasio (owner_admin) crea accesos para su personal desde
-- Configuración. Cada acceso entrega un código generado LOCALMENTE en el
-- dispositivo del dueño; aquí solo se guarda su hash SHA-256, nunca el texto
-- plano. El empleado canjea ese código una sola vez y queda ligado a un
-- staff_profiles con role='branch_staff'.
--
-- El empleado NO tiene correo ni contraseña: entra con una sesión anónima de
-- Supabase que se vincula a su perfil, de modo que auth.uid() sigue existiendo
-- y toda la RLS basada en current_gym_id()/current_branch_id() sigue aplicando
-- sin cambios.
--
-- REQUIERE: habilitar "Anonymous sign-ins" en el proyecto
--           (Authentication → Sign In / Providers).
--
-- Idempotente.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Tabla staff_accesos
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.staff_accesos (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    gym_id      uuid NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
    branch_id   uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    nombre      text NOT NULL,
    -- sha256 hex del código normalizado. NULL una vez canjeado o revocado:
    -- el código deja de existir en cuanto se usa.
    codigo_hash text,
    estado      text NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente', 'activo', 'revocado')),
    -- auth.users del empleado, una vez que canjeó el código
    user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    created_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    redeemed_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Un código pendiente no puede colisionar con otro. Parcial porque codigo_hash
-- se vacía al canjear y varios accesos canjeados tendrían NULL.
CREATE UNIQUE INDEX IF NOT EXISTS staff_accesos_codigo_hash_key
    ON public.staff_accesos (codigo_hash) WHERE codigo_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS staff_accesos_gym_idx
    ON public.staff_accesos (gym_id);

CREATE INDEX IF NOT EXISTS staff_accesos_user_idx
    ON public.staff_accesos (user_id) WHERE user_id IS NOT NULL;

DROP TRIGGER IF EXISTS set_updated_at_staff_accesos ON public.staff_accesos;
CREATE TRIGGER set_updated_at_staff_accesos
    BEFORE UPDATE ON public.staff_accesos
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ---------------------------------------------------------------
-- 2. RLS: la tabla es SOLO LECTURA para el dueño
-- ---------------------------------------------------------------
-- Todas las escrituras pasan por las RPC SECURITY DEFINER de la sección 4,
-- igual que ya se hace con register_gym_owner y delete_gym_cascade.
ALTER TABLE public.staff_accesos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner can view gym staff access" ON public.staff_accesos;
CREATE POLICY "Owner can view gym staff access"
    ON public.staff_accesos FOR SELECT
    USING (
        gym_id = public.current_gym_id()
        AND public.is_owner_admin()
    );

-- Sin políticas INSERT/UPDATE/DELETE: nadie escribe la tabla directamente.
REVOKE INSERT, UPDATE, DELETE ON public.staff_accesos FROM authenticated;
GRANT SELECT ON public.staff_accesos TO authenticated;


-- ---------------------------------------------------------------
-- 3. El dueño necesita ver a su propio equipo
-- ---------------------------------------------------------------
-- Hasta ahora staff_profiles solo tenía "Staff can view own profile"
-- (user_id = auth.uid()), así que el owner no podía listar a su personal.
DROP POLICY IF EXISTS "Owner can view gym staff profiles" ON public.staff_profiles;
CREATE POLICY "Owner can view gym staff profiles"
    ON public.staff_profiles FOR SELECT
    USING (
        gym_id = public.current_gym_id()
        AND public.is_owner_admin()
    );


-- ---------------------------------------------------------------
-- 4. RPCs de administración (solo owner_admin)
-- ---------------------------------------------------------------

-- Guarda común: exige owner y devuelve el acceso si pertenece a su gimnasio.
CREATE OR REPLACE FUNCTION public._acceso_staff_del_owner(p_acceso_id uuid)
RETURNS public.staff_accesos AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    IF NOT public.is_owner_admin() THEN
        RAISE EXCEPTION 'No autorizado: solo el dueño puede gestionar los accesos';
    END IF;

    SELECT * INTO v_acceso
    FROM public.staff_accesos
    WHERE id = p_acceso_id
      AND gym_id = public.current_gym_id()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Acceso no encontrado';
    END IF;

    RETURN v_acceso;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 4.1 Crear un acceso nuevo -------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_acceso_staff(
    p_nombre text,
    p_codigo_hash text
)
RETURNS uuid AS $$
DECLARE
    v_id uuid;
    v_nombre text;
BEGIN
    IF NOT public.is_owner_admin() THEN
        RAISE EXCEPTION 'No autorizado: solo el dueño puede crear accesos';
    END IF;

    v_nombre := nullif(btrim(p_nombre), '');
    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'El nombre es obligatorio';
    END IF;

    IF p_codigo_hash IS NULL OR length(p_codigo_hash) <> 64 THEN
        RAISE EXCEPTION 'Código inválido';
    END IF;

    INSERT INTO public.staff_accesos (gym_id, branch_id, nombre, codigo_hash, created_by)
    VALUES (
        public.current_gym_id(),
        public.current_branch_id(),
        v_nombre,
        p_codigo_hash,
        auth.uid()
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 4.2 Renombrar -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.renombrar_acceso_staff(
    p_acceso_id uuid,
    p_nombre text
)
RETURNS void AS $$
DECLARE
    v_acceso public.staff_accesos;
    v_nombre text;
BEGIN
    v_acceso := public._acceso_staff_del_owner(p_acceso_id);

    v_nombre := nullif(btrim(p_nombre), '');
    IF v_nombre IS NULL THEN
        RAISE EXCEPTION 'El nombre es obligatorio';
    END IF;

    UPDATE public.staff_accesos
    SET nombre = v_nombre
    WHERE id = p_acceso_id;

    -- Si ya lo canjeó, que el cambio se refleje en su perfil
    IF v_acceso.user_id IS NOT NULL THEN
        UPDATE public.staff_profiles
        SET display_name = v_nombre,
            first_name   = v_nombre
        WHERE user_id = v_acceso.user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 4.3 Regenerar el código ---------------------------------------------------
-- El camino para "el empleado cambió de teléfono" o "se perdió el código".
-- Desvincula el dispositivo anterior y vuelve el acceso a 'pendiente'.
CREATE OR REPLACE FUNCTION public.regenerar_codigo_staff(
    p_acceso_id uuid,
    p_codigo_hash text
)
RETURNS void AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    v_acceso := public._acceso_staff_del_owner(p_acceso_id);

    IF p_codigo_hash IS NULL OR length(p_codigo_hash) <> 64 THEN
        RAISE EXCEPTION 'Código inválido';
    END IF;

    -- El dispositivo anterior pierde el acceso: sin staff_profiles activo,
    -- current_gym_id() devuelve NULL y toda la RLS lo bloquea.
    IF v_acceso.user_id IS NOT NULL THEN
        DELETE FROM public.staff_profiles WHERE user_id = v_acceso.user_id;
        DELETE FROM auth.users WHERE id = v_acceso.user_id;
    END IF;

    UPDATE public.staff_accesos
    SET codigo_hash = p_codigo_hash,
        estado      = 'pendiente',
        user_id     = NULL,
        redeemed_at = NULL
    WHERE id = p_acceso_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 4.4 Revocar ---------------------------------------------------------------
-- Corta el acceso pero conserva la fila como registro.
CREATE OR REPLACE FUNCTION public.revocar_acceso_staff(p_acceso_id uuid)
RETURNS void AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    v_acceso := public._acceso_staff_del_owner(p_acceso_id);

    IF v_acceso.user_id IS NOT NULL THEN
        UPDATE public.staff_profiles
        SET is_active = false
        WHERE user_id = v_acceso.user_id;
    END IF;

    UPDATE public.staff_accesos
    SET estado      = 'revocado',
        codigo_hash = NULL
    WHERE id = p_acceso_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- 4.5 Eliminar por completo -------------------------------------------------
CREATE OR REPLACE FUNCTION public.eliminar_acceso_staff(p_acceso_id uuid)
RETURNS void AS $$
DECLARE
    v_acceso public.staff_accesos;
BEGIN
    v_acceso := public._acceso_staff_del_owner(p_acceso_id);

    IF v_acceso.user_id IS NOT NULL THEN
        DELETE FROM public.staff_profiles WHERE user_id = v_acceso.user_id;
        -- Borra también la cuenta anónima: no sirve para nada más.
        DELETE FROM auth.users WHERE id = v_acceso.user_id;
    END IF;

    DELETE FROM public.staff_accesos WHERE id = p_acceso_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- ---------------------------------------------------------------
-- 5. Canje del código (lo llama el empleado)
-- ---------------------------------------------------------------
-- La app crea primero una sesión anónima y después llama a esta función.
-- Devuelve el perfil con la MISMA forma que espera StaffProfileModel.fromJson,
-- incluyendo el objeto anidado `gyms`.
CREATE OR REPLACE FUNCTION public.canjear_codigo_staff(p_codigo_hash text)
RETURNS jsonb AS $$
DECLARE
    v_acceso public.staff_accesos;
    v_staff  public.staff_profiles;
    v_gym    public.gyms;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Se requiere una sesión activa';
    END IF;

    IF p_codigo_hash IS NULL OR length(p_codigo_hash) <> 64 THEN
        RAISE EXCEPTION 'Código inválido o ya utilizado';
    END IF;

    -- Un usuario solo puede pertenecer a un gimnasio (user_id es UNIQUE)
    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Esta sesión ya tiene un acceso asignado';
    END IF;

    SELECT * INTO v_acceso
    FROM public.staff_accesos
    WHERE codigo_hash = p_codigo_hash
      AND estado = 'pendiente'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Código inválido o ya utilizado';
    END IF;

    INSERT INTO public.staff_profiles (
        user_id, gym_id, branch_id, role, display_name, first_name, is_active
    )
    VALUES (
        auth.uid(), v_acceso.gym_id, v_acceso.branch_id, 'branch_staff',
        v_acceso.nombre, v_acceso.nombre, true
    )
    RETURNING * INTO v_staff;

    -- El código se consume: deja de existir incluso como hash.
    UPDATE public.staff_accesos
    SET estado      = 'activo',
        user_id     = auth.uid(),
        redeemed_at = now(),
        codigo_hash = NULL
    WHERE id = v_acceso.id;

    SELECT * INTO v_gym FROM public.gyms WHERE id = v_acceso.gym_id;

    RETURN jsonb_build_object(
        'id',           v_staff.id,
        'user_id',      v_staff.user_id,
        'gym_id',       v_staff.gym_id,
        'branch_id',    v_staff.branch_id,
        'role',         v_staff.role,
        'first_name',   v_staff.first_name,
        'last_name',    v_staff.last_name,
        'display_name', v_staff.display_name,
        'is_active',    v_staff.is_active,
        'created_at',   v_staff.created_at,
        'updated_at',   v_staff.updated_at,
        -- Anidado como lo devuelve el join `gyms(name, created_at, payment_mode)`.
        -- payment_mode es obligatorio: si llega NULL, la app reabre el asistente
        -- de configuración inicial (home_controller.checkOnboarding).
        'gyms', jsonb_build_object(
            'name',         v_gym.name,
            'created_at',   v_gym.created_at,
            'payment_mode', v_gym.payment_mode
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_temp;


-- ---------------------------------------------------------------
-- 6. GRANTs
-- ---------------------------------------------------------------
-- _acceso_staff_del_owner es un helper interno: no se expone.
REVOKE ALL ON FUNCTION public._acceso_staff_del_owner(uuid) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.crear_acceso_staff(text, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.renombrar_acceso_staff(uuid, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerar_codigo_staff(uuid, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.revocar_acceso_staff(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_acceso_staff(uuid)           TO authenticated;
-- El usuario anónimo ya es `authenticated` a ojos de Postgres.
GRANT EXECUTE ON FUNCTION public.canjear_codigo_staff(text)            TO authenticated;


-- ---------------------------------------------------------------
-- 7. Endurecer lo que abre el modo anónimo
-- ---------------------------------------------------------------
-- Habilitar sesiones anónimas significa que cualquiera con el anon key puede
-- obtener un JWT `authenticated`. Dos puntos del esquema asumían que eso no
-- podía pasar.

-- 7.a Bucket 'users': las políticas de la 020/021 son TO authenticated sin
--     ningún filtro. Un anónimo sin perfil no debe ni tocarlo. Se exige tener
--     contexto de gimnasio, es decir, un staff_profiles activo.
DROP POLICY IF EXISTS "Auth can read app storage" ON storage.objects;
CREATE POLICY "Auth can read app storage"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can insert app storage" ON storage.objects;
CREATE POLICY "Auth can insert app storage"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can update app storage" ON storage.objects;
CREATE POLICY "Auth can update app storage"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL)
    WITH CHECK (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);

DROP POLICY IF EXISTS "Auth can delete app storage" ON storage.objects;
CREATE POLICY "Auth can delete app storage"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'users' AND public.current_gym_id() IS NOT NULL);


-- 7.b register_gym_owner está GRANTeada a anon. Un usuario anónimo podría
--     crear gimnasios basura. Se conserva íntegra la definición vigente
--     (20260824214915) y se añade la guarda anti-anónimo.
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
    -- Las sesiones anónimas son para el canje de códigos de staff, no para
    -- registrar gimnasios.
    IF coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    -- Si el llamador está autenticado, solo puede registrarse a sí mismo
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'No autorizado: p_user_id no coincide con el usuario autenticado';
    END IF;

    IF EXISTS (SELECT 1 FROM public.staff_profiles WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User already has a gym registered';
    END IF;

    v_display_name := trim(p_first_name || ' ' || p_last_name);

    -- IMPORTANTE: no listar payment_mode aquí. Debe nacer NULL para que la
    -- app muestre el asistente de configuración inicial.
    INSERT INTO public.gyms (name, owner_user_id, is_active)
    VALUES (p_gym_name, p_user_id, true)
    RETURNING id INTO v_gym_id;

    INSERT INTO public.branches (gym_id, name, is_active)
    VALUES (v_gym_id, p_main_branch_name, true)
    RETURNING id INTO v_branch_id;

    INSERT INTO public.staff_profiles (user_id, gym_id, branch_id, role, display_name, first_name, last_name, is_active)
    VALUES (p_user_id, v_gym_id, v_branch_id, 'owner_admin', v_display_name, p_first_name, p_last_name, true)
    RETURNING id INTO v_staff_id;

    -- Categorías por defecto. El trigger trg_product_categories_set_gym solo
    -- rellena gym_id cuando viene NULL, así que respeta el v_gym_id explícito
    -- y no hace falta desactivarlo. id/created_at/updated_at los pone la base.
    INSERT INTO public.product_categories (name, description, icon, sort_order, gym_id, is_active) VALUES
        ('Suplementos',  'Proteínas, creatina, pre-entrenos y más', 'suplementos',  1, v_gym_id, true),
        ('Bebidas',      'Aguas, jugos, bebidas energéticas',       'bebidas',      2, v_gym_id, true),
        ('Ropa',         'Playeras, shorts, leggins y más',         'ropa',         3, v_gym_id, true),
        ('Accesorios',   'Guantes, cinturones, vendas, bolsas',     'accesorios',   4, v_gym_id, true),
        ('Snacks',       'Barras de proteína, frutos secos',        'snacks',       5, v_gym_id, true),
        ('Equipamiento', 'Cuerdas, ligas, tapetes y equipo',        'equipamiento', 6, v_gym_id, true),
        ('Otros',        'Productos varios',                        'otros',        7, v_gym_id, true);

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
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text) TO authenticated;


-- ---------------------------------------------------------------
-- 8. delete_gym_cascade debe llevarse también los accesos
-- ---------------------------------------------------------------
-- La FK a gyms es ON DELETE CASCADE, así que las filas de staff_accesos caen
-- solas. Las cuentas anónimas del staff ya las borra la función al eliminar
-- los auth.users de todo el personal del gimnasio.
