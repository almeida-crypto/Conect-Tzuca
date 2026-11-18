part of 'store.dart';

/// Mesas, cuentas, cocina y extras con precio.
mixin _RestaurantOps on _StoreCore {
  // ---------- Restaurante ----------

  /// Agrega mesas numeradas después de las que ya hay ("Mesa 5", "Mesa 6"...).
  /// Cada zona lleva su propia numeración: "Mesa 1" en planta baja y "Mesa 1" en la terraza.
  void addTables(int count, {String? zone}) {
    final where = zone?.trim().isEmpty ?? true ? null : zone!.trim();
    // Sigue después del número más alto que se vea en la zona, aunque se hayan quitado mesas.
    final last = state
        .tablesIn(where)
        .map((t) => int.tryParse(RegExp(r'^Mesa (\d+)$').firstMatch(t.name)?.group(1) ?? '') ?? 0)
        .fold(0, (a, n) => n > a ? n : a);
    var position = state.tables.fold(0, (a, t) => t.position > a ? t.position : a);
    final created = [
      for (var i = 1; i <= count; i++)
        DiningTable(id: newId(), name: 'Mesa ${last + i}', position: ++position, zone: where),
    ];
    state = state.copyWith(tables: [...state.tables, ...created]);
    for (final t in created) {
      _save((r) => r.upsertTable(t));
    }
  }

  void renameTable(String id, String name) => _setTable(state.tableById(id)?.copyWith(name: name.trim()));

  /// Cambia la mesa de zona (vacío = sin zona).
  void moveTable(String id, String? zone) {
    final where = zone?.trim().isEmpty ?? true ? null : zone!.trim();
    _setTable(state.tableById(id)?.copyWith(zone: where, clearZone: where == null));
  }

  /// Quita la mesa de la pantalla. Las comandas que tuvo se quedan.
  void removeTable(String id) => _setTable(state.tableById(id)?.copyWith(active: false));

  void _setTable(DiningTable? table) {
    if (table == null) return;
    state = state.copyWith(tables: [for (final t in state.tables) t.id == table.id ? table : t]);
    _save((r) => r.upsertTable(table));
  }

  /// Abre la cuenta de una mesa (o un pedido para llevar si no hay mesa).
  RestaurantOrder openOrder({String? tableId, String? label}) {
    if (tableId != null) {
      final existing = state.openOrderOfTable(tableId);
      if (existing != null) return existing;
    }
    final order = RestaurantOrder(
      id: newId(),
      tableId: tableId,
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      createdAt: _now(),
    );
    state = state.copyWith(orders: [...state.orders, order]);
    _save((r) => r.upsertOrder(order), urgent: true);
    return order;
  }

  /// Suma un platillo a la comanda. Si ya hay uno igual (mismas notas y extras) sin mandar a cocina,
  /// sube la cantidad.
  OrderItem addOrderItem(String orderId, Product product, {String? notes, List<ItemExtra> extras = const []}) {
    final note = notes?.trim().isEmpty ?? true ? null : notes!.trim();
    final same = state
        .itemsOfOrder(orderId)
        .where(
          (i) =>
              !i.sent && !i.cancelled && i.productId == product.id && i.notes == note && _sameExtras(i.extras, extras),
        )
        .firstOrNull;
    final item =
        same?.copyWith(qty: same.qty + 1) ??
        OrderItem(
          id: newId(),
          orderId: orderId,
          productId: product.id,
          name: product.name,
          qty: 1,
          unitCents: product.priceCents,
          extras: List.unmodifiable(extras),
          notes: note,
          createdAt: _now(),
        );
    _setItems([item]);
    return item;
  }

  static bool _sameExtras(List<ItemExtra> a, List<ItemExtra> b) =>
      a.length == b.length && a.every(b.contains) && b.every(a.contains);

  /// Indicaciones y extras de un platillo que aún no se manda a cocina.
  void setItemDetails(String itemId, {required String notes, required List<ItemExtra> extras}) {
    final item = state.orderItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.sent) return;
    _setItems([
      OrderItem(
        id: item.id,
        orderId: item.orderId,
        productId: item.productId,
        name: item.name,
        qty: item.qty,
        unitCents: item.unitCents,
        extras: List.unmodifiable(extras),
        notes: notes.trim().isEmpty ? null : notes.trim(),
        createdAt: item.createdAt,
      ),
    ]);
  }

  // ---------- Extras con precio ----------

  /// Da de alta o cambia un extra. Devuelve el extra guardado.
  Extra saveExtra({String? id, required String name, required int priceCents}) {
    final existing = id == null ? null : state.extras.where((e) => e.id == id).firstOrNull;
    final extra =
        existing?.copyWith(name: name.trim(), priceCents: priceCents) ??
        Extra(id: newId(), name: name.trim(), priceCents: priceCents, position: state.extras.length);
    state = state.copyWith(
      extras: existing == null
          ? [...state.extras, extra]
          : [for (final e in state.extras) e.id == extra.id ? extra : e],
    );
    _save((r) => r.upsertExtra(extra));
    return extra;
  }

  /// Quita un extra de la lista (las comandas que ya lo traen no cambian).
  void removeExtra(String id) {
    final existing = state.extras.where((e) => e.id == id).firstOrNull;
    if (existing == null) return;
    final off = existing.copyWith(active: false);
    state = state.copyWith(extras: [for (final e in state.extras) e.id == id ? off : e]);
    _save((r) => r.upsertExtra(off));
  }

  /// Cambia la cantidad de un platillo que aún no se manda. En cero se cancela.
  void setItemQty(String itemId, double qty) {
    final item = state.orderItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.sent) return;
    // Lo que ya se pagó por platillos no se quita.
    if (qty < item.paidQty - 0.0001) return;
    _setItems([qty <= 0 ? item.copyWith(status: KitchenStatus.cancelado) : item.copyWith(qty: qty)]);
  }

  void setItemNotes(String itemId, String notes) {
    final item = state.orderItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    setItemDetails(itemId, notes: notes, extras: item.extras);
  }

  /// Manda a cocina lo que el mesero ya anotó. Devuelve cuántos platillos salieron.
  int sendToKitchen(String orderId) {
    final now = _now();
    final pending = [
      for (final i in state.itemsOfOrder(orderId))
        if (!i.sent && !i.cancelled) i.copyWith(sentAt: now),
    ];
    if (pending.isNotEmpty) _setItems(pending);
    return pending.length;
  }

  /// Cocina avanza un platillo; el mesero lo marca servido.
  void setItemStatus(String itemId, KitchenStatus status) {
    final item = state.orderItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    final now = _now();
    _setItems([
      item.copyWith(
        status: status,
        readyAt: status == KitchenStatus.listo ? now : null,
        servedAt: status == KitchenStatus.servido ? now : null,
      ),
    ]);
  }

  /// Todo lo de una comanda que sigue en cocina, listo de una vez.
  void markOrderReady(String orderId) {
    final now = _now();
    final items = [
      for (final i in state.kitchenItemsOf(orderId))
        if (i.status != KitchenStatus.listo) i.copyWith(status: KitchenStatus.listo, readyAt: now),
    ];
    if (items.isNotEmpty) _setItems(items);
  }

  void _setItems(List<OrderItem> items) {
    final byId = {for (final i in items) i.id: i};
    final known = state.orderItems.map((i) => i.id).toSet();
    state = state.copyWith(
      orderItems: [
        for (final i in state.orderItems) byId[i.id] ?? i,
        for (final i in items)
          if (!known.contains(i.id)) i,
      ],
    );
    _save((r) => r.upsertOrderItems(items), urgent: true);
  }

  /// Cancela la cuenta completa (se fueron sin pedir, se equivocaron de mesa).
  void cancelOrder(String orderId) {
    final order = state.orderById(orderId);
    if (order == null || !order.isOpen) return;
    // Si ya se pagó una parte por platillos, eso se queda: solo se quita lo que faltaba y la cuenta se cierra.
    final paidSome = state.partlyPaid(orderId);
    final items = [
      for (final i in state.itemsOfOrder(orderId))
        if (!i.cancelled && !i.fullyPaid)
          if (i.paidQty > 0)
            i.copyWith(qty: i.paidQty)
          else if (i.status != KitchenStatus.servido)
            i.copyWith(status: KitchenStatus.cancelado),
    ];
    if (items.isNotEmpty) _setItems(items);
    _closeOrder(order.close(paidSome ? OrderStatus.cerrada : OrderStatus.cancelada, _now()));
  }

  /// Cobra la cuenta: se vuelve una venta normal (corte, fiado, ticket) y la mesa queda libre.
  Sale chargeOrder(
    String orderId, {
    required SaleKind kind,
    PayMethod? method,
    int? receivedCents,
    String? customerId,
    int discountCents = 0,
    List<SalePayment> payments = const [],
  }) {
    final order = state.orderById(orderId)!;
    // Lo que falta por cobrar (si ya se pagó una parte por platillos, solo lo demás).
    final lines = [
      for (final i in state.itemsOfOrder(orderId))
        if (!i.cancelled && !i.fullyPaid) _lineOf(i, i.dueQty),
    ];
    final sale = checkout(
      lines: lines,
      kind: kind,
      method: method,
      receivedCents: receivedCents,
      customerId: customerId,
      orderId: orderId,
      discountCents: discountCents,
      payments: payments,
    );
    _closeOrder(order.close(OrderStatus.cerrada, _now()));
    return sale;
  }

  /// Renglón de venta de un platillo de la cuenta. Con extras: "Tacos de pastor (extra queso)" y el precio de
  /// la pieza ya con ellos. El costo se toma al cobrar (quien cobra sí lo tiene), para que la ganancia cuente.
  SaleLine _lineOf(OrderItem i, double qty) => SaleLine(
    key: i.id,
    productId: i.productId,
    name: i.fullName,
    unitCents: i.unitWithExtrasCents,
    qty: qty,
    unitCostCents: i.productId == null ? 0 : (state.productById(i.productId!)?.costCents ?? 0),
  );

  /// Cobra solo unos platillos de la cuenta ([qtyByItem]: cuántas piezas de cada uno). La cuenta sigue
  /// abierta con lo demás; si ya no queda nada por cobrar, se cierra y la mesa queda libre.
  Sale? chargeOrderItems(
    String orderId,
    Map<String, double> qtyByItem, {
    required SaleKind kind,
    PayMethod? method,
    int? receivedCents,
    String? customerId,
    int discountCents = 0,
    List<SalePayment> payments = const [],
  }) {
    final order = state.orderById(orderId);
    if (order == null || !order.isOpen) return null;
    final paid = <OrderItem>[];
    final lines = <SaleLine>[];
    for (final i in state.itemsOfOrder(orderId)) {
      final want = (qtyByItem[i.id] ?? 0).clamp(0, i.dueQty).toDouble();
      if (want <= 0) continue;
      lines.add(_lineOf(i, want));
      paid.add(i.copyWith(paidQty: i.paidQty + want));
    }
    if (lines.isEmpty) return null;
    final sale = checkout(
      lines: lines,
      kind: kind,
      method: method,
      receivedCents: receivedCents,
      customerId: customerId,
      orderId: orderId,
      discountCents: discountCents,
      payments: payments,
    );
    _setItems(paid);
    final left = state.itemsOfOrder(orderId).where((i) => !i.cancelled && !i.fullyPaid);
    if (left.isEmpty) _closeOrder(order.close(OrderStatus.cerrada, _now()));
    return sale;
  }

  /// Pasa una cuenta abierta a otra mesa libre. Falso si la mesa ya tiene cuenta o no existe.
  bool moveOrder(String orderId, String tableId) {
    final order = state.orderById(orderId);
    final table = state.tableById(tableId);
    if (order == null || !order.isOpen || table == null || !table.active) return false;
    if (state.openOrderOfTable(tableId) != null) return false;
    _closeOrder(order.moveTo(tableId));
    return true;
  }

  void _closeOrder(RestaurantOrder order) {
    state = state.copyWith(orders: [for (final o in state.orders) o.id == order.id ? order : o]);
    _save((r) => r.upsertOrder(order), urgent: true);
  }
}
