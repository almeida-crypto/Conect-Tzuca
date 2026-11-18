-- 0022: sale_payments no tenía synced_at (la hora del servidor con la que cada celular baja lo que cambió).
-- La app 1.7.0 empezó a bajar esta tabla para los pagos en partes y el respaldo fallaba con
-- "column sale_payments.synced_at does not exist". Se pone igual que en las demás tablas (0003_sync).

alter table public.sale_payments add column synced_at timestamptz not null default now();

create trigger trg_synced_at before insert or update on public.sale_payments
  for each row execute function public.set_synced_at();

create index on public.sale_payments (business_id, synced_at);
