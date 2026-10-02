-- =============================================================
-- Migración: cerrar la fuga de datos en vistas SECURITY DEFINER
-- Fecha: 2026-08-17
--
-- Hallazgo: Supabase Security Advisor marcó como CRITICAL que
--   public.daily_access_stats y public.users_currently_inside están
--   definidas como "SECURITY DEFINER". Ambas se crearon en
--   supabase/access_logs_update.sql (script suelto, ejecutado a mano
--   en el SQL Editor, nunca versionado como migración), y quedaron
--   como propiedad del rol `postgres`.
--
-- Causa raíz: en Postgres, una vista sin `security_invoker = on` se
--   ejecuta con los permisos de su DUEÑO, no de quien la consulta.
--   Como el dueño es `postgres` (bypassa RLS), ambas vistas ignoran
--   por completo las políticas RLS de la tabla `access_logs`
--   ("Staff can view branch access_logs", que exige
--   branch_id = current_branch_id()).
--
-- Impacto verificado (17/08/2026, con una fila de prueba marcada,
--   insertada y borrada en la misma sesión de verificación):
--   - Consultando `access_logs` directo con la anon key pública y SIN
--     sesión: RLS bloquea correctamente, devuelve [].
--   - Consultando `users_currently_inside` con la MISMA anon key y sin
--     sesión: devolvió nombre, número y hora de entrada del registro
--     de prueba.
--   - Consultando `daily_access_stats` sin sesión: devolvió el
--     conteo agregado del día.
--   Conclusión: cualquiera con la anon key (pública, embebida en la
--   app) podía ver en tiempo real quién está dentro de CUALQUIER
--   gimnasio del sistema, sin iniciar sesión y sin pertenecer a ese
--   gimnasio. Fuga de datos personales entre tenants y hacia
--   usuarios no autenticados.
--
-- Corrección: activar `security_invoker = on` en ambas vistas. A
--   partir de esto, cada vista se ejecuta con los permisos de quien
--   consulta, heredando las políticas RLS ya correctas de
--   `access_logs`. Un usuario sin sesión vuelve a recibir [], y un
--   miembro de staff autenticado solo ve los datos de su propia
--   sucursal (branch_id = current_branch_id()), igual que en el
--   resto de la app.
--
-- Impacto en la app: ninguno. `daily_access_stats` no se usa en
--   ningún lugar de lib/. `users_currently_inside` la lee
--   AccessLogService.getUsersCurrentlyInside(), pero ese método no
--   está conectado a ninguna pantalla todavía (código sin llamador
--   actual). No hay cambio de comportamiento visible.
-- =============================================================

ALTER VIEW public.daily_access_stats
    SET (security_invoker = on);

ALTER VIEW public.users_currently_inside
    SET (security_invoker = on);
