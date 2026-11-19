// Lo que el panel lee de Supabase, ya en centavos y con fechas.

export type PayMethod = "efectivo" | "tarjeta" | "transferencia" | "fiado";

export type Sale = {
  id: string;
  at: Date;
  totalCents: number;
  method: PayMethod;
  /** Pagada en partes (pago mixto o cuenta dividida): cuánto entró por cada método. */
  parts?: { method: PayMethod; totalCents: number }[];
  /** "K7-0043", como en el ticket. */
  folio?: string;
  /** Quién atendió (con PIN en el mostrador); null si no se usan PIN. */
  clerk?: string | null;
  /** Nombre de la caja ("Mostrador") o "Caja K7" si no tiene nombre. */
  register?: string;
};

/** Devolución de una venta de otro día (la venta sigue contando en su día). */
export type SaleReturn = {
  at: Date;
  folio: string;
  summary: string;
  amountCents: number;
  /** Lo que salió en efectivo de la caja. */
  cashCents: number;
};

export type SaleItem = {
  saleId: string;
  at: Date;
  name: string;
  qty: number;
  totalCents: number;
  /** Costo de lo vendido; null si el producto no tiene costo capturado. */
  costCents: number | null;
};

export type CashCut = {
  id: string;
  openedAt: Date;
  closedAt: Date;
  expectedCents: number;
  countedCents: number;
};

export type Debtor = { name: string; balanceCents: number };

export type LowStock = { name: string; stock: number; minStock: number };

/** Todo lo que necesita la pantalla de reportes para un periodo. */
export type ReportData = {
  sales: Sale[];
  /** Ventas del periodo anterior del mismo largo, para comparar. */
  previousSales: Sale[];
  items: SaleItem[];
  /** Abonos de fiados cobrados en el periodo. */
  creditPaymentsCents: number;
  cuts: CashCut[];
  debtors: Debtor[];
  lowStock: LowStock[];
  /** Devoluciones de ventas de otros días hechas en el periodo. */
  returns: SaleReturn[];
};

export type Period = { from: Date; to: Date; label: string };
