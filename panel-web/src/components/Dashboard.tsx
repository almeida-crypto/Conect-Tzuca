"use client";

import Image from "next/image";
import { useEffect, useMemo, useState } from "react";
import { ColumnChart } from "@/components/ColumnChart";
import { BarList, Card, CardTitle, StatTile } from "@/components/Pieces";
import { type Business, loadReport } from "@/lib/data";
import { demoReport } from "@/lib/demo";
import {
  bestBucket,
  byDay,
  byHour,
  byMethod,
  change,
  money,
  type PeriodKey,
  periodFor,
  profit,
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
];

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
  const period = useMemo(() => periodFor(key), [key]);

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

  // Al cambiar de periodo se avisa que está cargando; el efecto trae los datos.
  function choose(k: PeriodKey) {
    if (k === key) return;
    setKey(k);
    setLoading(true);
    setError(null);
  }

  const name = business?.name ?? "Abarrotes Doña Mary";

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-linea bg-fondo/90 backdrop-blur">
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
            className="shrink-0 rounded-full border-[1.5px] border-linea bg-superficie px-4 py-2 text-[14px] font-bold hover:bg-hundido"
          >
            <span className="sm:hidden">Salir</span>
            <span className="hidden sm:inline">{business ? "Cerrar sesión" : "Salir del ejemplo"}</span>
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-[1180px] px-4 pt-5 pb-16 sm:px-6">
        <div className="mb-5 flex flex-wrap items-center gap-2">
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

        {error && (
          <p className="mb-5 rounded-2xl bg-rojo-suave px-4 py-3 text-[14px] font-semibold text-rojo">{error}</p>
        )}

        {data && <Report data={data} period={period} key={`${key}-${data.sales.length}`} />}
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
