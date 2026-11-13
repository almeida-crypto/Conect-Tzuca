import 'models.dart';

/// Margen de ganancia sobre el precio: de cada peso que paga el cliente, cuánto te queda.
/// Null si no hay costo capturado (no se puede saber).
double? marginPct({required int priceCents, required int costCents}) {
  if (costCents <= 0 || priceCents <= 0) return null;
  return (priceCents - costCents) / priceCents;
}

/// Lo que dejó un producto en un periodo (por ejemplo, un turno de caja).
class ProductProfit {
  const ProductProfit({
    required this.name,
    required this.qty,
    required this.soldCents,
    required this.costCents,
    required this.knownCost,
  });

  final String name;
  final double qty;

  /// Lo que pagaron los clientes.
  final int soldCents;

  /// Lo que costó lo vendido (solo de lo que tiene costo capturado).
  final int costCents;

  /// Todo lo vendido de este producto tenía costo capturado.
  final bool knownCost;

  int get profitCents => soldCents - costCents;

  /// Precio promedio por pieza o kilo.
  int get unitPriceCents => qty == 0 ? 0 : (soldCents / qty).round();
  int get unitCostCents => qty == 0 ? 0 : (costCents / qty).round();

  double? get margin => knownCost && soldCents > 0 ? profitCents / soldCents : null;
}

/// Resumen de ganancia: renglones por producto (los de mayor ganancia primero) y totales.
class ProfitReport {
  const ProfitReport(this.products);

  final List<ProductProfit> products;

  List<ProductProfit> get withCost => products.where((p) => p.knownCost).toList();
  List<ProductProfit> get withoutCost => products.where((p) => !p.knownCost).toList();

  int get soldCents => products.fold(0, (a, p) => a + p.soldCents);

  /// Venta, costo y ganancia contando solo lo que tiene costo.
  int get soldWithCostCents => withCost.fold(0, (a, p) => a + p.soldCents);
  int get costCents => withCost.fold(0, (a, p) => a + p.costCents);
  int get profitCents => soldWithCostCents - costCents;
  double? get margin => soldWithCostCents == 0 ? null : profitCents / soldWithCostCents;

  /// Qué parte de lo vendido tiene costo capturado (0 a 1).
  double get coverage => soldCents == 0 ? 1 : soldWithCostCents / soldCents;

  bool get isEmpty => products.isEmpty;
}

/// Junta los renglones de [sales] por producto. Las ventas rápidas por monto (sin producto) se juntan en una.
ProfitReport profitOf(Iterable<Sale> sales) {
  final byKey = <String, ({String name, double qty, int sold, int cost, bool known})>{};
  for (final sale in sales) {
    // Con descuento, cada producto cuenta lo que de verdad se cobró por él (el descuento se reparte).
    final subtotal = sale.subtotalCents;
    final factor = subtotal == 0 ? 1.0 : sale.totalCents / subtotal;
    for (final l in sale.lines) {
      final key = l.productId ?? '_rapida';
      final name = l.productId == null ? 'Ventas rápidas por monto' : l.name;
      final lineCost = (l.unitCostCents * l.qty).round();
      final prev = byKey[key];
      byKey[key] = (
        name: prev?.name ?? name,
        qty: (prev?.qty ?? 0) + l.qty,
        sold: (prev?.sold ?? 0) + (l.totalCents * factor).round(),
        cost: (prev?.cost ?? 0) + (l.unitCostCents > 0 ? lineCost : 0),
        known: (prev?.known ?? true) && l.unitCostCents > 0,
      );
    }
  }
  final list =
      [
        for (final v in byKey.values)
          ProductProfit(name: v.name, qty: v.qty, soldCents: v.sold, costCents: v.cost, knownCost: v.known),
      ]..sort((a, b) {
        if (a.knownCost != b.knownCost) return a.knownCost ? -1 : 1;
        return a.knownCost ? b.profitCents.compareTo(a.profitCents) : b.soldCents.compareTo(a.soldCents);
      });
  return ProfitReport(list);
}
