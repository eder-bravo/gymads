-- Borrar las fotos de los clientes también desde la base de datos.
--
-- Borrar un cliente, un gimnasio o una cuenta desde el panel de Supabase o
-- desde SQL dejaba sus fotos en el almacenamiento. Borrar de storage.objects
-- con SQL no sirve (Supabase lo bloquea, y el archivo real se quedaría): solo
-- la API de Storage borra de verdad, y necesita la llave de servicio. Por eso
-- la base de datos le avisa a la Edge Function `borrar-fotos`
-- (supabase/functions/borrar-fotos), que ya trae esa llave en su entorno.
--
-- Tres caminos, todos hacia la misma función:
--   1. Se borra un cliente (también en cascada: gimnasio, cuenta del dueño).
--   2. A un cliente le cambian la foto: se borra la anterior.
--   3. Cada día se borran las fotos que ningún cliente usa (redes de
--      seguridad: fotos subidas que nunca se guardaron, borrados de antes
--      de esta migración...).
--
-- El secreto compartido con la función está en el vault (`secreto_borrado_fotos`),
-- no en este archivo. Si falta, no se borra nada y se avisa: NUNCA se impide
-- borrar un cliente por esto.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------
-- La ruta dentro del bucket `users` de lo que guarda users.photo_url
-- (URL pública, firmada o ruta cruda). Null si no apunta a una foto.
-- ---------------------------------------------------------------
create or replace function public.ruta_de_foto(p_foto text)
returns text
language sql
immutable
as $$
  select case
    when p_foto is null or p_foto = '' then null
    when p_foto ~ '/object/(public|sign|authenticated)/users/'
      then substring(p_foto from '/object/(?:public|sign|authenticated)/users/([^?]+)')
    when p_foto like 'http%' then null
    else p_foto
  end
$$;

-- ---------------------------------------------------------------
-- Pedir a la Edge Function que borre estas rutas.
-- ---------------------------------------------------------------
create or replace function public.pedir_borrado_de_fotos(p_rutas text[])
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_secreto text;
begin
  if p_rutas is null or cardinality(p_rutas) = 0 then
    return;
  end if;

  select decrypted_secret into v_secreto
  from vault.decrypted_secrets
  where name = 'secreto_borrado_fotos';

  if v_secreto is null then
    raise warning 'No se borran fotos: falta el secreto secreto_borrado_fotos en el vault';
    return;
  end if;

  perform net.http_post(
    url     := 'https://olhbhnjhducfxkffercu.supabase.co/functions/v1/borrar-fotos',
    body    := jsonb_build_object('rutas', to_jsonb(p_rutas)),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-secreto', v_secreto
    ),
    timeout_milliseconds := 30000
  );
exception when others then
  -- Nunca impedir el borrado de un cliente por esto.
  raise warning 'No se pudo pedir el borrado de fotos: %', sqlerrm;
end;
$$;

revoke all on function public.pedir_borrado_de_fotos(text[]) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- 1 y 2. Al borrar un cliente o cambiarle la foto.
-- ---------------------------------------------------------------
create or replace function public.borrar_foto_de_cliente()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruta text;
begin
  if tg_op = 'DELETE'
     or (tg_op = 'UPDATE' and old.photo_url is distinct from new.photo_url) then
    v_ruta := public.ruta_de_foto(old.photo_url);
    if v_ruta is not null then
      perform public.pedir_borrado_de_fotos(array[v_ruta]);
    end if;
  end if;
  return null;
end;
$$;

revoke all on function public.borrar_foto_de_cliente() from public, anon, authenticated;

drop trigger if exists borrar_foto_de_cliente on public.users;
create trigger borrar_foto_de_cliente
  after delete or update of photo_url on public.users
  for each row execute function public.borrar_foto_de_cliente();

-- ---------------------------------------------------------------
-- 3. Limpieza diaria: fotos que ningún cliente usa.
-- ---------------------------------------------------------------
-- Con una hora de margen: la foto se sube ANTES de guardar al cliente, y no
-- hay que borrar una que todavía está a punto de asignarse.
create or replace function public.limpiar_fotos_sin_dueno()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rutas text[];
begin
  select coalesce(array_agg(o.name), '{}') into v_rutas
  from (
    select name from storage.objects
    where bucket_id = 'users'
      and name ~ '^users/[^/]+$'
      and name not like '%.emptyFolderPlaceholder'
      and created_at < now() - interval '1 hour'
    order by created_at
    limit 500
  ) o
  where not exists (
    select 1 from public.users u
    where public.ruta_de_foto(u.photo_url) = o.name
  );

  perform public.pedir_borrado_de_fotos(v_rutas);
  return coalesce(cardinality(v_rutas), 0);
end;
$$;

revoke all on function public.limpiar_fotos_sin_dueno() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job
where jobname = 'limpiar-fotos-sin-dueno';
select cron.schedule(
  'limpiar-fotos-sin-dueno',
  '43 4 * * *',
  $$select public.limpiar_fotos_sin_dueno()$$
);
