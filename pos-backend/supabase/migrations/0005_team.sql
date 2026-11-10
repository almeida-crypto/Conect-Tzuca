-- Equipo: invitaciones con código para que cajeros y administradores se unan al negocio.
--
-- El dueño (o un administrador) crea un código de 8 letras. Quien lo recibe entra con su
-- cuenta y lo escribe en la app; accept_invite lo agrega a business_members con su rol.
-- Los miembros ya no se insertan ni se cambian directo: todo pasa por estas funciones.

create table public.business_invites (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id) on delete cascade,
  code         text not null unique,
  role         public.member_role not null check (role <> 'owner'),
  display_name text,
  created_by   uuid references auth.users(id),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '7 days',
  used_by      uuid references auth.users(id),
  used_at      timestamptz,
  revoked_at   timestamptz
);
create index on public.business_invites (business_id);

alter table public.business_invites enable row level security;
create policy invites_select on public.business_invites for select to authenticated
  using (public.has_role(business_id, array['owner','admin']::public.member_role[]));

-- Sin INSERT/UPDATE directos en miembros: así nadie se sube de rol desde la app.
drop policy members_insert on public.business_members;
drop policy members_update on public.business_members;

-- Código de 8 caracteres sin letras que se confunden (sin I, O, 0 ni 1).
create or replace function public.new_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea := extensions.gen_random_bytes(8);
  code text := '';
begin
  for i in 0..7 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return code;
end;
$$;
revoke execute on function public.new_invite_code() from public, anon, authenticated;

create or replace function public.create_invite(p_business uuid, p_role public.member_role, p_name text default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.has_role(p_business, array['owner','admin']::public.member_role[]) then
    raise exception 'not_allowed';
  end if;
  if p_role = 'owner' then
    raise exception 'not_allowed';
  end if;
  -- Solo el dueño invita administradores.
  if p_role = 'admin' and not public.has_role(p_business, array['owner']::public.member_role[]) then
    raise exception 'not_allowed';
  end if;
  loop
    v_code := public.new_invite_code();
    exit when not exists (select 1 from public.business_invites where code = v_code);
  end loop;
  insert into public.business_invites (business_id, code, role, display_name, created_by)
    values (p_business, v_code, p_role, nullif(trim(p_name), ''), (select auth.uid()));
  return v_code;
end;
$$;

create or replace function public.accept_invite(p_code text, p_name text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_invite public.business_invites;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  select * into v_invite from public.business_invites
    where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'))
      and used_at is null and revoked_at is null and expires_at > now()
    for update;
  if not found then
    raise exception 'invalid_invite';
  end if;
  -- La app maneja un negocio por cuenta.
  if exists (select 1 from public.business_members where user_id = v_uid and deleted_at is null) then
    raise exception 'already_member';
  end if;
  insert into public.business_members (business_id, user_id, role, display_name)
    values (v_invite.business_id, v_uid, v_invite.role, coalesce(nullif(trim(p_name), ''), v_invite.display_name))
    on conflict (business_id, user_id) do update
      set role = excluded.role, display_name = excluded.display_name, deleted_at = null, updated_at = now();
  update public.business_invites set used_by = v_uid, used_at = now() where id = v_invite.id;
  return v_invite.business_id;
end;
$$;

create or replace function public.revoke_invite(p_invite uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_business uuid;
begin
  select business_id into v_business from public.business_invites where id = p_invite;
  if v_business is null or not public.has_role(v_business, array['owner','admin']::public.member_role[]) then
    raise exception 'not_allowed';
  end if;
  update public.business_invites set revoked_at = now() where id = p_invite and used_at is null;
end;
$$;

create or replace function public.remove_member(p_member uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_member public.business_members;
begin
  select * into v_member from public.business_members where id = p_member and deleted_at is null;
  if not found or v_member.role = 'owner'
     or not public.has_role(v_member.business_id, array['owner','admin']::public.member_role[])
     -- Solo el dueño quita administradores.
     or (v_member.role = 'admin' and not public.has_role(v_member.business_id, array['owner']::public.member_role[])) then
    raise exception 'not_allowed';
  end if;
  update public.business_members set deleted_at = now(), updated_at = now() where id = p_member;
end;
$$;

revoke execute on function public.create_invite(uuid, public.member_role, text) from public, anon;
revoke execute on function public.accept_invite(text, text) from public, anon;
revoke execute on function public.revoke_invite(uuid) from public, anon;
revoke execute on function public.remove_member(uuid) from public, anon;
grant execute on function public.create_invite(uuid, public.member_role, text) to authenticated;
grant execute on function public.accept_invite(text, text) to authenticated;
grant execute on function public.revoke_invite(uuid) to authenticated;
grant execute on function public.remove_member(uuid) to authenticated;
