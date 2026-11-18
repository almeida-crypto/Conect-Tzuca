-- 0019: formas de pago que acepta el negocio. null = las tres (negocios de antes). El efectivo siempre va.
-- Solo el dueño o un administrador cambian la fila del negocio (política de 0001).

alter table public.businesses add column pay_methods text[]
  check (pay_methods is null or (pay_methods <@ array['cash', 'card', 'transfer'] and 'cash' = any (pay_methods)));
