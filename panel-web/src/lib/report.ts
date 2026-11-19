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
      // Una venta pagada en partes reparte su total entre sus métodos.
      const cents = sum(
        sales.flatMap((s) =>
          s.parts ? s.parts.filter((p) => p.method === m).map((p) => p.totalCents) : s.method === m ? [s.totalCents] : [],
        ),
      );
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

/** Ganancia de cada producto: lo vendido menos su costo. Los que no tienen costo van al final, sin ganancia. */
export type ProductProfit = {
  name: string;
  qty: number;
  salesCents: number;
  costCents: number | null;
  profitCents: number | null;
  /** Margen sobre lo vendido (0.25 = 25%). */
  margin: number | null;
};

export function profitByProduct(data: ReportData): ProductProfit[] {
  const map = new Map<string, { qty: number; sales: number; cost: number; missing: boolean }>();
  for (const i of data.items) {
    const p = map.get(i.name) ?? { qty: 0, sales: 0, cost: 0, missing: false };
    p.qty += i.qty;
    p.sales += i.totalCents;
    if (i.costCents === null) p.missing = true;
    else p.cost += i.costCents;
    map.set(i.name, p);
  }
  return [...map.entries()]
    .map(([name, p]) => {
      // Si algún renglón no tiene costo, la ganancia de ese producto no se puede saber.
      const profitCents = p.missing ? null : p.sales - p.cost;
      return {
        name,
        qty: p.qty,
        salesCents: p.sales,
        costCents: p.missing ? null : p.cost,
        profitCents,
        margin: profitCents === null || p.sales === 0 ? null : profitCents / p.sales,
      };
    })
    .sort((a, b) => (b.profitCents ?? -Infinity) - (a.profitCents ?? -Infinity) || b.salesCents - a.salesCents);
}

/** Ventas agrupadas por quien atendió o por caja. */
export function byGroup(sales: Sale[], keyOf: (s: Sale) => string): Share[] {
  const map = new Map<string, { cents: number; count: number }>();
  for (const s of sales) {
    const k = keyOf(s);
    const g = map.get(k) ?? { cents: 0, count: 0 };
    g.cents += s.totalCents;
    g.count += 1;
    map.set(k, g);
  }
  const total = sum([...map.values()].map((g) => g.cents));
  return [...map.entries()]
    .map(([k, g]) => ({
      key: k,
      label: k,
      cents: g.cents,
      share: total ? g.cents / total : 0,
      extra: `${g.count} ${g.count === 1 ? "venta" : "ventas"}`,
    }))
    .sort((a, b) => b.cents - a.cents);
}

export const byClerk = (sales: Sale[]) => byGroup(sales, (s) => s.clerk || "Sin PIN");
export const byRegister = (sales: Sale[]) => byGroup(sales, (s) => s.register ?? "Sin caja");

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

export type PeriodKey = "hoy" | "7d" | "30d" | "mes" | "mesPasado" | "rango";

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
    case "rango":
      return { from: new Date(today.getTime() - 6 * 86_400_000), to: tomorrow, label: "Últimos 7 días" };
  }
}

/** "2026-11-18" (de un campo de fecha) a medianoche local; null si no es una fecha. */
export function parseDay(value: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Fecha local como la pide un campo de fecha: "2026-11-18". */
export const dayValue = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

const rangeDay = new Intl.DateTimeFormat("es-MX", { day: "numeric", month: "short", year: "numeric" });

/** Del día [from] al día [to], los dos incluidos. Si vienen al revés, se voltean. null si falta alguno. */
export function rangePeriod(from: string, to: string): Period | null {
  let a = parseDay(from);
  let b = parseDay(to);
  if (!a || !b) return null;
  if (b < a) [a, b] = [b, a];
  const end = new Date(b.getFullYear(), b.getMonth(), b.getDate() + 1);
  const label = a.getTime() === b.getTime() ? rangeDay.format(a) : `${rangeDay.format(a)} al ${rangeDay.format(b)}`;
  return { from: a, to: end, label };
}

// ---------- Descargas (Excel abre los CSV) ----------

const csvCell = (v: string | number) => {
  const s = String(v);
  // Una celda que empieza con =, +, - o @ Excel la tomaría como fórmula: se le antepone un apóstrofo
  // (menos a los números negativos, como una ganancia de -5.00).
  const safe = /^[=+\-@]/.test(s) && !/^-?\d+(\.\d+)?$/.test(s) ? `'${s}` : s;
  return /[",\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
};

/** CSV con BOM para que Excel respete los acentos. */
export function toCsv(header: string[], rows: (string | number)[][]): string {
  return "\uFEFF" + [header, ...rows].map((r) => r.map(csvCell).join(",")).join("\r\n");
}

const pesos = (cents: number) => (cents / 100).toFixed(2);
const two = (n: number) => String(n).padStart(2, "0");
/** "2026-11-18 14:05": Excel lo reconoce como fecha y hora. */
const csvDate = (d: Date) => `${dayValue(d)} ${two(d.getHours())}:${two(d.getMinutes())}`;

export function salesCsv(data: ReportData): string {
  return toCsv(
    ["Fecha", "Folio", "Total", "Forma de pago", "Atendió", "Caja"],
    [...data.sales].sort((a, b) => a.at.getTime() - b.at.getTime()).map((s) => [
      csvDate(s.at),
      s.folio ?? "",
      pesos(s.totalCents),
      s.parts ? s.parts.map((p) => `${methodLabel[p.method]} ${pesos(p.totalCents)}`).join(" + ") : methodLabel[s.method],
      s.clerk ?? "",
      s.register ?? "",
    ]),
  );
}

export function productsCsv(data: ReportData): string {
  return toCsv(
    ["Producto", "Cantidad", "Vendido", "Costo", "Ganancia", "Margen %"],
    profitByProduct(data).map((p) => [
      p.name,
      formatQty(p.qty),
      pesos(p.salesCents),
      p.costCents === null ? "" : pesos(p.costCents),
      p.profitCents === null ? "" : pesos(p.profitCents),
      p.margin === null ? "" : Math.round(p.margin * 100),
    ]),
  );
}

/** El periodo anterior del mismo largo, para comparar. */
export function previousPeriod(p: Period): Period {
  const len = p.to.getTime() - p.from.getTime();
  return { from: new Date(p.from.getTime() - len), to: new Date(p.from), label: "Periodo anterior" };
}
