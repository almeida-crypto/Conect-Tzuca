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

  /// Nuevo apartado con su anticipo (puede ser 0).
  Layaway addLayaway({
    required String customerId,
    required String description,
    required int totalCents,
    DateTime? dueDate,
    int depositCents = 0,
    PayMethod method = PayMethod.efectivo,
  }) {
    final layaway = Layaway(
      id: newId(),
      customerId: customerId,
      description: description.trim(),
      totalCents: totalCents,
      createdAt: _now(),
      dueDate: dueDate,
    );
    state = state.copyWith(layaways: [...state.layaways, layaway]);
    _save((r) => r.upsertLayaway(layaway));
    if (depositCents > 0) addLayawayPayment(layaway.id, depositCents, method, at: layaway.createdAt);
    return state.layawayById(layaway.id)!;
  }

  /// Abono a un apartado. Al cubrir el total queda liquidado.
  /// El anticipo lleva la misma hora que el apartado; así se reconoce.
  void addLayawayPayment(String layawayId, int amountCents, PayMethod method, {DateTime? at}) {
    final payment = LayawayPayment(
      id: newId(),
      layawayId: layawayId,
      amountCents: amountCents,
      method: method,
      createdAt: at ?? _now(),
      sessionId: state.openSession?.id,
    );
    state = state.copyWith(layawayPayments: [...state.layawayPayments, payment]);
    _save((r) => r.insertLayawayPayment(payment));
    final layaway = state.layawayById(layawayId);
    if (layaway != null && layaway.status == LayawayStatus.activo && state.pendingOfLayaway(layawayId) == 0) {
      _setLayaway(layaway.withStatus(LayawayStatus.liquidado));
    }
  }

  void cancelLayaway(String layawayId) {
    final layaway = state.layawayById(layawayId);
    if (layaway == null) return;
    _setLayaway(layaway.withStatus(LayawayStatus.cancelado));
  }

  void _setLayaway(Layaway updated) {
    state = state.copyWith(layaways: [for (final l in state.layaways) l.id == updated.id ? updated : l]);
    _save((r) => r.upsertLayaway(updated));
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
