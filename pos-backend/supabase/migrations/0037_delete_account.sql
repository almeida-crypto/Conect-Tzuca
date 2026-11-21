-- 0037: borrar la cuenta desde la app (lo pide Google Play).
--
-- delete_my_account(): borra los negocios donde la persona es dueña (con todo su historial: ventas, fiados,
-- productos...; las fotos las borra antes la app, porque Storage no deja borrarlas desde SQL) y su usuario.
-- Lo que registró en negocios ajenos (como cajero o mesero) se queda, sin autor: las llaves a auth.users pasan a
-- ON DELETE SET NULL, y el candado "solo los jefes cambian esto" deja pasar ese único cambio.

do $$
declare r record;
begin
  for r in
    select c.conrelid::regclass as tbl, a.attname as col, c.conname
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and c.connamespace = 'public'::regnamespace
      and c.confdeltype = 'a' and not a.attnotnull
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format('alter table %s add constraint %I foreign key (%I) references auth.users(id) on delete set null',
                   r.tbl, r.conname, r.col);
  end loop;
end $$;

create or replace function public.only_bosses_change()
returns trigger language plpgsql set search_path = ''
as $function$
begin
  if coalesce((select auth.role()), '') = 'service_role' then
    return new;
  end if;
  if public.has_role(old.business_id, array['owner', 'admin']::public.member_role[]) then
    return new;
  end if;
  -- Al borrarse una cuenta, lo que registró se queda sin autor: ese es el único cambio permitido.
  if (to_jsonb(new) - 'synced_at' - 'updated_at' - 'created_by') is not distinct from
     (to_jsonb(old) - 'synced_at' - 'updated_at' - 'created_by')
     and to_jsonb(new) ->> 'created_by' is null then
    return new;
  end if;
  if (to_jsonb(new) - 'synced_at' - 'updated_at') is distinct from (to_jsonb(old) - 'synced_at' - 'updated_at') then
    raise exception 'Solo el dueño o un administrador puede cambiar o cancelar esto'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not_allowed';
  end if;
  -- Sus negocios, completos (todo lo del negocio se borra en cascada).
  delete from public.businesses b
   where exists (select 1 from public.business_members m
                  where m.business_id = b.id and m.user_id = uid and m.role = 'owner');
  -- Su usuario: sus lugares en otros equipos se borran y lo que registró ahí queda sin autor.
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
