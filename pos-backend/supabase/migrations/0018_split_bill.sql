-- 0018: dividir la cuenta del restaurante.
-- * Por platillos: order_items.paid_qty dice cuántas piezas ya se cobraron. Solo quien cobra (dueño,
--   administrador o cajero) la sube, y nunca baja: una copia vieja en el celular de un mesero no la regresa.
-- * Partes iguales y pagos mixtos: cada pago va en sale_payments (la tabla ya existía); la venta queda con
--   pay_method vacío.

alter table public.order_items add column paid_qty numeric(12, 3) not null default 0
  check (paid_qty >= 0 and paid_qty <= 99999);

create or replace function public.order_item_paid_qty()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'service_role' then
    return new;
  end if;
  if public.has_role(new.business_id, array['owner', 'admin', 'cashier']::public.member_role[]) then
    if tg_op = 'UPDATE' then
      new.paid_qty := greatest(old.paid_qty, new.paid_qty);
    end if;
    return new;
  end if;
  -- Meseros y cocina no cobran.
  new.paid_qty := case when tg_op = 'UPDATE' then old.paid_qty else 0 end;
  return new;
end;
$$;

revoke execute on function public.order_item_paid_qty() from public, anon, authenticated;

create trigger order_item_paid_qty before insert or update on public.order_items
  for each row execute function public.order_item_paid_qty();

-- La cocina tampoco toca lo pagado (además de lo que ya no tocaba).
create or replace function public.kitchen_status_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.has_role(new.business_id, '{kitchen}') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if not exists (select 1 from public.order_items i where i.id = new.id) then
      raise exception 'La cocina no puede agregar platillos' using errcode = '42501';
    end if;
    return new;
  end if;

  new.business_id   := old.business_id;
  new.order_id      := old.order_id;
  new.product_id    := old.product_id;
  new.name_snapshot := old.name_snapshot;
  new.qty           := old.qty;
  new.unit_price    := old.unit_price;
  new.extras        := old.extras;
  new.notes         := old.notes;
  new.sent_at       := old.sent_at;
  new.created_at    := old.created_at;
  new.paid_qty      := old.paid_qty;
  return new;
end;
$$;
