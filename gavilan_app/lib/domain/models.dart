// Modelos del dominio. Reflejan las tablas de Supabase (proyecto-Gavilan) para
// poder conectar la sincronización después sin cambiar las pantallas.

enum PayMethod { efectivo, tarjeta, transferencia }

extension PayMethodLabel on PayMethod {
  String get label => switch (this) {
    PayMethod.efectivo => 'Efectivo',
    PayMethod.tarjeta => 'Tarjeta',
    PayMethod.transferencia => 'Transferencia',
  };

  /// Para botones angostos.
  String get short => this == PayMethod.transferencia ? 'Transfer.' : label;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.costCents = 0,
    this.barcode,
    this.iconId = 'otro',
    this.trackStock = false,
    this.stock = 0,
    this.minStock,
    this.active = true,
  });

  final String id;
  final String name;
  final int priceCents;
  final int costCents;
  final String? barcode;
  final String iconId;
  final bool trackStock;
  final double stock;
  final double? minStock;
  final bool active;

  bool get isLow => trackStock && minStock != null && stock <= minStock!;

  Product copyWith({
    String? name,
    int? priceCents,
    int? costCents,
    String? barcode,
    bool clearBarcode = false,
    String? iconId,
    bool? trackStock,
    double? stock,
    double? minStock,
    bool clearMinStock = false,
    bool? active,
  }) => Product(
    id: id,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    costCents: costCents ?? this.costCents,
    barcode: clearBarcode ? null : (barcode ?? this.barcode),
    iconId: iconId ?? this.iconId,
    trackStock: trackStock ?? this.trackStock,
    stock: stock ?? this.stock,
    minStock: clearMinStock ? null : (minStock ?? this.minStock),
    active: active ?? this.active,
  );
}

/// Renglón del carrito o de una venta. productId nulo = venta rápida sin producto.
class SaleLine {
  const SaleLine({
    required this.key,
    required this.name,
    required this.unitCents,
    required this.qty,
    this.productId,
    this.unitCostCents = 0,
  });

  final String key;
  final String? productId;
  final String name;
  final int unitCents;
  final int unitCostCents;
  final double qty;

  int get totalCents => (unitCents * qty).round();

  SaleLine withQty(double q) =>
      SaleLine(key: key, productId: productId, name: name, unitCents: unitCents, unitCostCents: unitCostCents, qty: q);
}

enum SaleKind { pagada, fiada }

class Sale {
  const Sale({
    required this.id,
    required this.folio,
    required this.createdAt,
    required this.lines,
    required this.kind,
    required this.sessionId,
    this.method,
    this.receivedCents,
    this.customerId,
  });

  final String id;
  final int folio;
  final DateTime createdAt;
  final List<SaleLine> lines;
  final SaleKind kind;
  final String? sessionId;
  final PayMethod? method;
  final int? receivedCents;
  final String? customerId;

  int get totalCents => lines.fold(0, (a, l) => a + l.totalCents);
  int get changeCents => (receivedCents ?? totalCents) - totalCents;
}

class Customer {
  const Customer({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;
}

enum CreditType { cargo, abono }

class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountCents,
    required this.createdAt,
    this.saleId,
    this.method,
    this.sessionId,
  });

  final String id;
  final String customerId;
  final CreditType type;
  final int amountCents;
  final DateTime createdAt;
  final String? saleId;
  final PayMethod? method;
  final String? sessionId;
}

enum CashKind { entrada, gasto }

class CashMovement {
  const CashMovement({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.amountCents,
    required this.concept,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final CashKind kind;
  final int amountCents;
  final String concept;
  final DateTime createdAt;
}

class CashSession {
  const CashSession({
    required this.id,
    required this.openedAt,
    required this.openingCents,
    this.closedAt,
    this.expectedCents,
    this.countedCents,
  });

  final String id;
  final DateTime openedAt;
  final int openingCents;
  final DateTime? closedAt;
  final int? expectedCents;
  final int? countedCents;

  bool get isOpen => closedAt == null;
  int? get differenceCents => (countedCents == null || expectedCents == null) ? null : countedCents! - expectedCents!;

  CashSession close({required DateTime at, required int expected, required int counted}) => CashSession(
    id: id,
    openedAt: openedAt,
    openingCents: openingCents,
    closedAt: at,
    expectedCents: expected,
    countedCents: counted,
  );
}

/// Resumen del corte, calculado siempre a partir de ventas, abonos y movimientos.
class CashSummary {
  const CashSummary({
    required this.openingCents,
    required this.cashSalesCents,
    required this.otherSalesCents,
    required this.creditSalesCents,
    required this.cashAbonosCents,
    required this.otherAbonosCents,
    required this.entradasCents,
    required this.gastosCents,
    required this.salesCount,
  });

  final int openingCents;
  final int cashSalesCents;
  final int otherSalesCents;
  final int creditSalesCents;
  final int cashAbonosCents;
  final int otherAbonosCents;
  final int entradasCents;
  final int gastosCents;
  final int salesCount;

  int get expectedCashCents => openingCents + cashSalesCents + cashAbonosCents + entradasCents - gastosCents;
  int get totalSoldCents => cashSalesCents + otherSalesCents + creditSalesCents;
}

/// Cliente con su saldo, para la libreta de fiados.
class Debtor {
  const Debtor({required this.customer, required this.balanceCents, required this.since, required this.entries});

  final Customer customer;
  final int balanceCents;

  /// Fecha del último abono o, si nunca ha pagado, del primer cargo.
  final DateTime since;
  final List<CreditEntry> entries;
}
