-- 0010: cancelar ventas.
-- Una venta cancelada queda con sales.status = 'cancelled' y el motivo en sales.notes.
-- Lo vendido regresa al inventario con un movimiento 'return'.
-- Si la venta fue fiada, se le quita la deuda al cliente con un renglón 'reversal' en credit_entries
-- (no es un abono: no entró dinero a la caja).

alter type public.ledger_type add value if not exists 'reversal';
