-- 0008: el costo de compra es información del dueño.
-- Meseros y cocina siguen viendo los productos con su precio de venta, pero sin el costo.
-- Postgres no puede esconder una columna según quién pregunta, así que:
--   * la tabla products solo la leen dueño, administrador y cajero (que necesita el costo para registrar ventas);
--   * todos bajan los productos con pull_products(), que deja el costo vacío a meseros y cocina;
--   * el costo de lo vendido (sale_items.unit_cost) solo lo leen dueño, administrador y cajero.

drop policy if exists products_select on public.products;
create policy products_select on public.products
  for select to authenticated
  using (public.has_role(business_id, '{owner,admin,cashier}'));

drop policy if exists sale_items_select on public.sale_items;
create policy sale_items_select on public.sale_items
  for select to authenticated
  using (public.has_role(business_id, '{owner,admin,cashier}'));

-- Cambios de productos desde [p_since], de [p_limit] en [p_limit], ordenados como los demás pulls.
create or replace function public.pull_products(
  p_business_id uuid,
  p_since timestamptz,
  p_offset integer,
  p_limit integer
)
returns setof jsonb
language sql stable security definer set search_path = ''
as $$
  select case
           when public.has_role(p.business_id, '{owner,admin,cashier}') then to_jsonb(p)
           else (to_jsonb(p) - 'cost') || jsonb_build_object('cost', null)
         end
  from public.products p
  where p.business_id = p_business_id
    and public.is_member(p_business_id)
    and p.synced_at > p_since
  order by p.synced_at
  offset greatest(p_offset, 0)
  limit least(greatest(p_limit, 0), 1000);
$$;

revoke execute on function public.pull_products(uuid, timestamptz, integer, integer) from public, anon;
grant execute on function public.pull_products(uuid, timestamptz, integer, integer) to authenticated;
