-- 0013: una cuenta puede estar en varios negocios, con un puesto distinto en cada uno
-- (el mesero de "Tacos El Güero" que además es dueño de "Perfumes Ana").
-- Cada negocio sigue separado: RLS ya revisa la pertenencia y el rol negocio por negocio.

create or replace function public.accept_invite(p_code text, p_name text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
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
  -- Ya no se rechaza a quien pertenece a otro negocio. Si ya era de este mismo, se actualiza su puesto.
  insert into public.business_members (business_id, user_id, role, display_name)
    values (v_invite.business_id, v_uid, v_invite.role, coalesce(nullif(trim(p_name), ''), v_invite.display_name))
    on conflict (business_id, user_id) do update
      set role = excluded.role, display_name = excluded.display_name, deleted_at = null, updated_at = now();
  update public.business_invites set used_by = v_uid, used_at = now() where id = v_invite.id;
  return v_invite.business_id;
end;
$$;
