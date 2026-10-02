-- Rechazar cuentas con correos temporales (desechables), con una lista que se
-- mantiene sola.
--
-- La lista NO se escribe a mano: la base de datos descarga cada día la lista
-- pública de la comunidad (github.com/disposable-email-domains, ~9,000
-- dominios, se actualiza seguido) y llena `dominios_correo_temporal`.
-- - `es_correo_temporal(correo)`: la app la consulta al registrarse.
-- - El trigger en auth.users lo hace valer aunque la cuenta se cree desde
--   fuera de la app.
-- Gmail, Outlook, .edu.mx o el correo del negocio pasan igual; las cuentas
-- de Google nunca son temporales.

create extension if not exists http with schema extensions;
create extension if not exists pg_cron;

create table if not exists public.dominios_correo_temporal (
  dominio text primary key
);

-- Solo la usan las funciones de abajo: nadie la lee ni la escribe directo.
alter table public.dominios_correo_temporal enable row level security;
revoke all on public.dominios_correo_temporal from anon, authenticated;

-- Si el dominio del correo (o uno del que es subdominio, como
-- x.mailinator.com) es temporal.
create or replace function public.es_correo_temporal(correo text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_dominio text := lower(trim(split_part(coalesce(correo, ''), '@', 2)));
begin
  while v_dominio like '%.%' loop
    if exists (select 1 from public.dominios_correo_temporal d
               where d.dominio = v_dominio) then
      return true;
    end if;
    v_dominio := substr(v_dominio, strpos(v_dominio, '.') + 1);
  end loop;
  return false;
end;
$$;

-- La app pregunta antes de crear la cuenta (todavía sin sesión).
revoke all on function public.es_correo_temporal(text) from public;
grant execute on function public.es_correo_temporal(text) to anon, authenticated;

-- Descarga la lista y la deja al día (agrega los nuevos y quita los que la
-- comunidad retiró). Si la descarga falla o viene rara, no toca nada: se
-- queda la lista del día anterior.
create or replace function public.actualizar_dominios_temporales()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  respuesta extensions.http_response;
  total integer;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS', '30000');
  respuesta := extensions.http_get(
    'https://raw.githubusercontent.com/disposable-email-domains/'
    'disposable-email-domains/main/disposable_email_blocklist.conf');

  if respuesta.status <> 200 then
    raise warning 'Lista de correos temporales: respuesta %', respuesta.status;
    return 0;
  end if;

  create temp table if not exists _nuevos (dominio text primary key)
    on commit drop;
  truncate _nuevos;
  insert into _nuevos (dominio)
  select distinct lower(trim(linea))
  from regexp_split_to_table(respuesta.content, E'\n') as linea
  where trim(linea) <> '' and trim(linea) not like '#%'
  on conflict do nothing;

  select count(*) into total from _nuevos;
  -- Una lista casi vacía es una descarga rota, no que ya no haya temporales.
  if total < 1000 then
    raise warning 'Lista de correos temporales sospechosa: % dominios', total;
    return 0;
  end if;

  insert into public.dominios_correo_temporal (dominio)
  select dominio from _nuevos
  on conflict (dominio) do nothing;

  delete from public.dominios_correo_temporal d
  where not exists (select 1 from _nuevos n where n.dominio = d.dominio);

  return total;
end;
$$;

revoke all on function public.actualizar_dominios_temporales() from public, anon, authenticated;

-- Rechaza la cuenta si el correo es temporal.
create or replace function public.rechazar_correo_temporal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.es_correo_temporal(new.email) then
    raise exception 'correo_temporal: no se aceptan correos temporales'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.rechazar_correo_temporal() from public, anon, authenticated;

drop trigger if exists rechazar_correo_temporal on auth.users;
create trigger rechazar_correo_temporal
  before insert or update of email on auth.users
  for each row execute function public.rechazar_correo_temporal();

-- Cada día a las 4:17 (UTC) se actualiza sola.
select cron.unschedule(jobid) from cron.job
where jobname = 'actualizar-dominios-temporales';
select cron.schedule(
  'actualizar-dominios-temporales',
  '17 4 * * *',
  $$select public.actualizar_dominios_temporales()$$
);

-- Y la primera vez, ya.
select public.actualizar_dominios_temporales();
