-- =============================================
-- ELIMINAR POLÍTICAS PÚBLICAS DEL BUCKET 'users'
-- =============================================
-- HALLAZGO (crítico):
--   storage.objects tenía cuatro políticas 'All 1ufimg_0..3' sobre el rol
--   PUBLIC (es decir, también `anon`) con la única condición
--   `bucket_id = 'users'`. No provienen de ninguna migración: el nombre es el
--   que genera el editor de políticas del dashboard, así que se crearon a mano.
--
--   Efecto: cualquiera con el anon key podía LEER, INSERTAR, ACTUALIZAR y
--   BORRAR las fotos de clientes de TODOS los gimnasios, sin sesión alguna.
--   El bucket es privado desde la 020, pero RLS lo abría igualmente.
--
--   Además, como las políticas permisivas se combinan con OR, anulaban por
--   completo el endurecimiento aplicado en la migración anterior
--   (20260827000107, sección 7.a).
--
-- El acceso legítimo lo siguen dando las políticas "Auth can ... app storage",
-- que exigen `authenticated` + un staff_profiles activo (current_gym_id()).
-- =============================================

DROP POLICY IF EXISTS "All 1ufimg_0" ON storage.objects;
DROP POLICY IF EXISTS "All 1ufimg_1" ON storage.objects;
DROP POLICY IF EXISTS "All 1ufimg_2" ON storage.objects;
DROP POLICY IF EXISTS "All 1ufimg_3" ON storage.objects;

-- Barrido de las políticas legacy atadas a un user_id fijo del modelo
-- single-tenant (ver supabase/storage_policies.sql).
DROP POLICY IF EXISTS "Usuario autorizado puede administrar archivos" ON storage.objects;
DROP POLICY IF EXISTS "Acceso público de lectura" ON storage.objects;
