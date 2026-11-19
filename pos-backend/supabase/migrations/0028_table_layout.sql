-- Plano de mesas acomodado como el local: dónde está cada mesa en el dibujo, su forma y cuántas sillas.
-- Todo opcional: una mesa sin posición se acomoda sola en su zona (como antes). Las mismas reglas de siempre:
-- solo el dueño o un administrador cambian mesas (políticas de restaurant_tables).

alter table public.restaurant_tables
  add column pos_x integer check (pos_x between 0 and 4000),
  add column pos_y integer check (pos_y between 0 and 4000),
  add column shape text check (shape in ('square', 'round')),
  add column seats smallint check (seats between 1 and 20);

comment on column public.restaurant_tables.pos_x is 'Posición en el plano (puntos de diseño, la esquina de arriba a la izquierda de su zona = 0). null = se acomoda sola.';
comment on column public.restaurant_tables.pos_y is 'Posición en el plano. null = se acomoda sola.';
comment on column public.restaurant_tables.shape is 'square o round. null = square.';
comment on column public.restaurant_tables.seats is 'Sillas que se dibujan. null = 4.';
