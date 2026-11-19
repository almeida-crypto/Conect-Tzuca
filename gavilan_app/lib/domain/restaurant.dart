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

/// Forma de la mesa en el plano.
enum TableShape { cuadrada, redonda }

/// Lo que se dibuja en el plano además de las mesas. [remote] es como se guarda en Supabase.
enum FloorItemKind {
  pared('Pared', 'wall', 300, 12),
  puerta('Puerta', 'door', 80, 80),
  ventana('Ventana', 'window', 160, 12),
  barra('Barra', 'bar', 260, 56),
  cocina('Cocina', 'kitchen', 220, 140),
  bano('Baños', 'restroom', 110, 90),
  caja('Caja', 'register', 100, 60);

  const FloorItemKind(this.label, this.remote, this.width, this.height);

  final String label;
  final String remote;

  /// Tamaño con el que se agrega (puntos del plano).
  final int width;
  final int height;

  /// Paredes y ventanas son una línea: se alargan o se giran; lo demás se agranda.
  bool get isLine => this == pared || this == ventana;

  /// Lleva su nombre escrito encima.
  bool get named => this == barra || this == cocina || this == bano || this == caja;

  static FloorItemKind fromRemote(String? v) =>
      FloorItemKind.values.firstWhere((k) => k.remote == v, orElse: () => FloorItemKind.pared);
}

/// Una pared, puerta, barra... en el plano de una zona.
class FloorItem {
  const FloorItem({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zone,
    this.label,
    this.active = true,
  });

  final String id;
  final String? zone;
  final FloorItemKind kind;

  /// Nombre propio ("Barra de bebidas"); null = el del tipo.
  final String? label;
  final int x;
  final int y;
  final int width;
  final int height;
  final bool active;

  String get title => (label == null || label!.trim().isEmpty) ? kind.label : label!;

  FloorItem copyWith({int? x, int? y, int? width, int? height, String? label, bool clearLabel = false, bool? active}) =>
      FloorItem(
        id: id,
        kind: kind,
        zone: zone,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        label: clearLabel ? null : (label ?? this.label),
        active: active ?? this.active,
      );
}

class DiningTable {
  const DiningTable({
    required this.id,
    required this.name,
    this.position = 0,
    this.active = true,
    this.zone,
    this.x,
    this.y,
    this.shape = TableShape.cuadrada,
    this.seats = 4,
  });

  final String id;
  final String name;
  final int position;
  final bool active;

  /// "Planta baja", "Segunda planta", "Terraza". null = sin zona.
  final String? zone;

  /// Dónde está en el plano de su zona (puntos de diseño). null = se acomoda sola.
  final int? x;
  final int? y;

  final TableShape shape;

  /// Sillas que se dibujan alrededor.
  final int seats;

  bool get placed => x != null && y != null;

  /// "Mesa 1 · Terraza", para la cocina y el ticket.
  String get fullName => zone == null ? name : '$name · $zone';

  /// Al cambiar de zona se suelta del plano (en la otra zona se acomoda sola).
  DiningTable copyWith({
    String? name,
    bool? active,
    String? zone,
    bool clearZone = false,
    int? x,
    int? y,
    bool unplace = false,
    TableShape? shape,
    int? seats,
  }) => DiningTable(
    id: id,
    name: name ?? this.name,
    position: position,
    active: active ?? this.active,
    zone: clearZone ? null : (zone ?? this.zone),
    x: unplace ? null : (x ?? this.x),
    y: unplace ? null : (y ?? this.y),
    shape: shape ?? this.shape,
    seats: seats ?? this.seats,
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

/// Extra con precio que el dueño da de alta una vez ("Extra queso", +\$10).
class Extra {
  const Extra({required this.id, required this.name, required this.priceCents, this.active = true, this.position = 0});

  final String id;
  final String name;
  final int priceCents;
  final bool active;
  final int position;

  Extra copyWith({String? name, int? priceCents, bool? active}) => Extra(
    id: id,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    active: active ?? this.active,
    position: position,
  );
}

/// Un extra ya puesto en un platillo: nombre y precio de ese momento (si luego cambia, la comanda no).
class ItemExtra {
  const ItemExtra(this.name, this.cents);

  final String name;
  final int cents;

  @override
  bool operator ==(Object other) => other is ItemExtra && other.name == name && other.cents == cents;

  @override
  int get hashCode => Object.hash(name, cents);
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    required this.qty,
    required this.unitCents,
    this.extras = const [],
    required this.createdAt,
    this.productId,
    this.notes,
    this.status = KitchenStatus.pendiente,
    this.sentAt,
    this.readyAt,
    this.servedAt,
    this.paidQty = 0,
  });

  /// Piezas que ya se cobraron al dividir la cuenta por platillos.
  final double paidQty;

  /// Lo que falta por cobrar de este platillo.
  double get dueQty => cancelled ? 0 : (qty - paidQty).clamp(0, qty).toDouble();

  /// Ya se cobró completo.
  bool get fullyPaid => !cancelled && dueQty <= 0.0001;

  /// Lo que falta por cobrar, en centavos.
  int get dueCents => (unitWithExtrasCents * dueQty).round();

  final String id;
  final String orderId;
  final String? productId;
  final String name;
  final double qty;

  /// Precio del platillo solo, sin extras.
  final int unitCents;

  /// Extras con precio ("Extra queso" +\$10). Se cobran por cada pieza.
  final List<ItemExtra> extras;

  /// Precio de una pieza con sus extras.
  int get unitWithExtrasCents => unitCents + extras.fold(0, (a, e) => a + e.cents);

  /// "Tacos de pastor (extra queso, doble carne)", para la cuenta y el ticket.
  String get fullName => extras.isEmpty ? name : '$name (${extras.map((e) => e.name.toLowerCase()).join(', ')})';

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
  int get totalCents => cancelled ? 0 : (unitWithExtrasCents * qty).round();

  OrderItem copyWith({
    double? qty,
    String? notes,
    List<ItemExtra>? extras,
    KitchenStatus? status,
    DateTime? sentAt,
    DateTime? readyAt,
    DateTime? servedAt,
    double? paidQty,
  }) => OrderItem(
    id: id,
    orderId: orderId,
    productId: productId,
    name: name,
    qty: qty ?? this.qty,
    unitCents: unitCents,
    extras: extras ?? this.extras,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt,
    sentAt: sentAt ?? this.sentAt,
    readyAt: readyAt ?? this.readyAt,
    servedAt: servedAt ?? this.servedAt,
    paidQty: paidQty ?? this.paidQty,
  );
}
