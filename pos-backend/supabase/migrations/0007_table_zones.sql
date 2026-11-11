-- Zonas de mesas: "Planta baja", "Segunda planta", "Terraza". Vacío = sin zona.
alter table public.restaurant_tables add column zone text;
