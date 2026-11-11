// Cálculos de los reportes. Funciones puras: no saben de Supabase ni de React.
import type { PayMethod, Period, ReportData, Sale } from "./types";

export const methodLabel: Record<PayMethod, string> = {
  efectivo: "Efectivo",
  tarjeta: "Tarjeta",
  transferencia: "Transferencia",
  fiado: "Fiado",
};

const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0);

export function totals(sales: Sale[]) {
  const totalCents = sum(sales.map((s) => s.totalCents));
  return { totalCents, count: sales.length, averageCents: sales.length ? Math.round(totalCents / sales.length) : 0 };
}

/** Cambio contra el periodo anterior, en porcentaje; null si antes no hubo ventas. */
export function change(now: number, before: number): number | null {
  if (before <= 0) return null;
  return ((now - before) / before) * 100;
}

/** Ganancia de lo vendido con costo capturado, y qué parte de las ventas lo tiene. */
export function profit(data: ReportData) {
  const withCost = data.items.filter((i) => i.costCents !== null);
  const profitCents = sum(withCost.map((i) => i.totalCents - (i.costCents ?? 0)));
  const coveredCents = sum(withCost.map((i) => i.totalCents));
  const itemsCents = sum(data.items.map((i) => i.totalCents));
  return { profitCents, coverage: itemsCents ? coveredCents / itemsCents : 0 };
}

const dayKey = (d: Date) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;

export type Bucket = { key: string; label: string; detail: string; cents: number; count: number };

const shortDay = new Intl.DateTimeFormat("es-MX", { day: "numeric", month: "short" });
const longDay = new Intl.DateTimeFormat("es-MX", { weekday: "long", day: "numeric", month: "long" });

/** Ventas por día del periodo; los días sin ventas aparecen en cero. */
export function byDay(sales: Sale[], period: Period): Bucket[] {
  const buckets = new Map<string, Bucket>();
  const d = new Date(period.from.getFullYear(), period.from.getMonth(), period.from.getDate());
  const end = period.to.getTime();
  while (d.getTime() < end) {
    buckets.set(dayKey(d), {
      key: dayKey(d),
      label: shortDay.format(d).replace(".", ""),
      detail: longDay.format(d),
      cents: 0,
      count: 0,
    });
    d.setDate(d.getDate() + 1);
  }
  for (const s of sales) {
    const b = buckets.get(dayKey(s.at));
    if (b) {
      b.cents += s.totalCents;
      b.count += 1;
    }
  }
  return [...buckets.values()];
}

/** Ventas por hora del día (de la primera a la última hora con ventas, mínimo de 7 a 21). */
export function byHour(sales: Sale[]): Bucket[] {
  const cents = new Array<number>(24).fill(0);
  const count = new Array<number>(24).fill(0);
  for (const s of sales) {
    cents[s.at.getHours()] += s.totalCents;
    count[s.at.getHours()] += 1;
  }
  const used = cents.map((c, h) => (c > 0 ? h : -1)).filter((h) => h >= 0);
  const first = Math.min(7, ...used);
  const last = Math.max(21, ...used);
  const out: Bucket[] = [];
  for (let h = first; h <= last; h++) {
    out.push({
      key: String(h),
      label: `${h}`,
      detail: `De ${h}:00 a ${h + 1}:00`,
      cents: cents[h],
      count: count[h],
    });
  }
  return out;
}

export type Share = { key: string; label: string; cents: number; share: number; extra?: string };

export function byMethod(sales: Sale[]): Share[] {
  const total = sum(sales.map((s) => s.totalCents));
  return (Object.keys(methodLabel) as PayMethod[])
    .map((m) => {
      const cents = sum(sales.filter((s) => s.method === m).map((s) => s.totalCents));
      return { key: m, label: methodLabel[m], cents, share: total ? cents / total : 0 };
    })
    .filter((x) => x.cents > 0)
    .sort((a, b) => b.cents - a.cents);
}

/** Lo más vendido por dinero; junta los renglones del mismo nombre. */
export function topProducts(data: ReportData, limit = 10): Share[] {
  const map = new Map<string, { cents: number; qty: number }>();
  for (const i of data.items) {
    const p = map.get(i.name) ?? { cents: 0, qty: 0 };
    p.cents += i.totalCents;
    p.qty += i.qty;
    map.set(i.name, p);
  }
  const total = sum([...map.values()].map((p) => p.cents));
  return [...map.entries()]
    .map(([name, p]) => ({
      key: name,
      label: name,
      cents: p.cents,
      share: total ? p.cents / total : 0,
      extra: `${formatQty(p.qty)} ${unitOf(name, p.qty)}`,
    }))
    .sort((a, b) => b.cents - a.cents)
    .slice(0, limit);
}

/** "kg" para lo que se vende a granel (el nombre lo dice, como "Huevo, kg"); si no, piezas. */
function unitOf(name: string, qty: number) {
  if (/\bkg\b/i.test(name)) return "kg";
  if (/\b(l|litro|litros)\b/i.test(name) && !Number.isInteger(qty)) return "L";
  return qty === 1 ? "pieza" : "piezas";
}

export function bestBucket(buckets: Bucket[]): Bucket | null {
  return buckets.reduce<Bucket | null>((best, b) => (b.cents > (best?.cents ?? 0) ? b : best), null);
}

// ---------- Formatos ----------

const mxn = new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" });
const mxnShort = new Intl.NumberFormat("es-MX", {
  style: "currency",
  currency: "MXN",
  notation: "compact",
  maximumFractionDigits: 1,
});

export const money = (cents: number) => mxn.format(cents / 100);

/** $1.2 mil en ejes; montos chicos completos. */
export const moneyAxis = (cents: number) => (cents >= 1_000_000 ? mxnShort.format(cents / 100) : mxn.format(Math.round(cents / 100)).replace(".00", ""));

export const formatQty = (q: number) => (Number.isInteger(q) ? String(q) : q.toFixed(2));

export const percent = (x: number) => `${Math.round(x * 100)}%`;

// ---------- Periodos ----------

export type PeriodKey = "hoy" | "7d" | "30d" | "mes" | "mesPasado";

export function periodFor(key: PeriodKey, now = new Date()): Period {
  const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const today = startOfDay(now);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  switch (key) {
    case "hoy":
      return { from: today, to: tomorrow, label: "Hoy" };
    case "7d": {
      const from = new Date(today);
      from.setDate(today.getDate() - 6);
      return { from, to: tomorrow, label: "Últimos 7 días" };
    }
    case "30d": {
      const from = new Date(today);
      from.setDate(today.getDate() - 29);
      return { from, to: tomorrow, label: "Últimos 30 días" };
    }
    case "mes":
      return { from: new Date(today.getFullYear(), today.getMonth(), 1), to: tomorrow, label: "Este mes" };
    case "mesPasado":
      return {
        from: new Date(today.getFullYear(), today.getMonth() - 1, 1),
        to: new Date(today.getFullYear(), today.getMonth(), 1),
        label: "Mes pasado",
      };
  }
}

/** El periodo anterior del mismo largo, para comparar. */
export function previousPeriod(p: Period): Period {
  const len = p.to.getTime() - p.from.getTime();
  return { from: new Date(p.from.getTime() - len), to: new Date(p.from), label: "Periodo anterior" };
}
