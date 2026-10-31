-- =====================================================================
-- 0004 · Pacas y lotes, apartados y pedidos por tanda en la sincronización
-- =====================================================================

-- Turno de caja en que entró el dinero, para que salga en el corte.
alter table public.lot_sales
  add column cash_session_id uuid references public.cash_sessions(id);
alter table public.layaway_payments
  add column cash_session_id uuid references public.cash_sessions(id);

-- synced_at: hora del servidor en cada alta o cambio (ver 0003).
do $$
declare t text;
begin
  foreach t in array array['lots','lot_sales','layaways','layaway_payments','batches','batch_orders'] loop
    execute format('alter table public.%I add column synced_at timestamptz not null default now()', t);
    execute format('create trigger trg_synced_at before insert or update on public.%I
                    for each row execute function public.set_synced_at()', t);
    execute format('create index on public.%I (business_id, synced_at)', t);
  end loop;
end $$;
