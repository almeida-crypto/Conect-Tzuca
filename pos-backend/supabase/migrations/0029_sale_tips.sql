-- Propinas en el restaurante: lo que el cliente deja de más al pagar la cuenta.
-- No es venta (no entra en total, ni en la ganancia): va aparte para el equipo. El dinero sí entra al cajón,
-- por eso los pagos (pay_method o sale_payments) suman total + tip.
alter table public.sales
  add column tip numeric(12, 2) not null default 0 check (tip >= 0 and tip <= 100000);

comment on column public.sales.tip is 'Propina para el equipo (aparte del total de la venta). Los pagos suman total + tip.';
