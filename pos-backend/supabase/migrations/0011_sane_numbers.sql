-- 0011: nada de números irreales. La app ya no deja escribirlos (core/limits.dart); la base los rechaza
-- también, por si llegan de una versión vieja o de otro lado. Son amplios a propósito.

alter table public.products
  add constraint products_price_range check (price >= 0 and price <= 999999.99),
  add constraint products_cost_range check (cost is null or (cost >= 0 and cost <= 999999.99)),
  add constraint products_min_stock_range check (min_stock is null or (min_stock >= 0 and min_stock <= 99999)),
  -- La existencia puede quedar negativa (se vendió sin capturar la compra), pero no infinita.
  add constraint products_stock_range check (stock_qty between -999999 and 999999),
  add constraint products_name_length check (char_length(name) between 1 and 120);

alter table public.cash_movements
  add constraint cash_movements_amount_range check (amount > 0 and amount <= 999999.99);

alter table public.cash_sessions
  add constraint cash_sessions_opening_range check (opening_amount >= 0 and opening_amount <= 999999.99);
