// Tiendita de ejemplo para ver el panel sin cuenta. Siempre da los mismos números para las mismas fechas.
import { previousPeriod } from "./report";
import type { CashCut, PayMethod, Period, ReportData, Sale, SaleItem } from "./types";

const catalog: [name: string, price: number, cost: number, weight: number][] = [
  ["Coca 600 ml", 1800, 1300, 10],
  ["Tortilla, kg", 2400, 1800, 9],
  ["Sabritas", 1700, 1200, 7],
  ["Huevo, kg", 4200, 3400, 6],
  ["Agua 1 L", 1200, 700, 6],
  ["Pan dulce", 800, 500, 6],
  ["Leche 1 L", 2800, 2300, 5],
  ["Cerveza", 2500, 1800, 5],
  ["Frijol, kg", 3800, 2900, 3],
  ["Arroz, kg", 3200, 2400, 3],
  ["Café soluble", 3500, 2600, 2],
  ["Jabón Zote", 1500, 1100, 2],
  ["Aceite 1 L", 4500, 3600, 2],
  ["Papel higiénico", 2200, 1600, 2],
];

/** Generador pseudoaleatorio con semilla: los mismos números en cada recarga. */
function seeded(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Más clientes temprano (desayuno, tortillas) y al salir del trabajo.
const hourWeights = [0, 0, 0, 0, 0, 0, 1, 4, 7, 6, 4, 3, 4, 5, 4, 3, 3, 4, 7, 8, 7, 5, 2, 0];

function pick<T>(rand: () => number, items: T[], weight: (t: T) => number): T {
  const total = items.reduce((a, t) => a + weight(t), 0);
  let r = rand() * total;
  for (const t of items) {
    r -= weight(t);
    if (r <= 0) return t;
  }
  return items[items.length - 1];
}

function salesOfDay(day: Date, now: Date) {
  const rand = seeded(day.getFullYear() * 1000 + day.getMonth() * 40 + day.getDate());
  const weekend = day.getDay() === 0 || day.getDay() === 6;
  const count = Math.round((weekend ? 34 : 26) + rand() * 12);
  const sales: Sale[] = [];
  const items: SaleItem[] = [];
  for (let n = 0; n < count; n++) {
    const hour = pick(rand, [...hourWeights.keys()], (h) => hourWeights[h]);
    const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, Math.floor(rand() * 60));
    if (at > now) continue;
    const id = `${at.getTime()}-${n}`;
    let total = 0;
    const lines = 1 + Math.floor(rand() * 3);
    for (let l = 0; l < lines; l++) {
      const [name, price, cost] = pick(rand, catalog, (c) => c[3]);
      const qty = 1 + Math.floor(rand() * 2);
      total += price * qty;
      items.push({ saleId: id, at, name, qty, totalCents: price * qty, costCents: cost * qty });
    }
    const r = rand();
    const method: PayMethod = r < 0.7 ? "efectivo" : r < 0.82 ? "tarjeta" : r < 0.9 ? "transferencia" : "fiado";
    sales.push({ id, at, totalCents: total, method });
  }
  return { sales, items, rand };
}

export function demoReport(period: Period, now = new Date()): ReportData {
  const prev = previousPeriod(period);
  const sales: Sale[] = [];
  const previousSales: Sale[] = [];
  const items: SaleItem[] = [];
  const cuts: CashCut[] = [];
  let creditPaymentsCents = 0;
  for (
    let d = new Date(prev.from.getFullYear(), prev.from.getMonth(), prev.from.getDate());
    d < period.to && d <= now;
    d.setDate(d.getDate() + 1)
  ) {
    const day = salesOfDay(new Date(d), now);
    if (d < period.from) {
      previousSales.push(...day.sales);
      continue;
    }
    sales.push(...day.sales);
    items.push(...day.items);
    creditPaymentsCents += Math.round(day.rand() * 4) * 5000;
    const closedAt = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 22, 5);
    if (closedAt < now) {
      const expected = 50000 + day.sales.filter((s) => s.method === "efectivo").reduce((a, s) => a + s.totalCents, 0);
      const diff = [0, 0, 0, -2000, 1000, 0, -500][Math.floor(day.rand() * 7)];
      cuts.push({
        id: closedAt.toISOString(),
        openedAt: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 7, 30),
        closedAt,
        expectedCents: expected,
        countedCents: expected + diff,
      });
    }
  }
  return {
    sales,
    previousSales,
    items,
    creditPaymentsCents,
    cuts: cuts.reverse(),
    debtors: [
      { name: "Don Beto", balanceCents: 58000 },
      { name: "Doña Lupe", balanceCents: 32000 },
      { name: "Pedro el albañil", balanceCents: 20000 },
      { name: "Sra. Chelo", balanceCents: 9000 },
    ],
    lowStock: [
      { name: "Jabón Zote", stock: 2, minStock: 5 },
      { name: "Sabritas", stock: 3, minStock: 10 },
    ],
  };
}
