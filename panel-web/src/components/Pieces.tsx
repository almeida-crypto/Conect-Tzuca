"use client";

import type { ReactNode } from "react";
import { money, percent, type Share } from "@/lib/report";

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <section className={`rounded-2xl bg-superficie p-5 shadow-[0_3px_12px_rgba(27,26,25,0.06)] ${className}`}>
      {children}
    </section>
  );
}

export function CardTitle({ title, subtitle, right }: { title: string; subtitle?: string; right?: ReactNode }) {
  return (
    <div className="mb-3 flex items-start justify-between gap-3">
      <div>
        <h2 className="text-[17px] font-extrabold">{title}</h2>
        {subtitle && <p className="text-[13px] text-tinta-suave">{subtitle}</p>}
      </div>
      {right}
    </div>
  );
}

/** Cifra clave con su comparación contra el periodo anterior. */
export function StatTile({
  label,
  value,
  delta,
  note,
  tone = "tinta",
  delay = 0,
}: {
  label: string;
  value: string;
  /** Cambio en %; null = no hay con qué comparar. */
  delta?: number | null;
  note?: string;
  tone?: "tinta" | "cenote" | "rojo";
  delay?: number;
}) {
  const color = { tinta: "text-tinta", cenote: "text-cenote", rojo: "text-rojo" }[tone];
  return (
    <div
      className="entrar rounded-2xl bg-superficie p-4 shadow-[0_3px_12px_rgba(27,26,25,0.06)]"
      style={{ animationDelay: `${delay}ms` }}
    >
      <div className="text-[13px] font-semibold text-tinta-suave">{label}</div>
      <div className={`tabular mt-1 text-[26px] leading-tight font-extrabold tracking-tight ${color}`}>{value}</div>
      <div className="mt-1 flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[12.5px]">
        {delta !== undefined && delta !== null && (
          <span
            className={`tabular shrink-0 whitespace-nowrap rounded-full px-1.5 py-0.5 font-bold ${
              delta >= 0 ? "bg-cenote-suave text-cenote" : "bg-rojo-suave text-rojo"
            }`}
          >
            {delta >= 0 ? "▲" : "▼"} {Math.abs(Math.round(delta))}%
          </span>
        )}
        {note && <span className="text-tinta-tenue">{note}</span>}
      </div>
    </div>
  );
}

/** Barras horizontales con nombre, monto y porcentaje (formas de pago, lo más vendido). */
export function BarList({ rows, empty }: { rows: Share[]; empty: string }) {
  if (rows.length === 0) return <p className="py-6 text-center text-[14px] text-tinta-suave">{empty}</p>;
  const max = Math.max(...rows.map((r) => r.cents));
  return (
    <ul className="space-y-3">
      {rows.map((r, i) => (
        <li key={r.key} className="group">
          <div className="mb-1 flex items-baseline justify-between gap-3 text-[14px]">
            <span className="truncate font-semibold">
              {r.label}
              {r.extra && <span className="ml-2 font-normal text-tinta-tenue">{r.extra}</span>}
            </span>
            <span className="tabular shrink-0">
              <span className="font-bold">{money(r.cents)}</span>
              <span className="ml-2 text-tinta-tenue">{percent(r.share)}</span>
            </span>
          </div>
          <div className="h-2.5 overflow-hidden rounded-full bg-hundido">
            <div
              className="bar-grow h-full rounded-full bg-cenote-vivo transition-[filter] group-hover:brightness-110"
              style={{ width: `${(r.cents / max) * 100}%`, animationDelay: `${i * 40}ms` }}
            />
          </div>
        </li>
      ))}
    </ul>
  );
}
