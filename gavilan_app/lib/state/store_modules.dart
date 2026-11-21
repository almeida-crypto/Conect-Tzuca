part of 'store.dart';

/// Módulos por giro: pacas y lotes, apartados y pedidos por tanda.
mixin _ModuleOps on _StoreCore {
  // ===== Módulos: pacas y lotes, apartados y pedidos por tanda =====
  // ---------- Pacas y lotes ----------

  Lot addLot(String name, int investmentCents) {
    final now = _now();
    final lot = Lot(id: newId(), name: name.trim(), investmentCents: investmentCents, startedAt: now);
    state = state.copyWith(lots: [...state.lots, lot]);
    _save((r) => r.upsertLot(lot));
    return lot;
  }

  /// Una venta de la paca. Entra en efectivo al turno de caja abierto.
  void addLotSale(String lotId, int amountCents, {String? note}) {
    final sale = LotSale(
      id: newId(),
      lotId: lotId,
      amountCents: amountCents,
      createdAt: _now(),
      note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      sessionId: state.openSession?.id,
    );
    state = state.copyWith(lotSales: [...state.lotSales, sale]);
    _save((r) => r.insertLotSale(sale));
  }

  void closeLot(String lotId) {
    final lot = state.lots.where((l) => l.id == lotId).firstOrNull;
    if (lot == null || !lot.isOpen) return;
    final closed = lot.close(_now());
    state = state.copyWith(lots: [for (final l in state.lots) l.id == lotId ? closed : l]);
    _save((r) => r.upsertLot(closed));
  }

  // ---------- Apartados ----------

  /// Nuevo apartado con su anticipo (puede ser 0). Las [items] del inventario salen de la existencia: quedan
  /// guardadas para el cliente. [useCreditCents]: cuánto de su saldo a favor (de apartados cancelados) se usa
  /// como anticipo; no entra a la caja, ese dinero ya había entrado.
  Layaway addLayaway({
    required String customerId,
    String description = '',
    required int totalCents,
    DateTime? dueDate,
    int depositCents = 0,
    PayMethod method = PayMethod.efectivo,
    Uint8List? photo,
    List<({String? productId, String name, double qty, int unitCents})> items = const [],
    int? payEveryDays,
    int useCreditCents = 0,
  }) {
    final id = newId();
    final what = description.trim().isNotEmpty
        ? description.trim()
        : [for (final i in items) i.qty == 1 ? i.name : '${qtyLabel(i.qty)} × ${i.name}'].join(', ');
    final layaway = Layaway(
      id: id,
      customerId: customerId,
      description: what.length > 200 ? '${what.substring(0, 199)}…' : what,
      totalCents: totalCents,
      createdAt: _now(),
      dueDate: dueDate,
      payEveryDays: payEveryDays,
    );
    final rows = [
      for (final (n, i) in items.indexed)
        LayawayItem(
          id: newId(),
          layawayId: id,
          productId: i.productId,
          name: i.name,
          qty: i.qty,
          unitCents: i.unitCents,
          position: n,
        ),
    ];
    final (changed, stock) = _moveStock(rows, -1);
    state = state.copyWith(
      layaways: [...state.layaways, layaway],
      layawayItems: [...state.layawayItems, ...rows],
      products: changed.isEmpty ? null : _withProducts(changed),
    );
    _save((r) => r.upsertLayaway(layaway, items: rows, changedProducts: changed, stock: stock));
    // El saldo a favor, del apartado cancelado más viejo al más nuevo.
    var credit = useCreditCents.clamp(0, state.creditOf(customerId));
    final sources = state.layaways.where((l) => l.customerId == customerId && state.creditLeftOf(l.id) > 0).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final src in sources) {
      if (credit <= 0) break;
      final use = credit.clamp(0, state.creditLeftOf(src.id));
      _addPayment(
        LayawayPayment(
          id: newId(),
          layawayId: id,
          amountCents: use,
          method: PayMethod.efectivo,
          createdAt: layaway.createdAt,
          fromLayawayId: src.id,
        ),
      );
      credit -= use;
    }
    if (depositCents > 0) addLayawayPayment(id, depositCents, method, at: layaway.createdAt);
    if (photo != null) setLayawayPhoto(id, photo);
    return state.layawayById(id)!;
  }

  /// Saca ([sign] -1) o regresa (+1) a la existencia las piezas de un apartado. Solo las que llevan existencia.
  (List<Product>, Map<String, double>) _moveStock(List<LayawayItem> items, int sign) {
    final byProduct = <String, double>{};
    for (final i in items) {
      final p = i.productId == null ? null : state.productById(i.productId!);
      if (p == null || !p.trackStock) continue;
      byProduct[p.id] = (byProduct[p.id] ?? 0) + i.qty * sign;
    }
    final changed = [
      for (final e in byProduct.entries)
        state.productById(e.key)!.copyWith(stock: state.productById(e.key)!.stock + e.value),
    ];
    return (changed, byProduct);
  }

  List<Product> _withProducts(List<Product> changed) {
    final byId = {for (final p in changed) p.id: p};
    return [for (final p in state.products) byId[p.id] ?? p];
  }

  /// Pone (o quita, con null) la foto del artículo apartado. Los bytes ya vienen chicos (600×600 JPEG).
  /// La ruta empieza con "layaway-": el cajero también puede subirla (las de producto, solo el dueño).
  void setLayawayPhoto(String layawayId, Uint8List? bytes) {
    final l = state.layawayById(layawayId);
    if (l == null) return;
    final path = bytes == null ? null : '${state.businessId}/layaway-$layawayId-${_now().millisecondsSinceEpoch}.jpg';
    final updated = l.withPhoto(path);
    state = state.copyWith(
      layaways: [for (final x in state.layaways) x.id == layawayId ? updated : x],
      photos: path == null ? null : {...state.photos, path: bytes!},
    );
    _save((r) async {
      if (path != null) await r.savePhoto(layawayId, path, bytes!);
      await r.upsertLayaway(updated);
    });
  }

  /// Abono a un apartado. Al cubrir el total queda liquidado.
  /// El anticipo lleva la misma hora que el apartado; así se reconoce.
  void addLayawayPayment(String layawayId, int amountCents, PayMethod method, {DateTime? at}) {
    _addPayment(
      LayawayPayment(
        id: newId(),
        layawayId: layawayId,
        amountCents: amountCents,
        method: method,
        createdAt: at ?? _now(),
        sessionId: state.openSession?.id,
      ),
    );
  }

  void _addPayment(LayawayPayment payment) {
    state = state.copyWith(layawayPayments: [...state.layawayPayments, payment]);
    _save((r) => r.insertLayawayPayment(payment));
    final layaway = state.layawayById(payment.layawayId);
    if (layaway != null && layaway.status == LayawayStatus.activo && state.pendingOfLayaway(layaway.id) == 0) {
      _setLayaway(layaway.withStatus(LayawayStatus.liquidado));
    }
  }

  /// El saldo a favor de [customerId] pagó [cents] de la venta [saleId] (del apartado cancelado más viejo al más
  /// nuevo). No vuelve a entrar a la caja: en el corte se descuenta lo que la venta contó como efectivo.
  void useCreditInSale(String saleId, String customerId, int cents) {
    final sale = state.sales.where((s) => s.id == saleId).firstOrNull;
    if (sale == null || cents <= 0) return;
    var left = cents.clamp(0, state.creditOf(customerId));
    final sources = state.layaways.where((l) => l.customerId == customerId && state.creditLeftOf(l.id) > 0).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final uses = <CreditUse>[];
    for (final src in sources) {
      if (left <= 0) break;
      final use = left.clamp(0, state.creditLeftOf(src.id));
      uses.add(
        CreditUse(
          id: newId(),
          layawayId: src.id,
          saleId: saleId,
          sessionId: sale.sessionId,
          amountCents: use,
          createdAt: sale.createdAt,
        ),
      );
      left -= use;
      state = state.copyWith(creditUses: [...state.creditUses, uses.last]);
    }
    if (uses.isEmpty) return;
    _save((r) => r.insertCreditUses(uses));
  }

  /// Se lo llevó: ya liquidado, sale de "por entregar".
  void deliverLayaway(String layawayId) {
    final l = state.layawayById(layawayId);
    if (l == null || l.status != LayawayStatus.liquidado || l.delivered) return;
    _setLayaway(l.copyWith(deliveredAt: _now()));
  }

  /// Cancela el apartado: las piezas regresan a la existencia. [refundCents] es lo que se le devuelve (con
  /// [refundFromCash] sale del efectivo de la caja abierta, como gasto) y [creditCents] lo que queda como saldo
  /// a favor. Lo demás de lo abonado se lo queda el negocio, según sus reglas.
  void cancelLayaway(String layawayId, {int refundCents = 0, int creditCents = 0, bool refundFromCash = false}) {
    final layaway = state.layawayById(layawayId);
    if (layaway == null || !layaway.kept) return;
    final (changed, stock) = _moveStock(state.itemsOfLayaway(layawayId), 1);
    final updated = layaway.copyWith(
      status: LayawayStatus.cancelado,
      refundCents: refundCents,
      creditCents: creditCents,
    );
    state = state.copyWith(
      layaways: [for (final l in state.layaways) l.id == layawayId ? updated : l],
      products: changed.isEmpty ? null : _withProducts(changed),
    );
    _save((r) => r.upsertLayaway(updated, changedProducts: changed, stock: stock));
    if (refundFromCash && refundCents > 0) {
      final who = state.customerById(layaway.customerId)?.name;
      addMovement(
        CashKind.gasto,
        refundCents,
        who == null ? 'Devolución de apartado' : 'Devolución de apartado · $who',
      );
    }
  }

  /// Se le mandó el recordatorio por WhatsApp: no se vuelve a sugerir en un par de días.
  void markLayawayReminded(String layawayId) {
    final l = state.layawayById(layawayId);
    if (l == null) return;
    _setLayaway(l.copyWith(remindedAt: _now()));
  }

  /// Las reglas del apartado (plazo, anticipo mínimo y qué pasa al cancelar). Las ve todo el equipo.
  void setLayawayRules(LayawayRules rules) {
    state = state.copyWith(layawayRules: rules);
    _save((r) => r.setLayawayRules(rules));
  }

  void _setLayaway(Layaway updated) {
    state = state.copyWith(layaways: [for (final l in state.layaways) l.id == updated.id ? updated : l]);
    _save((r) => r.upsertLayaway(updated));
  }

  // ---------- Compras a proveedores ----------

  Supplier addSupplier(String name, {String? phone}) {
    final supplier = Supplier(
      id: newId(),
      name: name.trim(),
      phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
    );
    state = state.copyWith(suppliers: [...state.suppliers, supplier]);
    _save((r) => r.upsertSupplier(supplier));
    return supplier;
  }

  void updateSupplier(Supplier supplier) {
    state = state.copyWith(suppliers: [for (final s in state.suppliers) s.id == supplier.id ? supplier : s]);
    _save((r) => r.upsertSupplier(supplier));
  }

  /// Llegó mercancía: entra al inventario y, con [updateCost], el costo de cada producto queda como el de esta
  /// compra (en un modelo con tallas, el de todas sus tallas). [paidCents] es lo que se pagó en el momento; lo
  /// demás queda a deber. Pagado en efectivo [fromCash] sale de la caja abierta.
  Purchase addPurchase({
    String? supplierId,
    required List<PurchaseLine> lines,
    bool updateCost = true,
    int paidCents = 0,
    PayMethod method = PayMethod.efectivo,
    bool fromCash = true,
    String? note,
  }) {
    final now = _now();
    final total = lines.fold(0, (a, l) => a + l.totalCents);
    final purchase = Purchase(
      id: newId(),
      supplierId: supplierId,
      lines: List.unmodifiable(lines),
      totalCents: total,
      note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      clerk: _clerkName,
      createdAt: now,
    );
    final stock = <String, double>{};
    final costs = <String, int>{};
    for (final l in lines) {
      final p = l.productId == null ? null : state.productById(l.productId!);
      if (p == null) continue;
      if (p.trackStock) stock[p.id] = (stock[p.id] ?? 0) + l.qty;
      if (updateCost && l.unitCostCents > 0) {
        costs[p.id] = l.unitCostCents;
        // Las tallas cuestan lo mismo que su modelo.
        if (p.parentId != null) {
          costs[p.parentId!] = l.unitCostCents;
          for (final v in state.variantsOf(p.parentId!)) {
            costs.putIfAbsent(v.id, () => l.unitCostCents);
          }
        }
      }
    }
    final changed = <Product>[
      for (final p in state.products)
        if (stock.containsKey(p.id) || costs.containsKey(p.id))
          p.copyWith(stock: p.stock + (stock[p.id] ?? 0), costCents: costs[p.id]),
    ];
    final session = state.openSession;
    final payment = paidCents > 0 && supplierId != null
        ? SupplierPayment(
            id: newId(),
            supplierId: supplierId,
            purchaseId: purchase.id,
            amountCents: paidCents.clamp(0, total),
            method: method,
            sessionId: method == PayMethod.efectivo && fromCash ? session?.id : null,
            clerk: _clerkName,
            createdAt: now,
          )
        : null;
    state = state.copyWith(
      purchases: [...state.purchases, purchase],
      products: changed.isEmpty ? null : _withProducts(changed),
      supplierPayments: payment == null ? null : [...state.supplierPayments, payment],
    );
    _save((r) => r.recordPurchase(purchase: purchase, changedProducts: changed, stock: stock, payment: payment));
    return purchase;
  }

  /// Un pago a un proveedor. En efectivo [fromCash] sale de la caja abierta.
  SupplierPayment paySupplier(
    String supplierId,
    int amountCents,
    PayMethod method, {
    bool fromCash = true,
    String? note,
  }) {
    final payment = SupplierPayment(
      id: newId(),
      supplierId: supplierId,
      amountCents: amountCents,
      method: method,
      sessionId: method == PayMethod.efectivo && fromCash ? state.openSession?.id : null,
      note: (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      clerk: _clerkName,
      createdAt: _now(),
    );
    state = state.copyWith(supplierPayments: [...state.supplierPayments, payment]);
    _save((r) => r.insertSupplierPayment(payment));
    return payment;
  }

  // ---------- Conteo de inventario ----------

  /// Lo contado de un producto ([qty] null: se quita del conteo). Se guarda en este aparato al momento.
  void setCounted(String productId, double? qty) {
    final draft = {...state.countDraft};
    if (qty == null) {
      draft.remove(productId);
    } else {
      draft[productId] = qty.clamp(0, Limits.maxQty).toDouble();
    }
    state = state.copyWith(countDraft: draft);
    _save((r) => r.setCountDraft(draft));
  }

  /// Suma una pieza contada (con el lector o el botón +1).
  void countOne(String productId) => setCounted(productId, (state.countDraft[productId] ?? 0) + 1);

  void discardCount() {
    state = state.copyWith(countDraft: const {});
    _save((r) => r.setCountDraft(const {}));
  }

  /// Aplica el conteo: la existencia de lo contado queda como se contó y se guarda qué faltó o sobró.
  /// Lo que no se contó no cambia. null si no había nada contado.
  StockCount? applyCount() {
    final lines = <CountLine>[
      for (final e in state.countDraft.entries)
        if (state.productById(e.key) case final p? when p.trackStock)
          CountLine(productId: p.id, name: p.name, system: p.stock, counted: e.value, costCents: p.costCents),
    ];
    if (lines.isEmpty) return null;
    final count = StockCount.of(id: newId(), lines: lines, at: _now(), clerk: _clerkName);
    final byId = {for (final l in lines) l.productId: l.counted};
    final changed = [
      for (final p in state.products)
        if (byId.containsKey(p.id) && byId[p.id] != p.stock) p.copyWith(stock: byId[p.id]),
    ];
    state = state.copyWith(
      stockCounts: [...state.stockCounts, count],
      products: changed.isEmpty ? null : _withProducts(changed),
      countDraft: const {},
    );
    _save((r) => r.recordCount(count: count, changedProducts: changed));
    return count;
  }

  // ---------- Pedidos por tanda ----------

  Tanda addBatch(String name, DateTime date) {
    final batch = Tanda(id: newId(), name: name.trim(), date: date, createdAt: _now());
    state = state.copyWith(batches: [...state.batches, batch]);
    _save((r) => r.upsertBatch(batch));
    return batch;
  }

  void setBatchSupplies(String batchId, int cents) {
    final batch = state.batchById(batchId);
    if (batch == null) return;
    final updated = batch.withSupplies(cents);
    state = state.copyWith(batches: [for (final b in state.batches) b.id == batchId ? updated : b]);
    _save((r) => r.upsertBatch(updated));
  }

  BatchOrder addBatchOrder({
    required String batchId,
    required String customerName,
    required int totalCents,
    String? phone,
    String? detail,
  }) {
    final order = BatchOrder(
      id: newId(),
      batchId: batchId,
      customerName: customerName.trim(),
      phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
      detail: (detail?.trim().isEmpty ?? true) ? null : detail!.trim(),
      totalCents: totalCents,
      createdAt: _now(),
    );
    state = state.copyWith(batchOrders: [...state.batchOrders, order]);
    _save((r) => r.upsertBatchOrder(order));
    return order;
  }

  void updateBatchOrder(BatchOrder order) {
    state = state.copyWith(batchOrders: [for (final o in state.batchOrders) o.id == order.id ? order : o]);
    _save((r) => r.upsertBatchOrder(order));
  }
}
