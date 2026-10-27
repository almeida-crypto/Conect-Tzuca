import '../domain/models.dart';
import 'store.dart';

/// Datos de ejemplo de una tiendita para ver la app funcionando de punta a punta.
StoreState seedStore(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int daysBack, int hour, [int minute = 0]) =>
      today.subtract(Duration(days: daysBack)).add(Duration(hours: hour, minutes: minute));

  final products = [
    const Product(
      id: 'p1',
      name: 'Coca 600 ml',
      priceCents: 1800,
      costCents: 1350,
      iconId: 'refresco',
      barcode: '7501055300075',
      trackStock: true,
      stock: 24,
      minStock: 6,
    ),
    const Product(
      id: 'p2',
      name: 'Sabritas',
      priceCents: 1700,
      costCents: 1250,
      iconId: 'botana',
      barcode: '7501011101456',
      trackStock: true,
      stock: 3,
      minStock: 5,
    ),
    const Product(
      id: 'p3',
      name: 'Huevo, kg',
      priceCents: 4200,
      costCents: 3400,
      iconId: 'huevo',
      trackStock: true,
      stock: 12,
      minStock: 3,
    ),
    const Product(
      id: 'p4',
      name: 'Tortilla, kg',
      priceCents: 2400,
      costCents: 1900,
      iconId: 'tortilla',
      trackStock: true,
      stock: 8,
      minStock: 2,
    ),
    const Product(
      id: 'p5',
      name: 'Jabón Zote',
      priceCents: 1500,
      costCents: 1100,
      iconId: 'limpieza',
      barcode: '7501025403010',
      trackStock: true,
      stock: 2,
      minStock: 4,
    ),
    const Product(
      id: 'p6',
      name: 'Agua 1 L',
      priceCents: 1200,
      costCents: 800,
      iconId: 'agua',
      barcode: '7501086801046',
      trackStock: true,
      stock: 30,
      minStock: 8,
    ),
    const Product(id: 'p7', name: 'Pan dulce', priceCents: 800, costCents: 500, iconId: 'pan'),
    const Product(
      id: 'p8',
      name: 'Café soluble',
      priceCents: 3500,
      costCents: 2700,
      iconId: 'cafe',
      trackStock: true,
      stock: 6,
      minStock: 2,
    ),
  ];

  const lupe = Customer(id: 'c1', name: 'Doña Lupe', phone: '9971234567');
  const beto = Customer(id: 'c2', name: 'Don Beto');
  const chelo = Customer(id: 'c3', name: 'Sra. Chelo', phone: '9977654321');
  const pedro = Customer(id: 'c4', name: 'Pedro el albañil');

  final credit = [
    CreditEntry(id: 'e1', customerId: lupe.id, type: CreditType.cargo, amountCents: 32000, createdAt: at(3, 18)),
    CreditEntry(id: 'e2', customerId: beto.id, type: CreditType.cargo, amountCents: 38000, createdAt: at(25, 12)),
    CreditEntry(
      id: 'e3',
      customerId: beto.id,
      type: CreditType.abono,
      amountCents: 10000,
      createdAt: at(18, 10),
      method: PayMethod.efectivo,
    ),
    CreditEntry(id: 'e4', customerId: beto.id, type: CreditType.cargo, amountCents: 30000, createdAt: at(16, 19)),
    CreditEntry(id: 'e5', customerId: chelo.id, type: CreditType.cargo, amountCents: 14000, createdAt: at(6, 9)),
    CreditEntry(id: 'e6', customerId: pedro.id, type: CreditType.cargo, amountCents: 20000, createdAt: at(21, 14)),
  ];

  final session = CashSession(id: 's-hoy', openedAt: at(0, 7, 30), openingCents: 50000);
  final yesterday = CashSession(
    id: 's-ayer',
    openedAt: at(1, 7, 30),
    openingCents: 50000,
    closedAt: at(1, 21, 10),
    expectedCents: 268000,
    countedCents: 267500,
  );

  SaleLine line(Product p, double qty) =>
      SaleLine(key: p.id, productId: p.id, name: p.name, unitCents: p.priceCents, unitCostCents: p.costCents, qty: qty);

  final sales = [
    Sale(
      id: 'v1',
      folio: 38,
      createdAt: at(0, 8, 10),
      sessionId: session.id,
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 10000,
      lines: [line(products[2], 1), line(products[3], 1)],
    ),
    Sale(
      id: 'v2',
      folio: 39,
      createdAt: at(0, 9, 2),
      sessionId: session.id,
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 5000,
      lines: [line(products[0], 2)],
    ),
    Sale(
      id: 'v3',
      folio: 40,
      createdAt: at(0, 9, 40),
      sessionId: session.id,
      kind: SaleKind.pagada,
      method: PayMethod.transferencia,
      lines: [line(products[7], 1), line(products[6], 4)],
    ),
    Sale(
      id: 'v4',
      folio: 41,
      createdAt: at(0, 10, 15),
      sessionId: session.id,
      kind: SaleKind.pagada,
      method: PayMethod.efectivo,
      receivedCents: 2000,
      lines: [line(products[5], 1)],
    ),
    Sale(
      id: 'v5',
      folio: 42,
      createdAt: at(0, 10, 50),
      sessionId: session.id,
      kind: SaleKind.pagada,
      method: PayMethod.tarjeta,
      lines: [line(products[4], 2), line(products[1], 2)],
    ),
  ];

  final movements = [
    CashMovement(
      id: 'm1',
      sessionId: session.id,
      kind: CashKind.gasto,
      amountCents: 8000,
      concept: 'Hielo',
      createdAt: at(0, 8, 0),
    ),
    CashMovement(
      id: 'm2',
      sessionId: session.id,
      kind: CashKind.gasto,
      amountCents: 10000,
      concept: 'Gas',
      createdAt: at(0, 9, 30),
    ),
  ];

  return StoreState(
    businessId: 'demo',
    isDemo: true,
    businessName: 'Abarrotes Doña Mary',
    products: products,
    sales: sales,
    customers: const [lupe, beto, chelo, pedro],
    credit: [
      ...credit,
      CreditEntry(
        id: 'e7',
        customerId: chelo.id,
        type: CreditType.abono,
        amountCents: 5000,
        createdAt: at(0, 10, 30),
        method: PayMethod.efectivo,
        sessionId: session.id,
      ),
    ],
    sessions: [yesterday, session],
    movements: movements,
    nextFolio: 43,
  );
}
