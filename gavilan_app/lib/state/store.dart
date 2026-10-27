import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'seed.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Estado local del negocio. Hoy vive en memoria con datos de ejemplo;
/// el siguiente paso es guardarlo en Drift (offline) y sincronizar con Supabase.
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
  });

  final String businessName;
  final List<Product> products;
  final List<Sale> sales;
  final List<Customer> customers;
  final List<CreditEntry> credit;
  final List<CashSession> sessions;
  final List<CashMovement> movements;
  final int nextFolio;

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
    return CashSummary(
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
    List<Product>? products,
    List<Sale>? sales,
    List<Customer>? customers,
    List<CreditEntry>? credit,
    List<CashSession>? sessions,
    List<CashMovement>? movements,
    int? nextFolio,
  }) => StoreState(
    businessName: businessName,
    products: products ?? this.products,
    sales: sales ?? this.sales,
    customers: customers ?? this.customers,
    credit: credit ?? this.credit,
    sessions: sessions ?? this.sessions,
    movements: movements ?? this.movements,
    nextFolio: nextFolio ?? this.nextFolio,
  );
}

class StoreNotifier extends Notifier<StoreState> {
  StoreNotifier({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  StoreState build() => seedStore(_clock());

  // ---------- Productos ----------

  void saveProduct(Product product) {
    final exists = state.products.any((p) => p.id == product.id);
    state = state.copyWith(
      products: exists
          ? [for (final p in state.products) p.id == product.id ? product : p]
          : [...state.products, product],
    );
  }

  void addStock(String productId, double qty) {
    state = state.copyWith(
      products: [for (final p in state.products) p.id == productId ? p.copyWith(stock: p.stock + qty) : p],
    );
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
    state = state.copyWith(
      sales: [...state.sales, sale],
      nextFolio: state.nextFolio + 1,
      products: [
        for (final p in state.products)
          (p.trackStock && sold.containsKey(p.id)) ? p.copyWith(stock: p.stock - sold[p.id]!) : p,
      ],
      credit: kind == SaleKind.fiada
          ? [
              ...state.credit,
              CreditEntry(
                id: newId(),
                customerId: customerId!,
                type: CreditType.cargo,
                amountCents: sale.totalCents,
                createdAt: now,
                saleId: sale.id,
              ),
            ]
          : state.credit,
    );
    return sale;
  }

  // ---------- Clientes y fiados ----------

  Customer addCustomer(String name, {String? phone}) {
    final c = Customer(id: newId(), name: name.trim(), phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim());
    state = state.copyWith(customers: [...state.customers, c]);
    return c;
  }

  void addAbono(String customerId, int amountCents, PayMethod method) {
    state = state.copyWith(
      credit: [
        ...state.credit,
        CreditEntry(
          id: newId(),
          customerId: customerId,
          type: CreditType.abono,
          amountCents: amountCents,
          createdAt: _clock(),
          method: method,
          sessionId: state.openSession?.id,
        ),
      ],
    );
  }

  // ---------- Caja ----------

  void openCash(int openingCents) {
    if (state.openSession != null) return;
    state = state.copyWith(
      sessions: [
        ...state.sessions,
        CashSession(id: newId(), openedAt: _clock(), openingCents: openingCents),
      ],
    );
  }

  void addMovement(CashKind kind, int amountCents, String concept) {
    final session = state.openSession;
    if (session == null) return;
    state = state.copyWith(
      movements: [
        ...state.movements,
        CashMovement(
          id: newId(),
          sessionId: session.id,
          kind: kind,
          amountCents: amountCents,
          concept: concept.trim(),
          createdAt: _clock(),
        ),
      ],
    );
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
    return closed;
  }
}

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);
