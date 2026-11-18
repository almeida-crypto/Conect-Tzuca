-- 0021: nombre de cada caja y cancelar ventas de días pasados.
-- * cash_sessions.register_name: cómo se llama la caja de ese celular ("Mostrador", "Barra").
-- * sales.cancelled_session_id: turno donde se canceló una venta de un corte ya cerrado. El corte de su día
--   no cambia; el dinero que se regresó se anota como gasto en ese turno.

alter table public.cash_sessions add column register_name text check (char_length(register_name) <= 30);
alter table public.sales add column cancelled_session_id uuid;
