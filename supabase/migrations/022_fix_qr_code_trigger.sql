-- =============================================
-- MIGRATION 022: ELIMINAR TRIGGER QUE REFERENCIA qr_code
-- =============================================
-- La columna qr_code fue eliminada en la migración 021, pero el
-- trigger "trigger_auto_generate_user_codes" y su función
-- "auto_generate_user_codes" aún referencian NEW.qr_code,
-- causando error 42703 al insertar usuarios.
--
-- Se reemplaza la función para que solo genere user_number
-- (sin tocar qr_code), y se limpia la función auxiliar
-- generate_unique_qr_code que ya no se necesita.
-- =============================================


-- 1. Reemplazar la función auto_generate_user_codes sin la parte de qr_code
CREATE OR REPLACE FUNCTION public.auto_generate_user_codes()
RETURNS trigger AS $$
BEGIN
  -- Generar número de usuario si no se proporciona
  IF NEW.user_number IS NULL OR NEW.user_number = '' THEN
    NEW.user_number := generate_unique_user_number();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Eliminar la función auxiliar de QR que ya no se usa
DROP FUNCTION IF EXISTS public.generate_unique_qr_code() CASCADE;

-- 3. También eliminar el trigger duplicado update_users_updated_at
--    (ya existe set_updated_at_users con la misma función)
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

-- 4. Verificar que la columna qr_code no existe (por si acaso)
ALTER TABLE public.users DROP COLUMN IF EXISTS qr_code;
