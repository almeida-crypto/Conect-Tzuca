-- Restaurante: mesas, comandas y cocina se sincronizan como lo demás (synced_at).
-- orders y order_items ya están en Realtime (0001) para avisar al instante a la cocina.

do $$
declare t text;
begin
  foreach t in array array['restaurant_tables', 'orders', 'order_items'] loop
    execute format('alter table public.%I add column synced_at timestamptz not null default now()', t);
    execute format('create trigger trg_synced_at before insert or update on public.%I
                    for each row execute function public.set_synced_at()', t);
    execute format('create index on public.%I (business_id, synced_at)', t);
  end loop;
end $$;

-- Orden de las mesas en la pantalla.
alter table public.restaurant_tables add column position int not null default 0;

-- Nombre de una comanda para llevar ("Juan", "Didi 4521") y cuándo se cobró o canceló.
alter table public.orders add column label text;
alter table public.orders add column closed_at timestamptz;

-- Cuándo el mesero entregó el platillo.
alter table public.order_items add column served_at timestamptz;
