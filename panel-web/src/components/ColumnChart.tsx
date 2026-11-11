"use client";

import { useEffect, useRef, useState } from "react";
import { type Bucket, money, moneyAxis } from "@/lib/report";

/** Escala con números redondos: 0, 500, 1,000, 1,500… */
function niceTicks(max: number): number[] {
  if (max <= 0) return [0, 10000, 20000];
  const raw = max / 4;
  const pow = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * pow).find((s) => s >= raw) ?? raw;
  const ticks: number[] = [];
  for (let v = 0; v <= max + step * 0.999; v += step) ticks.push(Math.round(v));
  return ticks;
}

/**
 * Columnas de una sola serie (ventas por día, por hora). Barras de 24 px como máximo, punta redondeada,
 * ejes discretos y el detalle al pasar el mouse o enfocar con el teclado. "Ver tabla" muestra los números.
 */
export function ColumnChart({
  buckets,
  title,
  subtitle,
  emptyText = "Sin ventas en este periodo.",
}: {
  buckets: Bucket[];
  title: string;
  subtitle?: string;
  emptyText?: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const [table, setTable] = useState(false);
  const max = Math.max(0, ...buckets.map((b) => b.cents));
  const ticks = niceTicks(max);
  const top = ticks[ticks.length - 1] || 1;
  const best = buckets.findIndex((b) => b.cents === max && max > 0);

  // El dibujo usa el ancho real de la tarjeta: así las letras miden siempre 12 px.
  const box = useRef<HTMLDivElement>(null);
  const [W, setW] = useState(720);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const obs = new ResizeObserver(([e]) => setW(Math.max(280, Math.round(e.contentRect.width))));
    obs.observe(el);
    return () => obs.disconnect();
  }, [table, max]);
  const H = 240;
  const left = 64;
  const bottom = 26;
  const plotW = W - left - 8;
  const plotH = H - bottom - 14;
  const slot = plotW / Math.max(1, buckets.length);
  const barW = Math.min(24, slot * 0.62);
  // Con muchos días, la etiqueta de abajo sale cada tantos para que no se encimen.
  // Que quepan las etiquetas: unas 46 px por cada una.
  const every = Math.max(1, Math.ceil(buckets.length / Math.floor(plotW / 46)));
  const y = (c: number) => 14 + plotH - (c / top) * plotH;

  return (
    <section className="rounded-2xl bg-superficie p-5 shadow-[0_3px_12px_rgba(27,26,25,0.06)]">
      <div className="mb-3 flex items-start justify-between gap-4">
        <div>
          <h2 className="text-[17px] font-extrabold">{title}</h2>
          {subtitle && <p className="text-[13px] text-tinta-suave">{subtitle}</p>}
        </div>
        <button
          onClick={() => setTable((t) => !t)}
          className="shrink-0 whitespace-nowrap rounded-full px-3 py-1.5 text-[13px] font-semibold text-tinta-suave hover:bg-hundido"
        >
          {table ? "Ver gráfica" : "Ver tabla"}
        </button>
      </div>

      {max === 0 ? (
        <p className="py-10 text-center text-[14px] text-tinta-suave">{emptyText}</p>
      ) : table ? (
        <div className="max-h-[260px] overflow-auto">
          <table className="tabular w-full text-[14px]">
            <thead className="text-left text-[12px] text-tinta-tenue">
              <tr>
                <th className="py-1.5 font-semibold">Cuándo</th>
                <th className="py-1.5 text-right font-semibold">Ventas</th>
                <th className="py-1.5 text-right font-semibold">Vendido</th>
              </tr>
            </thead>
            <tbody>
              {buckets.map((b) => (
                <tr key={b.key} className="border-t border-linea">
                  <td className="py-1.5 first-letter:uppercase">{b.detail}</td>
                  <td className="py-1.5 text-right">{b.count}</td>
                  <td className="py-1.5 text-right font-semibold">{money(b.cents)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="relative" ref={box}>
          <svg viewBox={`0 0 ${W} ${H}`} className="block h-auto w-full" role="img" aria-label={title}>
            {ticks.map((t) => (
              <g key={t}>
                <line x1={left} x2={W - 8} y1={y(t)} y2={y(t)} stroke="#ebe8e3" strokeWidth={1} />
                <text x={left - 10} y={y(t) + 4} textAnchor="end" fontSize={12} fill="#9c978f" className="tabular">
                  {moneyAxis(t)}
                </text>
              </g>
            ))}
            {buckets.map((b, i) => {
              const cx = left + slot * i + slot / 2;
              const h = Math.max(0, y(0) - y(b.cents));
              const r = Math.min(4, h / 2, barW / 2);
              const x0 = cx - barW / 2;
              const y0 = y(b.cents);
              const active = hover === i;
              return (
                <g
                  key={b.key}
                  tabIndex={0}
                  role="img"
                  aria-label={`${b.detail}: ${money(b.cents)} en ${b.count} ventas`}
                  onMouseEnter={() => setHover(i)}
                  onMouseLeave={() => setHover(null)}
                  onFocus={() => setHover(i)}
                  onBlur={() => setHover(null)}
                  className="outline-none"
                >
                  {/* Área de toque más grande que la barra. */}
                  <rect x={left + slot * i} y={14} width={slot} height={plotH} fill="transparent" />
                  {active && <rect x={left + slot * i + 1} y={14} width={slot - 2} height={plotH} fill="#f5f4f1" rx={6} />}
                  {h > 0 && (
                    <path
                      d={`M${x0},${y(0)} V${y0 + r} Q${x0},${y0} ${x0 + r},${y0} H${x0 + barW - r} Q${x0 + barW},${y0} ${
                        x0 + barW
                      },${y0 + r} V${y(0)} Z`}
                      fill={active || hover === null ? "#0a8f82" : "#7fc4bc"}
                      style={{ transition: "fill 150ms" }}
                    />
                  )}
                  {i % every === 0 && (
                    <text x={cx} y={H - 6} textAnchor="middle" fontSize={12} fill="#66625d">
                      {b.label}
                    </text>
                  )}
                  {/* Solo el mejor momento lleva su monto encima. */}
                  {i === best && hover === null && (
                    <text x={cx} y={y0 - 7} textAnchor="middle" fontSize={12} fontWeight={700} fill="#1b1a19" className="tabular">
                      {moneyAxis(b.cents)}
                    </text>
                  )}
                </g>
              );
            })}
            <line x1={left} x2={W - 8} y1={y(0)} y2={y(0)} stroke="#d6d2cb" strokeWidth={1} />
          </svg>
          {hover !== null && (
            <div
              className="pointer-events-none absolute top-0 z-10 -translate-x-1/2 rounded-xl bg-tinta px-3 py-2 text-[13px] text-white shadow-lg"
              style={{ left: `${((left + slot * hover + slot / 2) / W) * 100}%` }}
            >
              <div className="font-semibold first-letter:uppercase">{buckets[hover].detail}</div>
              <div className="tabular">
                <span className="text-[15px] font-extrabold">{money(buckets[hover].cents)}</span>
                <span className="text-white/70"> · {buckets[hover].count} ventas</span>
              </div>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
