import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/plan.dart';
import 'app_state.dart';
import 'seed.dart';
import 'sync.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Estado del negocio en memoria. Cada cambio se guarda también en el teléfono
/// (Drift) a través de [StoreRepository]; al abrir la app se vuelve a cargar.
class StoreState {
  const StoreState({
    required this.businessName,
    required this.products,
    required this.sales,
    required this.customers,
    required this.credit,
    required this.sessions,
    required this.movements,
    required this.nextFolio,
    this.businessId = '',
    this.isDemo = false,
    this.lots = const [],
    this.lotSales = const [],
    this.layaways = const [],
    this.layawayPayments = const [],
    this.batches = const [],
    this.batchOrders = const [],
  });

  /// Id del negocio; es el mismo en el teléfono y en Supabase.
  final String businessId;

  /// La tiendita de ejemplo nunca se sube a la nube.
  final bool isDemo;
  final String businessName;
  final List<Product> products;
  final List<Sale> sales;
  final List<Customer> customers;
  final List<CreditEntry> credit;
  final List<CashSession> sessions;
  final List<CashMovement> movements;
  final List<Lot> lots;
  final List<LotSale> lotSales;
  final List<Layaway> layaways;
  final List<LayawayPayment> layawayPayments;
  final List<Tanda> batches;
  final List<BatchOrder> batchOrders;
  final int nextFolio;

  /// Sin negocio todavía (primer arranque o después de borrar todo).
  static const blank = StoreState(
    businessName: '',
    products: [],
    sales: [],
    customers: [],
    credit: [],
    sessions: [],
    movements: [],
    nextFolio: 1,
  );

  bool get hasBusiness => businessName.isNotEmpty;

  CashSession? get openSession {
    for (final s in sessions) {
      if (s.isOpen) return s;
    }
    return null;
  }

  List<CashSession> get closedSessions =>
      sessions.where((s) => !s.isOpen).toList()..sort((a, b) => b.closedAt!.compareTo(a.closedAt!));

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Product? productByBarcode(String code) {
    for (final p in products) {
      if (p.active && p.barcode == code) return p;
    }
    return null;
  }

  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Product> get activeProducts => products.where((p) => p.active).toList();

  int balanceOf(String customerId) => credit
      .where((e) => e.customerId == customerId)
      .fold(0, (a, e) => a + (e.type == CreditType.cargo ? e.amountCents : -e.amountCents));

  /// Clientes con deuda, los más atrasados primero.
  List<Debtor> get debtors {
    final list = <Debtor>[];
    for (final c in customers) {
      final entries = credit.where((e) => e.customerId == c.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final balance = balanceOf(c.id);
      if (balance <= 0) continue;
      final abonos = entries.where((e) => e.type == CreditType.abono);
      final cargos = entries.where((e) => e.type == CreditType.cargo);
      final since = abonos.isNotEmpty ? abonos.first.createdAt : cargos.last.createdAt;
      list.add(Debtor(customer: c, balanceCents: balance, since: since, entries: entries));
    }
    list.sort((a, b) => a.since.compareTo(b.since));
    return list;
  }

  int get totalOnCreditCents => debtors.fold(0, (a, d) => a + d.balanceCents);

  // ---------- Pacas y lotes ----------

  List<Lot> get openLots => lots.where((l) => l.isOpen).toList();

  List<LotSale> salesOfLot(String lotId) =>
      lotSales.where((s) => s.lotId == lotId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int recoveredOfLot(String lotId) => lotSales.where((s) => s.lotId == lotId).fold(0, (a, s) => a + s.amountCents);

  // ---------- Apartados ----------

  Layaway? layawayById(String id) {
    for (final l in layaways) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<LayawayPayment> paymentsOfLayaway(String id) =>
      layawayPayments.where((p) => p.layawayId == id).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int paidOfLayaway(String id) => layawayPayments.where((p) => p.layawayId == id).fold(0, (a, p) => a + p.amountCents);

  int pendingOfLayaway(String id) {
    final l = layawayById(id);
    return l == null ? 0 : (l.totalCents - paidOfLayaway(id)).clamp(0, l.totalCents);
  }

  // ---------- Pedidos por tanda ----------

  Tanda? batchById(String id) {
    for (final b in batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<BatchOrder> ordersOfBatch(String batchId) =>
      batchOrders.where((o) => o.batchId == batchId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  CashSummary summaryFor(CashSession session) {
    final sessionSales = sales.where((s) => s.sessionId == session.id);
    var cash = 0, other = 0, onCredit = 0, count = 0;
    for (final s in sessionSales) {
      count++;
      if (s.kind == SaleKind.fiada) {
        onCredit += s.totalCents;
      } else if (s.method == PayMethod.efectivo) {
        cash += s.totalCents;
      } else {
        other += s.totalCents;
      }
    }
    var cashAbonos = 0, otherAbonos = 0;
    for (final e in credit.where((e) => e.sessionId == session.id && e.type == CreditType.abono)) {
      if (e.method == PayMethod.efectivo) {
        cashAbonos += e.amountCents;
      } else {
        otherAbonos += e.amountCents;
      }
    }
    var entradas = 0, gastos = 0;
    for (final m in movements.where((m) => m.sessionId == session.id)) {
      if (m.kind == CashKind.entrada) {
        entradas += m.amountCents;
      } else {
        gastos += m.amountCents;
      }
    }
    var lotCash = 0;
    for (final s in lotSales.where((s) => s.sessionId == session.id)) {
      lotCash += s.amountCents;
    }
    var layawayCash = 0, layawayOther = 0;
    for (final p in layawayPayments.where((p) => p.sessionId == session.id)) {
      if (p.method == PayMethod.efectivo) {
        layawayCash += p.amountCents;
      } else {
        layawayOther += p.amountCents;
      }
    }
    return CashSummary(
      lotSalesCents: lotCash,
      cashLayawayCents: layawayCash,
      otherLayawayCents: layawayOther,
      openingCents: session.openingCents,
      cashSalesCents: cash,
      otherSalesCents: other,
      creditSalesCents: onCredit,
      cashAbonosCents: cashAbonos,
      otherAbonosCents: otherAbonos,
      entradasCents: entradas,
      gastosCents: gastos,
      salesCount: count,
    );
  }

  StoreState copyWith({
    String? businessId,
    bool? isDemo,
    String? businessName,
    List<Product>? products,
    List<Sale>? sales,
    List<Customer>? customers,
    List<CreditEntry>? credit,
    List<CashSession>? sessions,
    List<CashMovement>? movements,
    List<Lot>? lots,
    List<LotSale>? lotSales,
    List<Layaway>? layaways,
    List<LayawayPayment>? layawayPayments,
    List<Tanda>? batches,
    List<BatchOrder>? batchOrders,
    int? nextFolio,
  }) => StoreState(
    businessId: businessId ?? this.businessId,
    isDemo: isDemo ?? this.isDemo,
    businessName: businessName ?? this.businessName,
    products: products ?? this.products,
    sales: sales ?? this.sales,
    customers: customers ?? this.customers,
    credit: credit ?? this.credit,
    sessions: sessions ?? this.sessions,
    movements: movements ?? this.movements,
    lots: lots ?? this.lots,
    lotSales: lotSales ?? this.lotSales,
    layaways: layaways ?? this.layaways,
    layawayPayments: layawayPayments ?? this.layawayPayments,
    batches: batches ?? this.batches,
    batchOrders: batchOrders ?? this.batchOrders,
    nextFolio: nextFolio ?? this.nextFolio,
  );
}

/// Dónde se guardan los cambios. main() lo cambia por Drift en el teléfono.
final repositoryProvider = Provider<StoreRepository>((ref) => MemoryRepository());

/// Lo que se cargó del teléfono al abrir la app (null = primer arranque).
final initialDataProvider = Provider<LoadedData?>((ref) => null);

class StoreNotifier extends Notifier<StoreState> {
  StoreNotifier({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  Future<void> _writes = Future.value();
  int _version = 0;

  @override
  StoreState build() => ref.read(initialDataProvider)?.store ?? StoreState.blank;

  /// Guarda en orden, una escritura tras otra. Si falla se reporta sin tumbar la app.
  void _save(Future<void> Function(StoreRepository repo) write) {
    final repo = ref.read(repositoryProvider);
    _version++;
    _writes = _writes.then((_) => write(repo)).then((_) => ref.read(syncProvider.notifier).nudge()).catchError((
      Object e,
      StackTrace st,
    ) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'gavilan',
          context: ErrorDescription('al guardar en el teléfono'),
        ),
      );
    });
  }

  DateTime _now() => _clock();

  /// Espera a que todo quede guardado.
  Future<void> flush() => _writes;

  /// Vuelve a leer todo del teléfono (después de bajar cambios de la nube).
  /// Si mientras tanto hubo un cambio local, lee otra vez para no perderlo.
  Future<void> reloadFromStorage() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await flush();
      final version = _version;
      final loaded = await ref.read(repositoryProvider).load();
      if (version == _version) {
        state = loaded?.store ?? StoreState.blank;
        return;
      }
    }
  }

  // ---------- Negocio ----------

  /// Alta de un negocio nuevo, vacío.
  void startBusiness(String name) {
    final fresh = StoreState.blank.copyWith(businessId: newId(), businessName: name.trim());
    state = fresh;
    final plan = ref.read(planProvider);
    _save((r) => r.replaceAll(fresh, plan));
  }

  /// Carga la tiendita de ejemplo para conocer la app.
  void loadDemo() {
    final demo = seedStore(_clock());
    state = demo;
    final plan = ref.read(planProvider);
    _save((r) => r.replaceAll(demo, plan));
  }

  /// Guarda el plan en la misma fila de escrituras, para que no lo pise un alta posterior.
  void savePlan(Plan plan) => _save((r) => r.setPlan(plan));

  /// Borra todo lo guardado en este teléfono y vuelve al primer arranque.
  void resetAll() {
    state = StoreState.blank;
    _save((r) => r.clear());
  }

  // ---------- Productos ----------

  void saveProduct(Product product) {
    final isNew = !state.products.any((p) => p.id == product.id);
    state = state.copyWith(
      products: isNew
          ? [...state.products, product]
          : [for (final p in state.products) p.id == product.id ? product : p],
    );
    _save((r) => r.upsertProduct(product, isNew: isNew));
  }

  void addStock(String productId, double qty) {
    final current = state.productById(productId);
    if (current == null) return;
    final updated = current.copyWith(stock: current.stock + qty);
    state = state.copyWith(products: [for (final p in state.products) p.id == productId ? updated : p]);
    _save((r) => r.addStock(updated, qty));
  }

  // ---------- Ventas ----------

  /// Registra la venta, descuenta inventario y, si es fiada, carga la deuda al cliente.
  Sale checkout({
    required List<SaleLine> lines,
    required SaleKind kind,
    PayMethod? method,
    int? receivedCents,
    String? customerId,
  }) {
    assert(lines.isNotEmpty);
    assert(kind == SaleKind.pagada || customerId != null);
    final now = _clock();
    final sale = Sale(
      id: newId(),
      folio: state.nextFolio,
      createdAt: now,
      lines: List.unmodifiable(lines),
      kind: kind,
      sessionId: state.openSession?.id,
      method: kind == SaleKind.pagada ? (method ?? PayMethod.efectivo) : null,
      receivedCents: kind == SaleKind.pagada ? receivedCents : null,
      customerId: customerId,
    );
    final sold = <String, double>{};
    for (final l in lines) {
      if (l.productId != null) sold[l.productId!] = (sold[l.productId!] ?? 0) + l.qty;
    }
    final changed = <Product>[];
    final products = <Product>[];
    for (final p in state.products) {
      if (p.trackStock && sold.containsKey(p.id)) {
        final updated = p.copyWith(stock: p.stock - sold[p.id]!);
        changed.add(updated);
        products.add(updated);
      } else {
        products.add(p);
      }
    }
    final charge = kind == SaleKind.fiada
        ? CreditEntry(
            id: newId(),
            customerId: customerId!,
            type: CreditType.cargo,
            amountCents: sale.totalCents,
            createdAt: now,
            saleId: sale.id,
          )
        : null;
    final nextFolio = state.nextFolio + 1;
    state = state.copyWith(
      sales: [...state.sales, sale],
      nextFolio: nextFolio,
      products: products,
      credit: charge == null ? state.credit : [...state.credit, charge],
    );
    _save((r) => r.recordSale(sale: sale, changedProducts: changed, charge: charge, nextFolio: nextFolio));
    return sale;
  }

  // ---------- Clientes y fiados ----------

  Customer addCustomer(String name, {String? phone}) {
    final c = Customer(id: newId(), name: name.trim(), phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim());
    state = state.copyWith(customers: [...state.customers, c]);
    _save((r) => r.upsertCustomer(c));
    return c;
  }

  void addAbono(String customerId, int amountCents, PayMethod method) {
    final entry = CreditEntry(
      id: newId(),
      customerId: customerId,
      type: CreditType.abono,
      amountCents: amountCents,
      createdAt: _clock(),
      method: method,
      sessionId: state.openSession?.id,
    );
    state = state.copyWith(credit: [...state.credit, entry]);
    _save((r) => r.insertCredit(entry));
  }

  // ---------- Caja ----------

  void openCash(int openingCents) {
    if (state.openSession != null) return;
    final session = CashSession(id: newId(), openedAt: _clock(), openingCents: openingCents);
    state = state.copyWith(sessions: [...state.sessions, session]);
    _save((r) => r.upsertSession(session));
  }

  void addMovement(CashKind kind, int amountCents, String concept) {
    final session = state.openSession;
    if (session == null) return;
    final movement = CashMovement(
      id: newId(),
      sessionId: session.id,
      kind: kind,
      amountCents: amountCents,
      concept: concept.trim(),
      createdAt: _clock(),
    );
    state = state.copyWith(movements: [...state.movements, movement]);
    _save((r) => r.insertMovement(movement));
  }

  CashSession? closeCash(int countedCents) {
    final session = state.openSession;
    if (session == null) return null;
    final closed = session.close(
      at: _clock(),
      expected: state.summaryFor(session).expectedCashCents,
      counted: countedCents,
    );
    state = state.copyWith(sessions: [for (final s in state.sessions) s.id == session.id ? closed : s]);
    _save((r) => r.upsertSession(closed));
    return closed;
  }

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

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);
