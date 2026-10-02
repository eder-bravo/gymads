-- =============================================
-- Migración: categorías de producto por ID, con icono y orden
-- Fecha: 2026-08-24
-- Descripción:
--   1. `product_categories` gana `icon` (clave corta) y `sort_order`.
--   2. `products` pasa de guardar el NOMBRE de la categoría como texto suelto
--      a una clave foránea `category_id`. Renombrar deja de desenlazar
--      productos y la base impide borrar una categoría en uso.
--   3. Se corrige el bug por el que los gimnasios nuevos nacían sin ninguna
--      categoría: existían DOS versiones de register_gym_owner y la que
--      sembraba las 7 por defecto era la firma vieja, que la app no llama.
--   4. Se añade la política RLS de DELETE, que no existía.
--
--   Seguro de aplicar: al escribirse no hay ningún producto ni categoría en
--   la base, así que no hay datos que convertir.
-- =============================================


-- ---------------------------------------------------------------
-- 1. Columnas nuevas en product_categories
-- ---------------------------------------------------------------
ALTER TABLE public.product_categories
    ADD COLUMN IF NOT EXISTS icon       text,
    ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.product_categories.icon IS
    'Clave corta del icono (ej: bebidas, ropa). Las válidas viven en lib/app/core/utils/category_icons.dart. Sin CHECK a propósito: añadir un icono no debe exigir una migración.';
COMMENT ON COLUMN public.product_categories.sort_order IS
    'Orden manual en las listas. Se consulta con ORDER BY sort_order, name para que los empates queden alfabéticos.';


-- ---------------------------------------------------------------
-- 2. Unicidad del nombre insensible a mayúsculas y espacios
-- ---------------------------------------------------------------
-- Antes (migración 004) convivían 'Bebidas' y 'bebidas'. Se queda como índice
-- y no como constraint porque Postgres no admite constraints sobre
-- expresiones; a efectos de error da igual, un índice único también lanza
-- 23505. No es parcial: cubre también las inactivas, para que una categoría
-- desactivada bloquee crear otra con el mismo nombre y la app pueda ofrecer
-- reactivarla en vez de acabar con dos.
DROP INDEX IF EXISTS idx_product_categories_gym_name;
CREATE UNIQUE INDEX idx_product_categories_gym_name
    ON public.product_categories (gym_id, lower(btrim(name)));


-- ---------------------------------------------------------------
-- 3. products.category_id reemplaza a products.category
-- ---------------------------------------------------------------
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS category_id uuid
        REFERENCES public.product_categories(id) ON DELETE RESTRICT;

-- No es opcional: cada DELETE de categoría hace una comprobación RESTRICT
-- sobre esta columna, y sin índice sería un recorrido completo de products.
CREATE INDEX IF NOT EXISTS idx_products_category_id
    ON public.products(category_id);

COMMENT ON COLUMN public.products.category_id IS
    'Categoría del producto. ON DELETE RESTRICT: la base impide borrar una categoría que todavía tenga productos.';

-- La columna vieja de texto. OJO: al caer, cualquier cliente que siga
-- enviando 'category' falla con PGRST204, así que el modelo Dart debe
-- actualizarse en el mismo despliegue.
ALTER TABLE public.products DROP COLUMN IF EXISTS category;

-- NOTA: 017_delete_gym_cascade.sql borra products ANTES que
-- product_categories, así que el RESTRICT no rompe el borrado de cuenta.
-- No invertir ese orden.


-- ---------------------------------------------------------------
-- 4. Política RLS de DELETE (no existía ninguna)
-- ---------------------------------------------------------------
-- 007_create_rls_policies.sql definió SELECT/INSERT/UPDATE y ninguna de
-- DELETE, así que hasta ahora un borrado desde el cliente afectaba en
-- silencio a 0 filas. Se restringe al dueño, igual que en membership_types.
-- INSERT y UPDATE se dejan abiertos a todo el staff para que el atajo de
-- crear categoría desde el formulario de producto siga funcionando.
DROP POLICY IF EXISTS "Owner can delete product_categories" ON public.product_categories;
CREATE POLICY "Owner can delete product_categories"
    ON public.product_categories FOR DELETE
    USING (gym_id = public.current_gym_id() AND public.is_owner_admin());


-- ---------------------------------------------------------------
-- 5. Reordenado atómico
-- ---------------------------------------------------------------
-- SECURITY INVOKER para que siga aplicando la política RLS de UPDATE.
CREATE OR REPLACE FUNCTION public.reorder_product_categories(p_ids uuid[])
RETURNS void AS $$
    UPDATE public.product_categories c
       SET sort_order = i.ord
      FROM unnest(p_ids) WITH ORDINALITY AS i(id, ord)
     WHERE c.id = i.id
       AND c.gym_id = public.current_gym_id();
$$ LANGUAGE sql SECURITY INVOKER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.reorder_product_categories(uuid[]) TO authenticated;


-- ---------------------------------------------------------------
-- 6. EL BUG: eliminar la firma huérfana de register_gym_owner
-- ---------------------------------------------------------------
-- La migración 016 añadió la siembra de categorías por defecto, pero la
-- escribió sobre esta firma antigua, que la app no llama nunca. Resultado:
-- todo gimnasio registrado desde entonces nace sin ninguna categoría.
-- Además, tener dos sobrecargas es ambiguo para las llamadas RPC.
DROP FUNCTION IF EXISTS public.register_gym_owner(uuid, text, text, text, text[]);


-- ---------------------------------------------------------------
-- 7. La firma viva, ahora sí sembrando categorías
-- ---------------------------------------------------------------
-- Se conserva íntegro el endurecimiento de 019_security_hardening.sql:
-- guarda anti-suplantación, guarda de perfil duplicado, search_path fijo y
-- los GRANT a anon + authenticated.
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
-- 8. Backfill: gimnasios que se quedaron sin categorías por el bug
-- ---------------------------------------------------------------
DO $$
DECLARE
    v_gym RECORD;
    v_names        text[] := ARRAY['Suplementos','Bebidas','Ropa','Accesorios','Snacks','Equipamiento','Otros'];
    v_descriptions text[] := ARRAY[
        'Proteínas, creatina, pre-entrenos y más',
        'Aguas, jugos, bebidas energéticas',
        'Playeras, shorts, leggins y más',
        'Guantes, cinturones, vendas, bolsas',
        'Barras de proteína, frutos secos',
        'Cuerdas, ligas, tapetes y equipo',
        'Productos varios'
    ];
    v_icons text[] := ARRAY['suplementos','bebidas','ropa','accesorios','snacks','equipamiento','otros'];
    v_idx int;
BEGIN
    FOR v_gym IN SELECT id FROM public.gyms WHERE is_active = true LOOP
        FOR v_idx IN 1..array_length(v_names, 1) LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.product_categories
                 WHERE gym_id = v_gym.id
                   AND lower(btrim(name)) = lower(btrim(v_names[v_idx]))
            ) THEN
                INSERT INTO public.product_categories
                    (name, description, icon, sort_order, gym_id, is_active)
                VALUES
                    (v_names[v_idx], v_descriptions[v_idx], v_icons[v_idx], v_idx, v_gym.id, true);
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Cualquier fila anterior sin icono queda con el de respaldo.
UPDATE public.product_categories SET icon = 'otros' WHERE icon IS NULL;
