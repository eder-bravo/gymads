-- El alta del gimnasio recoge también su horario.
--
-- Hasta ahora `gyms.hora_apertura` / `hora_cierre` nacían con el valor por
-- defecto (06:00–22:00) y solo se podían cambiar después, desde Configuración.
-- Preguntarlo junto al nombre evita esa segunda vuelta, y el reporte de
-- entradas ya sale bien acotado desde el primer día.
--
-- Los dos parámetros llevan DEFAULT a propósito: así una app antigua que aún
-- llame con cinco argumentos sigue funcionando. Y se hace DROP de la firma de
-- cinco antes de crear la de siete para que quede UNA sola función: convivir
-- dos versiones de register_gym_owner ya provocó una vez una resolución de
-- sobrecarga ambigua (ver 20260824214915).

DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text);

CREATE OR REPLACE FUNCTION public.register_gym_owner(
    p_user_id uuid,
    p_first_name text,
    p_last_name text,
    p_gym_name text,
    p_main_branch_name text,
    p_hora_apertura time DEFAULT '06:00',
    p_hora_cierre time DEFAULT '22:00'
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
    INSERT INTO public.gyms (name, owner_user_id, is_active, hora_apertura, hora_cierre)
    VALUES (
        p_gym_name,
        p_user_id,
        true,
        coalesce(p_hora_apertura, '06:00'::time),
        coalesce(p_hora_cierre,  '22:00'::time)
    )
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

GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text, time, time) TO anon;
GRANT EXECUTE ON FUNCTION public.register_gym_owner(uuid, text, text, text, text, time, time) TO authenticated;
