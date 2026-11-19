// Las mesas en este momento: cuáles están ocupadas, cuánto llevan y si la cocina ya tiene algo listo.
import type { SupabaseClient } from "@supabase/supabase-js";

export type FloorOrder = {
  totalCents: number;
  since: Date;
  /** Platillos en la cuenta (sin los cancelados). */
  dishes: number;
  /** Platillos listos en cocina, esperando que el mesero los lleve. */
  ready: number;
  /** Algo se está preparando o espera en cocina. */
  cooking: boolean;
};

export type FloorTable = { id: string; name: string; zone: string | null; order: FloorOrder | null };

export type Takeout = { id: string; label: string; order: FloorOrder };

export type Floor = { tables: FloorTable[]; takeouts: Takeout[]; at: Date };

const cents = (v: unknown) => Math.round(Number(v ?? 0) * 100);

type TableRow = { id: string; name: string; zone: string | null; position: number | null };
type OrderRow = { id: string; table_id: string | null; label: string | null; created_at: string };
type ItemRow = {
  order_id: string;
  qty: number;
  unit_price: number;
  paid_qty: number | null;
  status: string;
  extras: { price?: number }[] | null;
};

/** Junta los platillos de una cuenta: lo que falta por cobrar y cómo va la cocina. */
export function summarize(items: ItemRow[], since: Date): FloorOrder {
  let total = 0;
  let dishes = 0;
  let ready = 0;
  let cooking = false;
  for (const i of items) {
    if (i.status === "cancelled") continue;
    const unit = cents(i.unit_price) + (i.extras ?? []).reduce((a, e) => a + cents(e.price), 0);
    total += unit * Math.max(0, Number(i.qty) - Number(i.paid_qty ?? 0));
    dishes += Number(i.qty);
    if (i.status === "ready") ready += 1;
    if (i.status === "pending" || i.status === "preparing") cooking = true;
  }
  return { totalCents: Math.round(total), since, dishes, ready, cooking };
}

/** Mesas y cuentas abiertas del negocio. null si no tiene mesas (no es restaurante). */
export async function loadFloor(client: SupabaseClient, businessId: string): Promise<Floor | null> {
  const [tables, orders] = await Promise.all([
    client
      .from("restaurant_tables")
      .select("id, name, zone, position")
      .eq("business_id", businessId)
      .eq("is_active", true)
      .is("deleted_at", null)
      .order("position"),
    client
      .from("orders")
      .select("id, table_id, label, created_at")
      .eq("business_id", businessId)
      .eq("status", "open")
      .order("created_at"),
  ]);
  if (tables.error) throw tables.error;
  if (orders.error) throw orders.error;
  const tableRows = (tables.data ?? []) as TableRow[];
  const orderRows = (orders.data ?? []) as OrderRow[];
  if (tableRows.length === 0 && orderRows.length === 0) return null;

  const ids = orderRows.map((o) => o.id);
  const items: ItemRow[] = [];
  // De 100 en 100 cuentas, para no hacer una dirección demasiado larga.
  for (let i = 0; i < ids.length; i += 100) {
    const { data, error } = await client
      .from("order_items")
      .select("order_id, qty, unit_price, paid_qty, status, extras")
      .eq("business_id", businessId)
      .in("order_id", ids.slice(i, i + 100));
    if (error) throw error;
    items.push(...((data ?? []) as ItemRow[]));
  }
  const byOrder = new Map<string, ItemRow[]>();
  for (const it of items) byOrder.set(it.order_id, [...(byOrder.get(it.order_id) ?? []), it]);
  const summaryOf = (o: OrderRow) => summarize(byOrder.get(o.id) ?? [], new Date(o.created_at));

  // Una mesa con dos cuentas abiertas (no debería pasar) muestra la más nueva, como la app.
  const openByTable = new Map<string, OrderRow>();
  for (const o of orderRows) if (o.table_id) openByTable.set(o.table_id, o);

  return {
    at: new Date(),
    tables: tableRows.map((t) => {
      const o = openByTable.get(t.id);
      return { id: t.id, name: t.name, zone: t.zone, order: o ? summaryOf(o) : null };
    }),
    takeouts: orderRows
      .filter((o) => !o.table_id)
      .map((o) => ({ id: o.id, label: o.label ? `Para llevar · ${o.label}` : "Para llevar", order: summaryOf(o) })),
  };
}

/** Restaurante de ejemplo para ver el mapa sin cuenta. */
export function demoFloor(now = new Date()): Floor {
  const ago = (min: number) => new Date(now.getTime() - min * 60_000);
  const busy = (totalCents: number, min: number, dishes: number, ready = 0, cooking = false): FloorOrder => ({
    totalCents,
    since: ago(min),
    dishes,
    ready,
    cooking,
  });
  return {
    at: now,
    tables: [
      { id: "1", name: "Mesa 1", zone: null, order: busy(24500, 42, 7, 0, false) },
      { id: "2", name: "Mesa 2", zone: null, order: null },
      { id: "3", name: "Mesa 3", zone: null, order: busy(9000, 12, 4, 2, true) },
      { id: "4", name: "Mesa 4", zone: null, order: null },
      { id: "5", name: "Mesa 5", zone: null, order: busy(15500, 5, 5, 0, true) },
      { id: "6", name: "Mesa 6", zone: null, order: null },
      { id: "7", name: "Mesa 1", zone: "Terraza", order: busy(36000, 75, 11) },
      { id: "8", name: "Mesa 2", zone: "Terraza", order: null },
      { id: "9", name: "Mesa 3", zone: "Terraza", order: null },
    ],
    takeouts: [{ id: "t1", label: "Para llevar · Juan", order: busy(7000, 8, 3, 0, true) }],
  };
}

/** "recién", "12 min", "1 h 5 min". */
export function elapsed(since: Date, now = new Date()): string {
  const m = Math.floor((now.getTime() - since.getTime()) / 60_000);
  if (m < 1) return "recién";
  if (m < 60) return `${m} min`;
  if (m < 24 * 60) return m % 60 === 0 ? `${Math.floor(m / 60)} h` : `${Math.floor(m / 60)} h ${m % 60} min`;
  const d = Math.floor(m / (24 * 60));
  return d === 1 ? "1 día" : `${d} días`;
}
