-- Actualización de la tabla access_logs para incluir el campo access_type
-- Este script debe ejecutarse en Supabase SQL Editor
--
-- ⚠️  ADVERTENCIA (2026-08-17): este script NO está versionado como
--   migración y las dos vistas que crea (daily_access_stats,
--   users_currently_inside) quedaban SECURITY DEFINER — RLS Advisor
--   lo marcó CRITICAL. Se verificó una fuga real: cualquiera con la
--   anon key, sin sesión, podía leer quién está dentro de cualquier
--   gimnasio. Corregido en
--   supabase/migrations/20260817213253_fix_security_definer_views.sql
--   (ALTER VIEW ... SET (security_invoker = on)).
--   Si vuelves a correr este script (p. ej. en una BD nueva), corre
--   también esa migración justo después, o las vistas volverán a
--   quedar sin `security_invoker` y el hueco se reabre.

-- Agregar la columna access_type si no existe
ALTER TABLE public.access_logs 
ADD COLUMN IF NOT EXISTS access_type text DEFAULT 'entrada';

-- Agregar comentarios para claridad
COMMENT ON COLUMN public.access_logs.access_type IS 'Tipo de acceso: entrada o salida';
COMMENT ON COLUMN public.access_logs.method IS 'Método de acceso: qr o rfid';
COMMENT ON COLUMN public.access_logs.user_name IS 'Nombre completo del usuario';
COMMENT ON COLUMN public.access_logs.user_number IS 'Número único del usuario';
COMMENT ON COLUMN public.access_logs.staff_user IS 'Usuario del staff que registró el acceso';

-- Crear índices para mejorar el rendimiento de las consultas
CREATE INDEX IF NOT EXISTS idx_access_logs_user_id_time ON public.access_logs(user_id, access_time DESC);
CREATE INDEX IF NOT EXISTS idx_access_logs_access_time ON public.access_logs(access_time DESC);
CREATE INDEX IF NOT EXISTS idx_access_logs_access_type ON public.access_logs(access_type);
CREATE INDEX IF NOT EXISTS idx_access_logs_method ON public.access_logs(method);

-- Crear una función para obtener el último acceso de un usuario
CREATE OR REPLACE FUNCTION get_user_last_access(user_id_param uuid)
RETURNS TABLE(
    id uuid,
    user_id uuid,
    user_name text,
    user_number text,
    access_type text,
    method text,
    staff_user text,
    access_time timestamp with time zone,
    created_at timestamp with time zone
) 
LANGUAGE sql
STABLE
AS $$
    SELECT 
        al.id,
        al.user_id,
        al.user_name,
        al.user_number,
        al.access_type,
        al.method,
        al.staff_user,
        al.access_time,
        al.created_at
    FROM public.access_logs al
    WHERE al.user_id = user_id_param
    ORDER BY al.access_time DESC
    LIMIT 1;
$$;

-- Crear una función para verificar si un usuario está actualmente dentro
CREATE OR REPLACE FUNCTION is_user_inside(user_id_param uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (SELECT al.access_type = 'entrada'
         FROM public.access_logs al
         WHERE al.user_id = user_id_param
         ORDER BY al.access_time DESC
         LIMIT 1),
        false
    );
$$;

-- Crear una vista para estadísticas de accesos diarios
CREATE OR REPLACE VIEW daily_access_stats AS
SELECT 
    DATE(access_time) as access_date,
    COUNT(*) as total_accesses,
    COUNT(*) FILTER (WHERE access_type = 'entrada') as total_entries,
    COUNT(*) FILTER (WHERE access_type = 'salida') as total_exits,
    COUNT(*) FILTER (WHERE method = 'qr') as qr_accesses,
    COUNT(*) FILTER (WHERE method = 'rfid') as rfid_accesses,
    COUNT(DISTINCT user_id) as unique_users
FROM public.access_logs
GROUP BY DATE(access_time)
ORDER BY access_date DESC;

-- Crear una vista para usuarios actualmente dentro del gimnasio
CREATE OR REPLACE VIEW users_currently_inside AS
WITH last_accesses AS (
    SELECT DISTINCT ON (user_id) 
        user_id,
        user_name,
        user_number,
        access_type,
        method,
        access_time
    FROM public.access_logs
    ORDER BY user_id, access_time DESC
)
SELECT 
    la.user_id,
    la.user_name,
    la.user_number,
    la.access_time as entry_time,
    la.method as entry_method
FROM last_accesses la
WHERE la.access_type = 'entrada'
ORDER BY la.access_time DESC;

-- Crear política RLS (Row Level Security) si no existe
ALTER TABLE public.access_logs ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si existen (para evitar duplicados)
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON public.access_logs;
DROP POLICY IF EXISTS "Allow insert access to authenticated users" ON public.access_logs;
DROP POLICY IF EXISTS "Allow update to creator" ON public.access_logs;

-- Política para permitir lectura a usuarios autenticados
CREATE POLICY "Allow read access to authenticated users"
ON public.access_logs FOR SELECT
TO authenticated
USING (true);

-- Política para permitir inserción a usuarios autenticados
CREATE POLICY "Allow insert access to authenticated users"
ON public.access_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- Política para permitir actualización solo al creador del registro
CREATE POLICY "Allow update to creator"
ON public.access_logs FOR UPDATE
TO authenticated
USING (staff_user = auth.jwt() ->> 'email');

-- Conceder permisos necesarios
GRANT SELECT, INSERT, UPDATE ON public.access_logs TO authenticated;
GRANT SELECT ON daily_access_stats TO authenticated;
GRANT SELECT ON users_currently_inside TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_last_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_inside(uuid) TO authenticated;
