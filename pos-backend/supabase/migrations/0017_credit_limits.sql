-- 0017: tope de fiado. Cada cliente puede tener el suyo (customers.credit_limit) y el negocio uno general
-- (businesses.credit_limit). null = sin tope. Solo el dueño o un administrador los ponen o cambian: un
-- cajero puede dar de alta clientes, pero sin tope.
-- Fiar de más se controla en la app (con permiso o con el PIN del dueño); la base no lo frena porque las
-- ventas pueden llegar tarde desde un celular sin internet.

-- customers.credit_limit ya venía de 0001_init (sin usar); aquí solo se le pone rango.
alter table public.customers add constraint customers_credit_limit_range
  check (credit_limit is null or (credit_limit >= 0 and credit_limit <= 999999.99));
alter table public.businesses add column credit_limit numeric(12, 2)
  check (credit_limit is null or (credit_limit >= 0 and credit_limit <= 999999.99));

create or replace function public.credit_limit_bosses_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'service_role' then
    return new;
  end if;
  if public.has_role(new.business_id, array['owner', 'admin']::public.member_role[]) then
    return new;
  end if;
  if (tg_op = 'INSERT' and new.credit_limit is not null)
     or (tg_op = 'UPDATE' and new.credit_limit is distinct from old.credit_limit) then
    raise exception 'Solo el dueño o un administrador pone el tope de fiado'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.credit_limit_bosses_only() from public, anon, authenticated;

create trigger credit_limit_bosses_only before insert or update on public.customers
  for each row execute function public.credit_limit_bosses_only();
