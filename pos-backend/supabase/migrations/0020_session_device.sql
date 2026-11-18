-- 0020: cada celular lleva su propio turno de caja. device_id es la clave del celular (la de los folios,
-- "K7"); los turnos de antes quedan sin ella. Sirve para que un celular no tome la caja abierta de otro y
-- para el corte de todas las cajas del dueño.

alter table public.cash_sessions add column device_id text check (char_length(device_id) <= 16);
