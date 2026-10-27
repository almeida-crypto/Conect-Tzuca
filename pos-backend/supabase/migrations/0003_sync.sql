-- =====================================================================
-- 0003 · Sincronización con la app Gavilán (sin servicios externos)
--
-- La app guarda todo en el teléfono y sube los cambios cuando hay señal.
-- Para bajar lo que cambió en otros dispositivos usa synced_at: la hora del
-- SERVIDOR a la que llegó o se modificó cada fila (el reloj del teléfono
-- puede estar mal y una venta hecha sin internet llega horas después).
-- =====================================================================

-- ---------- Columnas que usa la app ----------
alter table public.sales
  add column pay_method public.payment_method,       -- forma de pago de una venta pagada
  add column received_amount numeric(12,2);          -- con cuánto pagó (para el cambio)

alter table public.sale_items
  add column position int not null default 0;        -- orden de los renglones en el ticket

alter table public.credit_entries
  add column method public.payment_method,           -- cómo se pagó un abono
  add column cash_session_id uuid references public.cash_sessions(id);  -- turno en que entró el abono

-- Quién hizo cada movimiento: por defecto, el usuario con sesión.
alter table public.sales               alter column created_by set default auth.uid();
alter table public.credit_entries      alter column created_by set default auth.uid();
alter table public.cash_movements      alter column created_by set default auth.uid();
alter table public.inventory_movements alter column created_by set default auth.uid();
alter table public.layaway_payments    alter column created_by set default auth.uid();
alter table public.cash_sessions       alter column opened_by  set default auth.uid();

-- ---------- synced_at: hora del servidor en cada alta o cambio ----------
create or replace function public.set_synced_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.synced_at = now(); return new; end; $$;

alter table public.businesses add column synced_at timestamptz not null default now();
create trigger trg_synced_at before insert or update on public.businesses
  for each row execute function public.set_synced_at();

do $$
declare t text;
begin
  foreach t in array array[
    'products','customers','sales','sale_items','credit_entries','cash_sessions','cash_movements'
  ] loop
    execute format('alter table public.%I add column synced_at timestamptz not null default now()', t);
    execute format('create trigger trg_synced_at before insert or update on public.%I
                    for each row execute function public.set_synced_at()', t);
    execute format('create index on public.%I (business_id, synced_at)', t);
  end loop;
end $$;

-- ---------- Alta del negocio con el id que ya tiene el teléfono ----------
drop function public.create_business(text, text);

create function public.create_business(p_name text, p_type text default null, p_id uuid default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  insert into public.businesses (id, name, business_type) values (v_id, p_name, p_type);
  insert into public.business_members (business_id, user_id, role)
    values (v_id, (select auth.uid()), 'owner');
  return v_id;
end;
$$;
revoke execute on function public.create_business(text, text, uuid) from public, anon;
grant  execute on function public.create_business(text, text, uuid) to authenticated;

-- ---------- Candado: el plan solo lo cambia el sistema de cobro ----------
create or replace function public.protect_business_plan()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.plan is distinct from old.plan
     and coalesce((select auth.role()), '') <> 'service_role'
     and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'El plan solo se cambia desde el sistema de cobro';
  end if;
  return new;
end;
$$;
create trigger trg_protect_plan before update on public.businesses
  for each row execute function public.protect_business_plan();
