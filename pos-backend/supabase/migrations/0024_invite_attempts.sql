-- 0024: tope de intentos con códigos de invitación.
-- Una cuenta que se equivoca 10 veces en 15 minutos espera antes de volver a intentar: así nadie prueba
-- códigos al azar hasta atinarle a uno.
-- Con un código equivocado, accept_invite ya no lanza error: anota el intento y regresa null (si lanzara
-- error, la base también desharía la anotación). La app 1.9 muestra "Ese código no existe…" al recibir null.

create table public.invite_attempts (
  user_id uuid not null,
  at      timestamptz not null default now()
);
create index on public.invite_attempts (user_id, at);
alter table public.invite_attempts enable row level security; -- sin políticas: nadie la lee ni escribe por la API
revoke all on public.invite_attempts from anon, authenticated;

create or replace function public.accept_invite(p_code text, p_name text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_invite public.business_invites;
  v_recent int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.invite_attempts where user_id = v_uid and at < now() - interval '1 day';
  select count(*) into v_recent from public.invite_attempts
    where user_id = v_uid and at > now() - interval '15 minutes';
  if v_recent >= 10 then
    raise exception 'too_many_attempts';
  end if;

  select * into v_invite from public.business_invites
    where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'))
      and used_at is null and revoked_at is null and expires_at > now()
    for update;
  if not found then
    insert into public.invite_attempts (user_id) values (v_uid);
    return null;
  end if;

  insert into public.business_members (business_id, user_id, role, display_name)
    values (v_invite.business_id, v_uid, v_invite.role, coalesce(nullif(trim(p_name), ''), v_invite.display_name))
    on conflict (business_id, user_id) do update
      set role = excluded.role, display_name = excluded.display_name, deleted_at = null, updated_at = now();
  update public.business_invites set used_by = v_uid, used_at = now() where id = v_invite.id;
  delete from public.invite_attempts where user_id = v_uid;
  return v_invite.business_id;
end;
$$;
