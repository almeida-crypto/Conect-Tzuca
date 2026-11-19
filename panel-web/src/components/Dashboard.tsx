"use client";

import Image from "next/image";
import { useEffect, useMemo, useState } from "react";
import { ColumnChart } from "@/components/ColumnChart";
import { FloorMap } from "@/components/FloorMap";
import { BarList, Card, CardTitle, StatTile } from "@/components/Pieces";
import { type Business, loadReport } from "@/lib/data";
import { demoReport } from "@/lib/demo";
import { demoFloor, type Floor, loadFloor } from "@/lib/floor";
import {
  bestBucket,
  byClerk,
  byDay,
  byHour,
  byMethod,
  byRegister,
  change,
  dayValue,
  formatQty,
  money,
  percent,
  type PeriodKey,
  periodFor,
  productsCsv,
  profit,
  profitByProduct,
  rangePeriod,
  salesCsv,
  topProducts,
  totals,
} from "@/lib/report";
import { supabase } from "@/lib/supabase";
import type { ReportData } from "@/lib/types";

const periods: { key: PeriodKey; label: string }[] = [
  { key: "hoy", label: "Hoy" },
  { key: "7d", label: "7 días" },
  { key: "30d", label: "30 días" },
  { key: "mes", label: "Este mes" },
  { key: "mesPasado", label: "Mes pasado" },
  { key: "rango", label: "Elegir fechas" },
];

/** Baja un archivo hecho en el navegador (no pasa por ningún servidor). */
function download(name: string, text: string) {
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}

const dateTime = new Intl.DateTimeFormat("es-MX", {
  weekday: "short",
  day: "numeric",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
});

/** Reportes de ventas. Con [business] lee Supabase; sin él, muestra la tiendita de ejemplo. */
export function Dashboard({ business, onExit }: { business: Business | null; onExit: () => void }) {
  const [key, setKey] = useState<PeriodKey>("7d");
  const [data, setData] = useState<ReportData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [range, setRange] = useState(() => {
    const week = periodFor("7d");
    return { from: dayValue(week.from), to: dayValue(new Date(week.to.getTime() - 86_400_000)) };
  });
  const [floor, setFloor] = useState<Floor | null>(null);
  const period = useMemo(
    () => (key === "rango" ? (rangePeriod(range.from, range.to) ?? periodFor("7d")) : periodFor(key)),
    [key, range],
  );

  useEffect(() => {
    let alive = true;
    const load = business ? loadReport(supabase, business.id, period) : Promise.resolve(demoReport(period));
    load
      .then((d) => alive && setData(d))
      .catch(() => alive && setError("No se pudieron leer las ventas. Revisa tu internet y vuelve a intentar."))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [business, period]);

  // Las mesas en este momento: se vuelven a leer cada 20 segundos (no dependen del periodo).
  useEffect(() => {
    let alive = true;
    const read = () =>
      (business ? loadFloor(supabase, business.id) : Promise.resolve(demoFloor()))
        .then((f) => alive && setFloor(f))
        .catch(() => {}); // Si falla una vez, se queda el mapa anterior y se intenta en la siguiente vuelta.
    read();
    const timer = setInterval(read, 20_000);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, [business]);

  // Al cambiar de periodo se avisa que está cargando; el efecto trae los datos.
  function choose(k: PeriodKey) {
    if (k === key) return;
    setKey(k);
    setLoading(true);
    setError(null);
  }

  function changeRange(next: { from: string; to: string }) {
    if (!rangePeriod(next.from, next.to)) return;
    setRange(next);
    setLoading(true);
    setError(null);
  }

  const fileDay = dayValue(period.from);

  const name = business?.name ?? "Abarrotes Doña Mary";

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-linea bg-fondo/90 backdrop-blur print:static print:border-0">
        <div className="mx-auto flex max-w-[1180px] items-center gap-3 px-4 py-3 sm:px-6">
          <Image src="/gavilan.png" alt="" width={58} height={33} />
          <div className="min-w-0 flex-1">
            <div className="truncate text-[18px] font-extrabold tracking-tight">{name}</div>
            <div className="truncate text-[12.5px] font-semibold text-tinta-suave">
              {business ? "Reportes de ventas" : "Datos de ejemplo"}
              <span className="hidden sm:inline">{business ? "" : " · así se ve con tu negocio"}</span>
            </div>
          </div>
          <button
            onClick={onExit}
            className="shrink-0 rounded-full print:hidden border-[1.5px] border-linea bg-superficie px-4 py-2 text-[14px] font-bold hover:bg-hundido"
          >
            <span className="sm:hidden">Salir</span>
            <span className="hidden sm:inline">{business ? "Cerrar sesión" : "Salir del ejemplo"}</span>
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-[1180px] px-4 pt-5 pb-16 sm:px-6">
        <div className="mb-5 flex flex-wrap items-center gap-2 print:hidden">
          {periods.map((p) => (
            <button
              key={p.key}
              onClick={() => choose(p.key)}
              aria-pressed={key === p.key}
              className={`rounded-full border-[1.5px] px-4 py-2 text-[14px] font-bold transition active:scale-95 ${
                key === p.key ? "border-tinta bg-tinta text-white" : "border-linea bg-superficie hover:bg-hundido"
              }`}
            >
              {p.label}
            </button>
          ))}
          {loading && <span className="ml-2 text-[13px] font-semibold text-tinta-tenue">Cargando…</span>}
        </div>

        {key === "rango" && (
          <div className="mb-5 flex flex-wrap items-end gap-3 print:hidden">
            {(["from", "to"] as const).map((f) => (
              <label key={f} className="text-[13px] font-semibold text-tinta-suave">
                {f === "from" ? "Desde" : "Hasta"}
                <input
                  type="date"
                  value={range[f]}
                  max={dayValue(new Date())}
                  onChange={(e) => changeRange({ ...range, [f]: e.target.value })}
                  className="mt-1 block rounded-xl border-[1.5px] border-linea bg-superficie px-3 py-2 text-[15px] font-bold text-tinta"
                />
              </label>
            ))}
          </div>
        )}

        <p className="mb-4 hidden text-[15px] font-bold print:block">{period.label}</p>

        {data && (
          <div className="mb-5 flex flex-wrap gap-2 print:hidden">
            <button
              onClick={() => download(`ventas-${fileDay}.csv`, salesCsv(data))}
              className="rounded-full border-[1.5px] border-linea bg-superficie px-4 py-2 text-[14px] font-bold hover:bg-hundido"
            >
              Descargar ventas (Excel)
            </button>
            <button
              onClick={() => download(`productos-${fileDay}.csv`, productsCsv(data))}
              className="rounded-full border-[1.5px] border-linea bg-superficie px-4 py-2 text-[14px] font-bold hover:bg-hundido"
            >
              Descargar productos (Excel)
            </button>
            <button
              onClick={() => window.print()}
              className="rounded-full border-[1.5px] border-linea bg-superficie px-4 py-2 text-[14px] font-bold hover:bg-hundido"
            >
              Imprimir o guardar PDF
            </button>
          </div>
        )}

        {error && (
          <p className="mb-5 rounded-2xl bg-rojo-suave px-4 py-3 text-[14px] font-semibold text-rojo">{error}</p>
        )}

        {floor && floor.tables.length + floor.takeouts.length > 0 && (
          <div className="mb-5 print:hidden">
            <FloorMap floor={floor} />
          </div>
        )}

        {data && <Report data={data} period={period} key={`${period.label}-${data.sales.length}`} />}
      </main>
    </div>
  );
}

function Report({ data, period }: { data: ReportData; period: ReturnType<typeof periodFor> }) {
  const now = totals(data.sales);
  const before = totals(data.previousSales);
  const gain = profit(data);
  const fiado = data.sales.filter((s) => s.method === "fiado").reduce((a, s) => a + s.totalCents, 0);
  const onStreet = data.debtors.reduce((a, d) => a + d.balanceCents, 0);
  const days = period.to.getTime() - period.from.getTime() <= 86_400_000 ? null : byDay(data.sales, period);
  const hours = byHour(data.sales);
  const bestHour = bestBucket(hours);
  const bestDay = days ? bestBucket(days) : null;
  const vs = "vs periodo anterior";
  const clerks = byClerk(data.sales);
  const registers = byRegister(data.sales);
  const returned = data.returns.reduce((a, r) => a + r.amountCents, 0);

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Vendido" value={money(now.totalCents)} delta={change(now.totalCents, before.totalCents)} note={vs} />
        <StatTile label="Ventas" value={String(now.count)} delta={change(now.count, before.count)} note={vs} delay={50} />
        <StatTile
          label="Ticket promedio"
          value={money(now.averageCents)}
          delta={change(now.averageCents, before.averageCents)}
          note={vs}
          delay={100}
        />
        <StatTile
          label="Ganancia"
          value={money(gain.profitCents)}
          tone="cenote"
          note={gain.coverage < 0.95 ? `de lo que tiene costo (${Math.round(gain.coverage * 100)}%)` : "precio menos costo"}
          delay={150}
        />
      </div>

      {days ? (
        <ColumnChart
          buckets={days}
          title="Ventas por día"
          subtitle={bestDay ? `El mejor día: ${bestDay.detail}, con ${money(bestDay.cents)}` : period.label}
        />
      ) : null}

      <div className="grid gap-5 lg:grid-cols-2">
        <ColumnChart
          buckets={hours}
          title="¿A qué hora se vende más?"
          subtitle={bestHour ? `La mejor hora: ${bestHour.detail.toLowerCase()}` : undefined}
        />
        <Card>
          <CardTitle title="Formas de pago" subtitle="Cuánto entró por cada una" />
          <BarList rows={byMethod(data.sales)} empty="Sin ventas en este periodo." />
          <div className="mt-5 grid grid-cols-2 gap-3 border-t border-linea pt-4 text-[14px]">
            <div>
              <div className="text-tinta-suave">Se fió</div>
              <div className="tabular text-[18px] font-extrabold">{money(fiado)}</div>
            </div>
            <div>
              <div className="text-tinta-suave">Se cobró de fiados</div>
              <div className="tabular text-[18px] font-extrabold text-cenote">{money(data.creditPaymentsCents)}</div>
            </div>
          </div>
        </Card>
      </div>

      <Card>
        <CardTitle title="Lo más vendido" subtitle="Por dinero que dejó en el periodo" />
        <BarList rows={topProducts(data)} empty="Todavía no hay productos vendidos en este periodo." />
      </Card>

      <ProfitTable data={data} />

      {(clerks.length > 1 || registers.length > 1) && (
        <div className="grid gap-5 lg:grid-cols-2">
          {clerks.length > 1 && (
            <Card>
              <CardTitle title="Por quien atendió" subtitle="Con PIN en el mostrador" />
              <BarList rows={clerks} empty="Sin ventas en este periodo." />
            </Card>
          )}
          {registers.length > 1 && (
            <Card>
              <CardTitle title="Por caja" subtitle="Cada celular o computadora que cobra" />
              <BarList rows={registers} empty="Sin ventas en este periodo." />
            </Card>
          )}
        </div>
      )}

      {data.returns.length > 0 && (
        <Card>
          <CardTitle
            title="Devoluciones de otros días"
            subtitle={`${money(returned)} devueltos · la venta sigue contando en su día`}
          />
          <ul className="tabular divide-y divide-linea text-[14px]">
            {data.returns.map((r, i) => (
              <li key={i} className="flex items-baseline justify-between gap-3 py-2">
                <span className="min-w-0 truncate">
                  <span className="font-semibold first-letter:uppercase">{dateTime.format(r.at)}</span>
                  <span className="ml-2 text-tinta-suave">
                    Venta {r.folio}: {r.summary}
                  </span>
                </span>
                <span className="shrink-0 text-right">
                  <b className="text-rojo">−{money(r.amountCents)}</b>
                  {r.cashCents < r.amountCents && (
                    <span className="ml-2 text-[12.5px] text-tinta-tenue">
                      {r.cashCents > 0 ? `${money(r.cashCents)} en efectivo` : "sin efectivo"}
                    </span>
                  )}
                </span>
              </li>
            ))}
          </ul>
        </Card>
      )}

      <div className="grid gap-5 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardTitle title="Cortes de caja" subtitle={`${data.cuts.length} en el periodo`} />
          {data.cuts.length === 0 ? (
            <p className="py-6 text-center text-[14px] text-tinta-suave">No se cerró la caja en este periodo.</p>
          ) : (
            <div className="max-h-[340px] overflow-auto">
              <table className="tabular w-full text-[14px]">
                <thead className="sticky top-0 bg-superficie text-left text-[12px] text-tinta-tenue">
                  <tr>
                    <th className="py-1.5 font-semibold">Cierre</th>
                    <th className="py-1.5 text-right font-semibold">Debía haber</th>
                    <th className="py-1.5 text-right font-semibold">Se contó</th>
                    <th className="py-1.5 text-right font-semibold">Diferencia</th>
                  </tr>
                </thead>
                <tbody>
                  {data.cuts.map((c) => {
                    const diff = c.countedCents - c.expectedCents;
                    return (
                      <tr key={c.id} className="border-t border-linea">
                        <td className="py-2 first-letter:uppercase">{dateTime.format(c.closedAt)}</td>
                        <td className="py-2 text-right">{money(c.expectedCents)}</td>
                        <td className="py-2 text-right">{money(c.countedCents)}</td>
                        <td className="py-2 text-right">
                          <span
                            className={`rounded-full px-2 py-0.5 text-[13px] font-bold ${
                              diff === 0
                                ? "bg-cenote-suave text-cenote"
                                : diff > 0
                                  ? "bg-izamal-suave text-[#8a5a00]"
                                  : "bg-rojo-suave text-rojo"
                            }`}
                          >
                            {diff === 0 ? "Cuadró" : `${diff > 0 ? "+" : "−"}${money(Math.abs(diff))}`}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <div className="space-y-5">
          <Card>
            <CardTitle title="Quién debe" subtitle={`En la calle: ${money(onStreet)}`} />
            {data.debtors.length === 0 ? (
              <p className="py-3 text-[14px] text-tinta-suave">Nadie te debe.</p>
            ) : (
              <ul className="tabular divide-y divide-linea text-[14px]">
                {data.debtors.map((d) => (
                  <li key={d.name} className="flex justify-between py-2">
                    <span className="truncate font-semibold">{d.name}</span>
                    <span className="font-bold text-rojo">{money(d.balanceCents)}</span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card>
            <CardTitle title="Por acabarse" subtitle="Productos en su mínimo o abajo" />
            {data.lowStock.length === 0 ? (
              <p className="py-3 text-[14px] text-tinta-suave">Todo con existencia suficiente.</p>
            ) : (
              <ul className="tabular divide-y divide-linea text-[14px]">
                {data.lowStock.map((p) => (
                  <li key={p.name} className="flex justify-between py-2">
                    <span className="truncate font-semibold">{p.name}</span>
                    <span className="text-tinta-suave">
                      quedan <b className="text-rojo">{p.stock}</b> (mín. {p.minStock})
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

/** Ganancia de cada producto: lo vendido, su costo y lo que dejó. */
function ProfitTable({ data }: { data: ReportData }) {
  const [all, setAll] = useState(false);
  const rows = profitByProduct(data);
  const shown = all ? rows : rows.slice(0, 12);
  const missing = rows.filter((r) => r.profitCents === null).length;
  return (
    <Card>
      <CardTitle
        title="Ganancia por producto"
        subtitle={
          missing > 0
            ? `${missing} ${missing === 1 ? "producto no tiene" : "productos no tienen"} costo: captúralo en la app para ver su ganancia`
            : "Lo vendido menos lo que te costó"
        }
      />
      {rows.length === 0 ? (
        <p className="py-6 text-center text-[14px] text-tinta-suave">Todavía no hay productos vendidos en este periodo.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="tabular w-full min-w-[520px] text-[14px]">
            <thead className="text-left text-[12px] text-tinta-tenue">
              <tr>
                <th className="py-1.5 font-semibold">Producto</th>
                <th className="py-1.5 text-right font-semibold">Cantidad</th>
                <th className="py-1.5 text-right font-semibold">Vendido</th>
                <th className="py-1.5 text-right font-semibold">Costo</th>
                <th className="py-1.5 text-right font-semibold">Ganancia</th>
                <th className="py-1.5 text-right font-semibold">Margen</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((r) => (
                <tr key={r.name} className="border-t border-linea">
                  <td className="max-w-[220px] truncate py-2 font-semibold">{r.name}</td>
                  <td className="py-2 text-right">{formatQty(r.qty)}</td>
                  <td className="py-2 text-right">{money(r.salesCents)}</td>
                  <td className="py-2 text-right text-tinta-suave">{r.costCents === null ? "—" : money(r.costCents)}</td>
                  <td className={`py-2 text-right font-bold ${(r.profitCents ?? 0) < 0 ? "text-rojo" : "text-cenote"}`}>
                    {r.profitCents === null ? <span className="font-normal text-tinta-tenue">sin costo</span> : money(r.profitCents)}
                  </td>
                  <td className="py-2 text-right text-tinta-suave">{r.margin === null ? "—" : percent(r.margin)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {rows.length > 12 && (
        <button
          onClick={() => setAll(!all)}
          className="mt-3 text-[14px] font-bold text-marca hover:underline print:hidden"
        >
          {all ? "Ver menos" : `Ver los ${rows.length} productos`}
        </button>
      )}
    </Card>
  );
}
