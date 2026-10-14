-- Los productos ya no tienen descripción ni categoría.
--
-- En el mostrador nadie las llenaba con cuidado y estorbaban: el formulario
-- exigía elegir una categoría, Inventario y Vender mostraban una fila de
-- filtros y la descripción ocupaba espacio en cada ficha. La app dejó de
-- usarlas, así que se quitan de la base junto con lo que solo existía para
-- ellas.
--
-- Ojo: una versión anterior de la app que intente guardar un producto manda
-- `description` y `category_id`, y falla hasta actualizarse.

-- 1. Realtime ya no escucha las categorías. (Borrar la tabla también la
--    sacaría de la publicación; se hace explícito para que se lea aquí.)
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'product_categories'
  ) then
    alter publication supabase_realtime drop table public.product_categories;
  end if;
end $$;

-- 2. Las columnas del producto. Con category_id se van su llave foránea a
--    product_categories y el índice idx_products_category_id.
ALTER TABLE public.products DROP COLUMN IF EXISTS category_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS description;

-- 3. El orden de las categorías y la tabla misma (con sus políticas, sus
--    triggers y su índice de nombre único). set_gym_on_insert() se queda:
--    también la usa membership_plans.
DROP FUNCTION IF EXISTS public.reorder_product_categories(uuid[]);
DROP TABLE IF EXISTS public.product_categories;

-- 4. El alta del gimnasio ya no crea las categorías por defecto. Misma firma
--    de siete argumentos que 20260901231221_registrar_gimnasio_con_horario,
--    sin el INSERT a product_categories.
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

-- 5. Sin categorías no hay permiso de gestionarlas. Igual que en
--    20260907232741_jerarquia_roles_staff, sin 'gestionar_categorias'
--    (la app ya no lo tiene en Permission).
CREATE OR REPLACE FUNCTION public.staff_puede(p_permiso text)
RETURNS boolean AS $$
    SELECT CASE (
        SELECT role
        FROM public.staff_profiles
        WHERE user_id = auth.uid()
          AND is_active = true
        LIMIT 1
    )
        WHEN 'owner_admin' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'gestionar_productos', 'ajustar_stock',
            'ver_ingresos', 'ver_accesos',
            'gestionar_precios_abonos', 'gestionar_control_accesos',
            'editar_gimnasio', 'gestionar_accesos_staff', 'eliminar_gimnasio'
        ])
        WHEN 'encargado' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'gestionar_productos', 'ajustar_stock',
            'ver_ingresos', 'ver_accesos',
            'gestionar_precios_abonos', 'gestionar_control_accesos',
            'editar_gimnasio', 'gestionar_accesos_staff'
        ])
        WHEN 'branch_staff' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_inventario', 'ajustar_stock',
            'ver_ingresos', 'ver_accesos'
        ])
        WHEN 'almacen' THEN p_permiso = ANY (ARRAY[
            'ver_inventario', 'gestionar_productos', 'ajustar_stock'
        ])
        WHEN 'mostrador' THEN p_permiso = ANY (ARRAY[
            'gestionar_clientes', 'cobrar_abonos', 'vender',
            'ver_ingresos', 'ver_accesos', 'recibir_alertas_nfc'
        ])
        -- Sin perfil activo no se puede nada.
        ELSE false
    END;
$$ LANGUAGE sql STABLE SECURITY DEFINER
   SET search_path = public, pg_temp;
