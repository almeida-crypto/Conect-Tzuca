"use client";

import { Card, CardTitle } from "@/components/Pieces";
import { elapsed, type Floor, type FloorTable } from "@/lib/floor";
import { money } from "@/lib/report";

/** Piso de mosaico, como el de las fondas: líneas finas cada 28 px. */
const tiles =
  "repeating-linear-gradient(0deg, transparent 0 27px, rgba(227,224,218,0.6) 27px 28px)," +
  "repeating-linear-gradient(90deg, transparent 0 27px, rgba(227,224,218,0.6) 27px 28px)";

const updated = new Intl.DateTimeFormat("es-MX", { hour: "2-digit", minute: "2-digit" });

/** Mapa del salón: cada mesa dibujada con sus sillas; ocupada en achiote, libre en blanco. */
export function FloorMap({ floor }: { floor: Floor }) {
  const zones: (string | null)[] = [];
  for (const t of floor.tables) if (!zones.includes(t.zone)) zones.push(t.zone);
  const busy = floor.tables.filter((t) => t.order);
  const due =
    busy.reduce((a, t) => a + (t.order?.totalCents ?? 0), 0) + floor.takeouts.reduce((a, t) => a + t.order.totalCents, 0);

  return (
    <Card>
      <CardTitle
        title="Mesas ahora"
        subtitle={`${busy.length} de ${floor.tables.length} ocupadas · ${money(due)} por cobrar`}
        right={
          <span className="shrink-0 text-[12.5px] text-tinta-tenue">
            Se actualiza solo · {updated.format(floor.at)}
          </span>
        }
      />
      <div className="mb-4 flex flex-wrap gap-x-4 gap-y-1 text-[12.5px] text-tinta-suave">
        <Legend className="border-marca bg-marca-suave" label="Ocupada" />
        <Legend className="border-linea bg-superficie" label="Libre" />
        <span className="inline-flex items-center gap-1.5">
          <span className="rounded-full bg-cenote px-1.5 text-[11px] font-bold text-white">listo</span>
          Platillos listos en cocina
        </span>
      </div>

      <div className="space-y-4">
        {zones.map((zone) => {
          const tables = floor.tables.filter((t) => t.zone === zone);
          const free = tables.filter((t) => !t.order).length;
          return (
            <section
              key={zone ?? "salon"}
              aria-label={zone ?? "Salón"}
              className="rounded-2xl border border-linea bg-fondo p-3"
              style={{ backgroundImage: tiles }}
            >
              <div className="mb-2 flex items-baseline gap-2 px-1">
                <h3 className="text-[15px] font-extrabold">{zone ?? "Salón"}</h3>
                <span className="text-[12.5px] font-semibold text-tinta-tenue">
                  {free} de {tables.length} {tables.length === 1 ? "libre" : "libres"}
                </span>
              </div>
              <ul className="grid grid-cols-[repeat(auto-fill,minmax(132px,1fr))] gap-2">
                {tables.map((t) => (
                  <li key={t.id}>
                    <TableDrawing table={t} now={floor.at} />
                  </li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>

      {floor.takeouts.length > 0 && (
        <div className="mt-4">
          <h3 className="mb-2 text-[15px] font-extrabold">Para llevar</h3>
          <ul className="flex flex-wrap gap-2">
            {floor.takeouts.map((t) => (
              <li
                key={t.id}
                className="flex min-w-[180px] items-center gap-3 rounded-xl border-[1.5px] border-izamal/60 bg-izamal-suave px-3 py-2"
              >
                <BagIcon />
                <div className="min-w-0">
                  <div className="truncate text-[14px] font-bold">{t.label}</div>
                  <div className="tabular text-[12.5px] text-tinta-suave">
                    {money(t.order.totalCents)} · {elapsed(t.order.since, floor.at)}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </Card>
  );
}

function Legend({ className, label }: { className: string; label: string }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className={`inline-block h-3 w-4 rounded-[4px] border-[1.5px] ${className}`} />
      {label}
    </span>
  );
}

/** Una mesa vista desde arriba: la mesa con cuatro sillas y, encima, su nombre y lo que lleva. */
function TableDrawing({ table, now }: { table: FloorTable; now: Date }) {
  const o = table.order;
  const busy = o !== null;
  const label = busy
    ? `${table.name}, ocupada: ${money(o.totalCents)}, ${o.dishes} platillos, desde hace ${elapsed(o.since, now)}${
        o.ready ? `, ${o.ready} listos en cocina` : ""
      }`
    : `${table.name}, libre`;
  const chair = busy ? "var(--color-marca)" : "var(--color-linea)";
  return (
    <div role="img" aria-label={label} title={label} className="relative mx-auto aspect-[132/112] w-full max-w-[170px]">
      <svg viewBox="0 0 132 112" className="absolute inset-0 h-full w-full" aria-hidden>
        {/* Sillas: dos arriba, dos abajo y una a cada lado. */}
        {[
          [34, 4, 24, 12],
          [74, 4, 24, 12],
          [34, 96, 24, 12],
          [74, 96, 24, 12],
          [2, 44, 12, 24],
          [118, 44, 12, 24],
        ].map(([x, y, w, h], i) => (
          <rect key={i} x={x} y={y} width={w} height={h} rx={5} fill={chair} opacity={busy ? 0.55 : 1} />
        ))}
        <rect
          x={18}
          y={20}
          width={96}
          height={72}
          rx={12}
          fill={busy ? "var(--color-marca-suave)" : "var(--color-superficie)"}
          stroke={busy ? "var(--color-marca)" : "var(--color-linea)"}
          strokeWidth={2}
        />
      </svg>
      <div className="absolute inset-x-[16%] inset-y-[20%] flex flex-col items-center justify-center text-center leading-tight">
        <div className="max-w-full truncate text-[13px] font-extrabold">{table.name}</div>
        {busy ? (
          <>
            <div className="tabular text-[14px] font-extrabold text-marca-oscura">{money(o.totalCents)}</div>
            <div className="tabular text-[11px] text-tinta-suave">{elapsed(o.since, now)}</div>
          </>
        ) : (
          <div className="text-[12px] font-semibold text-tinta-tenue">Libre</div>
        )}
      </div>
      {busy && o.ready > 0 && (
        <span className="absolute top-[14%] right-[6%] rounded-full bg-cenote px-1.5 text-[11px] font-bold text-white shadow">
          {o.ready} {o.ready === 1 ? "listo" : "listos"}
        </span>
      )}
      {busy && !o.ready && o.cooking && (
        <span className="absolute top-[14%] right-[6%] rounded-full bg-hundido px-1.5 text-[11px] font-bold text-tinta-suave">
          en cocina
        </span>
      )}
    </div>
  );
}

function BagIcon() {
  return (
    <svg viewBox="0 0 24 24" width={22} height={22} aria-hidden className="shrink-0 text-[#8a5a00]">
      <path
        d="M6 8h12l-1 12H7L6 8Zm3 0V6a3 3 0 0 1 6 0v2"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.8}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
    </svg>
  );
}
