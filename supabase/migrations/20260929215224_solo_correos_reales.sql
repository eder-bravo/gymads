-- Solo se aceptan correos de proveedores reales (Gmail, Outlook, Yahoo,
-- iCloud…) y de escuelas o gobierno (.edu, .edu.mx, .gob.mx).
--
-- Reemplaza la lista de correos temporales (20260929204616): una lista de
-- temporales siempre va detrás, porque salen dominios nuevos todos los días
-- (hudzer.com, por ejemplo, no estaba en ninguna lista pública). Aquí es al
-- revés: lo que no es un proveedor conocido no pasa, y esa lista corta casi
-- no cambia. Sin descargas ni tareas programadas.
--
-- La misma regla está en la app (lib/app/core/utils/correo_valido.dart):
-- si cambia una, cambia la otra.
--
-- Solo aplica a cuentas nuevas con correo y contraseña. No toca:
--   - las cuentas de Google (Google ya verificó el correo; incluye
--     Workspace con dominio propio),
--   - las anónimas del staff (no tienen correo),
--   - a nadie que ya tenga cuenta: iniciar sesión no revisa esto.

-- Lo anterior, fuera.
select cron.unschedule(jobid) from cron.job
where jobname = 'actualizar-dominios-temporales';
drop trigger if exists rechazar_correo_temporal on auth.users;
drop function if exists public.rechazar_correo_temporal();
drop function if exists public.actualizar_dominios_temporales();
drop function if exists public.es_correo_temporal(text);
drop table if exists public.dominios_correo_temporal;
drop extension if exists http;

-- ¿Es un correo de un proveedor real?
create or replace function public.correo_permitido(correo text)
returns boolean
language sql
immutable
as $$
  select d = any (array[
    -- Google
    'gmail.com', 'googlemail.com',
    -- Microsoft
    'outlook.com', 'outlook.es', 'outlook.com.mx',
    'hotmail.com', 'hotmail.es', 'hotmail.com.mx',
    'live.com', 'live.com.mx', 'msn.com',
    -- Yahoo
    'yahoo.com', 'yahoo.com.mx', 'yahoo.es', 'ymail.com',
    -- Apple
    'icloud.com', 'me.com', 'mac.com',
    -- Otros conocidos
    'proton.me', 'protonmail.com', 'aol.com', 'prodigy.net.mx'
  ])
  -- Escuelas y gobierno: los dominios .edu, .edu.xx, .gob.mx y .gov los da
  -- solo el registro oficial a instituciones, no se compran como cualquiera.
  or d ~ '\.(edu(\.[a-z]{2})?|gob\.mx|gov)$'
  from (select lower(trim(split_part(coalesce(correo, ''), '@', 2))) as d) x
$$;

revoke all on function public.correo_permitido(text) from public, anon, authenticated;

create or replace function public.rechazar_correo_no_permitido()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.email, '') <> ''
     and coalesce(new.raw_app_meta_data ->> 'provider', '') = 'email'
     and not public.correo_permitido(new.email) then
    raise exception 'correo_no_permitido: solo se aceptan correos de proveedores reales'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.rechazar_correo_no_permitido() from public, anon, authenticated;

-- Al crear la cuenta...
drop trigger if exists rechazar_correo_no_permitido on auth.users;
create trigger rechazar_correo_no_permitido
  before insert on auth.users
  for each row execute function public.rechazar_correo_no_permitido();

-- ...y al cambiar el correo (solo si de verdad cambia: el servidor de
-- autenticación reescribe la fila en cada inicio de sesión, y no debe
-- bloquear a quien ya tenía su cuenta).
drop trigger if exists rechazar_correo_no_permitido_cambio on auth.users;
create trigger rechazar_correo_no_permitido_cambio
  before update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.rechazar_correo_no_permitido();
