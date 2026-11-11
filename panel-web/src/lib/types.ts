// Lo que el panel lee de Supabase, ya en centavos y con fechas.

export type PayMethod = "efectivo" | "tarjeta" | "transferencia" | "fiado";

export type Sale = {
  id: string;
  at: Date;
  totalCents: number;
  method: PayMethod;
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
};

export type Period = { from: Date; to: Date; label: string };
