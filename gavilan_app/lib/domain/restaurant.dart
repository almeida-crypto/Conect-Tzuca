/// Restaurante: mesas, comandas y lo que pasa en la cocina.
library;

enum OrderStatus { abierta, cerrada, cancelada }

/// Camino de un platillo: el mesero lo manda, cocina lo prepara y avisa, el mesero lo lleva.
enum KitchenStatus {
  pendiente('En cola'),
  preparando('Preparando'),
  listo('Listo'),
  servido('Servido'),
  cancelado('Cancelado');

  const KitchenStatus(this.label);

  final String label;
}

class DiningTable {
  const DiningTable({required this.id, required this.name, this.position = 0, this.active = true, this.zone});

  final String id;
  final String name;
  final int position;
  final bool active;

  /// "Planta baja", "Segunda planta", "Terraza". null = sin zona.
  final String? zone;

  /// "Mesa 1 · Terraza", para la cocina y el ticket.
  String get fullName => zone == null ? name : '$name · $zone';

  DiningTable copyWith({String? name, bool? active, String? zone, bool clearZone = false}) => DiningTable(
    id: id,
    name: name ?? this.name,
    position: position,
    active: active ?? this.active,
    zone: clearZone ? null : (zone ?? this.zone),
  );
}

/// Una comanda: la cuenta abierta de una mesa o un pedido para llevar.
class RestaurantOrder {
  const RestaurantOrder({
    required this.id,
    required this.createdAt,
    this.tableId,
    this.label,
    this.status = OrderStatus.abierta,
    this.closedAt,
  });

  final String id;
  final String? tableId;

  /// Para llevar: a nombre de quién ("Juan", "Didi 4521").
  final String? label;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  bool get isOpen => status == OrderStatus.abierta;
  bool get takeout => tableId == null;

  /// La misma cuenta en otra mesa (se cambiaron de lugar).
  RestaurantOrder moveTo(String newTableId) => RestaurantOrder(
    id: id,
    tableId: newTableId,
    label: label,
    createdAt: createdAt,
    status: status,
    closedAt: closedAt,
  );

  RestaurantOrder close(OrderStatus status, DateTime at) =>
      RestaurantOrder(id: id, tableId: tableId, label: label, createdAt: createdAt, status: status, closedAt: at);
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    required this.qty,
    required this.unitCents,
    required this.createdAt,
    this.productId,
    this.notes,
    this.status = KitchenStatus.pendiente,
    this.sentAt,
    this.readyAt,
    this.servedAt,
  });

  final String id;
  final String orderId;
  final String? productId;
  final String name;
  final double qty;
  final int unitCents;

  /// "Sin cebolla", "bien dorada".
  final String? notes;
  final KitchenStatus status;
  final DateTime createdAt;

  /// Cuándo se mandó a cocina; null = el mesero todavía no la manda.
  final DateTime? sentAt;
  final DateTime? readyAt;
  final DateTime? servedAt;

  bool get sent => sentAt != null;
  bool get cancelled => status == KitchenStatus.cancelado;
  int get totalCents => cancelled ? 0 : (unitCents * qty).round();

  OrderItem copyWith({
    double? qty,
    String? notes,
    KitchenStatus? status,
    DateTime? sentAt,
    DateTime? readyAt,
    DateTime? servedAt,
  }) => OrderItem(
    id: id,
    orderId: orderId,
    productId: productId,
    name: name,
    qty: qty ?? this.qty,
    unitCents: unitCents,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt,
    sentAt: sentAt ?? this.sentAt,
    readyAt: readyAt ?? this.readyAt,
    servedAt: servedAt ?? this.servedAt,
  );
}
