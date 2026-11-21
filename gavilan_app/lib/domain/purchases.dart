import 'models.dart';

// Compras a proveedores y conteos de inventario.

class Supplier {
  const Supplier({required this.id, required this.name, this.phone, this.active = true});

  final String id;
  final String name;
  final String? phone;
  final bool active;

  Supplier copyWith({String? name, String? phone, bool clearPhone = false, bool? active}) => Supplier(
    id: id,
    name: name ?? this.name,
    phone: clearPhone ? null : (phone ?? this.phone),
    active: active ?? this.active,
  );
}

/// Un renglón de la compra: qué llegó, cuánto y a cómo se pagó cada uno.
class PurchaseLine {
  const PurchaseLine({required this.name, required this.qty, required this.unitCostCents, this.productId});

  final String? productId;
  final String name;
  final double qty;
  final int unitCostCents;

  int get totalCents => (unitCostCents * qty).round();

  Map<String, Object?> toJson() => {
    'product_id': productId,
    'name': name,
    'qty': qty,
    'unit_cost': unitCostCents / 100,
  };

  static PurchaseLine fromJson(Map<String, dynamic> j) => PurchaseLine(
    productId: j['product_id'] as String?,
    name: (j['name'] as String?) ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0,
    unitCostCents: (((j['unit_cost'] as num?) ?? 0) * 100).round(),
  );
}

/// Mercancía que llegó de un proveedor. Lo que trae entra al inventario. Lo que se le pagó va aparte
/// ([SupplierPayment]); lo que falta es lo que se le debe.
class Purchase {
  const Purchase({
    required this.id,
    required this.lines,
    required this.totalCents,
    required this.createdAt,
    this.supplierId,
    this.note,
    this.clerk,
  });

  final String id;
  final String? supplierId;
  final List<PurchaseLine> lines;
  final int totalCents;
  final String? note;
  final String? clerk;
  final DateTime createdAt;

  String get summary => lines.map((l) => '${_qty(l.qty)} ${l.name}').join(', ');
}

/// Lo que se le pagó a un proveedor. Con [sessionId] salió del efectivo de esa caja.
class SupplierPayment {
  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.amountCents,
    required this.method,
    required this.createdAt,
    this.purchaseId,
    this.sessionId,
    this.note,
    this.clerk,
  });

  final String id;
  final String supplierId;
  final String? purchaseId;
  final int amountCents;
  final PayMethod method;
  final String? sessionId;
  final String? note;
  final String? clerk;
  final DateTime createdAt;

  /// Salió del cajón de una caja (cuenta en su corte).
  bool get fromCash => method == PayMethod.efectivo && sessionId != null;
}

/// Un producto en el conteo: lo que decía el sistema y lo que se contó.
class CountLine {
  const CountLine({
    required this.productId,
    required this.name,
    required this.system,
    required this.counted,
    this.costCents = 0,
  });

  final String productId;
  final String name;
  final double system;
  final double counted;
  final int costCents;

  /// Positivo: sobró; negativo: faltó.
  double get diff => counted - system;

  Map<String, Object?> toJson() => {
    'product_id': productId,
    'name': name,
    'system': system,
    'counted': counted,
    'cost': costCents / 100,
  };

  static CountLine fromJson(Map<String, dynamic> j) => CountLine(
    productId: (j['product_id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    system: (j['system'] as num?)?.toDouble() ?? 0,
    counted: (j['counted'] as num?)?.toDouble() ?? 0,
    costCents: (((j['cost'] as num?) ?? 0) * 100).round(),
  );
}

/// Un conteo de inventario ya aplicado: la existencia quedó como lo contado.
class StockCount {
  const StockCount({
    required this.id,
    required this.lines,
    required this.createdAt,
    this.missingCostCents = 0,
    this.extraCostCents = 0,
    this.clerk,
  });

  final String id;
  final List<CountLine> lines;
  final DateTime createdAt;

  /// Lo que faltó y lo que sobró, a precio de costo.
  final int missingCostCents;
  final int extraCostCents;
  final String? clerk;

  double get missingPieces => lines.where((l) => l.diff < 0).fold(0.0, (a, l) => a - l.diff);
  double get extraPieces => lines.where((l) => l.diff > 0).fold(0.0, (a, l) => a + l.diff);

  /// Arma el conteo con lo que faltó o sobró a costo.
  static StockCount of({required String id, required List<CountLine> lines, required DateTime at, String? clerk}) {
    var missing = 0, extra = 0;
    for (final l in lines) {
      final cents = (l.diff.abs() * l.costCents).round();
      if (l.diff < 0) missing += cents;
      if (l.diff > 0) extra += cents;
    }
    return StockCount(
      id: id,
      lines: lines,
      createdAt: at,
      missingCostCents: missing,
      extraCostCents: extra,
      clerk: clerk,
    );
  }
}

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

/// Un renglón del pedido sugerido: cuánto pedir de un producto y a quién (el proveedor de su última compra).
class RestockLine {
  const RestockLine({required this.product, required this.qty, required this.perDay, this.supplierId});

  final Product product;
  final double qty;

  /// Lo que se vende al día (promedio de las últimas cuatro semanas).
  final double perDay;
  final String? supplierId;

  int get costCents => (product.costCents * qty).round();
}

/// El mensaje del pedido para mandarle al proveedor por WhatsApp.
String restockMessage({required String business, String? supplier, required List<(String, double)> lines}) {
  final b = StringBuffer()
    ..writeln(
      supplier == null
          ? 'Hola, te hago un pedido para *$business*:'
          : 'Hola $supplier, te hago un pedido para *$business*:',
    )
    ..writeln('');
  for (final (name, qty) in lines) {
    b.writeln('• ${_qty(qty)} $name');
  }
  b
    ..writeln('')
    ..writeln('¡Gracias!');
  return b.toString().trimRight();
}
