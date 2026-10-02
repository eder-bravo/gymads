-- =============================================
-- Eliminar la personalización (branding) del gimnasio
-- =============================================
-- Las columnas brand_color / brand_font se crearon manualmente en el
-- dashboard de Supabase (no existe migración que las añada). La app ya
-- no las lee ni las escribe: la personalización de nombre, color y
-- tipografía se eliminó por completo y el nombre del gimnasio se edita
-- desde "Mi Cuenta".
ALTER TABLE public.gyms
  DROP COLUMN IF EXISTS brand_color,
  DROP COLUMN IF EXISTS brand_font;
