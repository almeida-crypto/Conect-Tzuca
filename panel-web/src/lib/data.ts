// Lectura de Supabase. Todo pasa por RLS: cada quien ve solo su negocio.
import type { SupabaseClient } from "@supabase/supabase-js";
import { previousPeriod } from "./report";
import type { PayMethod, Period, ReportData, Sale } from "./types";

export type Business = { id: string; name: string; role: string };

const cents = (v: unknown) => Math.round(Number(v ?? 0) * 100);

const methodIn: Record<string, PayMethod> = { cash: "efectivo", card: "tarjeta", transfer: "transferencia" };

/** El negocio de la cuenta (la app maneja uno por cuenta). */
export async function myBusiness(client: SupabaseClient): Promise<Business | null> {
  const { data: user } = await client.auth.getUser();
  if (!user.user) return null;
  const { data, error } = await client
    .from("business_members")
    .select("business_id, role, businesses(name)")
    .eq("user_id", user.user.id)
    .is("deleted_at", null)
    .order("created_at")
    .limit(1);
  if (error) throw error;
  // El negocio llega como objeto (relación muchos a uno), aunque los tipos genéricos digan arreglo.
  const row = data?.[0] as unknown as
    | { business_id: string; role: string; businesses: { name: string } | { name: string }[] | null }
    | undefined;
  if (!row) return null;
  const b = Array.isArray(row.businesses) ? row.businesses[0] : row.businesses;
  return { id: row.business_id, name: b?.name ?? "Mi negocio", role: row.role };
}

/** Supabase entrega de 1000 en 1000: pide páginas hasta que no haya más. */
async function fetchAll<T>(page: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>) {
  const out: T[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await page(offset, offset + 999);
    if (error) throw error;
    out.push(...(data ?? []));
    if (!data || data.length < 1000) return out;
  }
}

type SaleRow = { id: string; created_at: string; total: number; status: string; pay_method: string | null };
type ItemRow = {
  sale_id: string;
  name_snapshot: string;
  qty: number;
  unit_price: number;
  unit_cost: number | null;
  sales: { created_at: string };
};

const toSale = (r: SaleRow): Sale => ({
  id: r.id,
  at: new Date(r.created_at),
  totalCents: cents(r.total),
  method: r.status === "credit" ? "fiado" : (methodIn[r.pay_method ?? ""] ?? "efectivo"),
});

export async function loadReport(client: SupabaseClient, businessId: string, period: Period): Promise<ReportData> {
  const prev = previousPeriod(period);
  const iso = (d: Date) => d.toISOString();

  const [sales, items, payments, cuts, debtors, products] = await Promise.all([
    fetchAll<SaleRow>((a, b) =>
      client
        .from("sales")
        .select("id, created_at, total, status, pay_method")
        .eq("business_id", businessId)
        .neq("status", "cancelled")
        .gte("created_at", iso(prev.from))
        .lt("created_at", iso(period.to))
        .order("created_at")
        .range(a, b),
    ),
    fetchAll<ItemRow>((a, b) =>
      client
        .from("sale_items")
        .select("sale_id, name_snapshot, qty, unit_price, unit_cost, sales!inner(created_at, status)")
        .eq("business_id", businessId)
        .gte("sales.created_at", iso(period.from))
        .lt("sales.created_at", iso(period.to))
        .neq("sales.status", "cancelled")
        .range(a, b) as unknown as PromiseLike<{ data: ItemRow[] | null; error: unknown }>,
    ),
    fetchAll<{ amount: number }>((a, b) =>
      client
        .from("credit_entries")
        .select("amount")
        .eq("business_id", businessId)
        .eq("type", "payment")
        .gte("created_at", iso(period.from))
        .lt("created_at", iso(period.to))
        .range(a, b),
    ),
    client
      .from("cash_sessions")
      .select("id, opened_at, closed_at, expected_amount, counted_amount")
      .eq("business_id", businessId)
      .not("closed_at", "is", null)
      .gte("closed_at", iso(period.from))
      .lt("closed_at", iso(period.to))
      .order("closed_at", { ascending: false })
      .limit(60),
    client
      .from("customer_balances")
      .select("name, balance")
      .eq("business_id", businessId)
      .gt("balance", 0)
      .order("balance", { ascending: false })
      .limit(15),
    client
      .from("products")
      .select("name, stock_qty, min_stock")
      .eq("business_id", businessId)
      .eq("track_stock", true)
      .eq("is_active", true)
      .is("deleted_at", null)
      .not("min_stock", "is", null),
  ]);
  for (const r of [cuts, debtors, products]) if (r.error) throw r.error;

  const all = sales.map(toSale);
  return {
    sales: all.filter((s) => s.at >= period.from),
    previousSales: all.filter((s) => s.at < period.from),
    items: items.map((r) => {
      const total = cents(r.unit_price) * Number(r.qty);
      const unitCost = cents(r.unit_cost);
      return {
        saleId: r.sale_id,
        at: new Date(r.sales.created_at),
        name: r.name_snapshot,
        qty: Number(r.qty),
        totalCents: Math.round(total),
        // Costo en cero = no se capturó: no cuenta para la ganancia.
        costCents: unitCost > 0 ? Math.round(unitCost * Number(r.qty)) : null,
      };
    }),
    creditPaymentsCents: payments.reduce((a, p) => a + cents(p.amount), 0),
    cuts: (cuts.data ?? []).map((c) => ({
      id: c.id,
      openedAt: new Date(c.opened_at),
      closedAt: new Date(c.closed_at),
      expectedCents: cents(c.expected_amount),
      countedCents: cents(c.counted_amount),
    })),
    debtors: (debtors.data ?? []).map((d) => ({ name: d.name, balanceCents: cents(d.balance) })),
    lowStock: (products.data ?? [])
      .filter((p) => Number(p.stock_qty) <= Number(p.min_stock))
      .map((p) => ({ name: p.name, stock: Number(p.stock_qty), minStock: Number(p.min_stock) }))
      .sort((a, b) => a.stock - b.stock),
  };
}
