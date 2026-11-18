import '../domain/business.dart';
import '../core/limits.dart';
import '../core/money.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/plan.dart';
import '../domain/profit.dart';
import '../domain/restaurant.dart';
import 'app_state.dart';
import 'seed.dart';
import 'sync.dart';
import '../domain/clerk.dart';
import 'clerk_session.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Clave de dos caracteres para los folios de un teléfono (sin I, O, 0 ni 1, que se confunden).
String newDeviceCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return String.fromCharCodes([for (var i = 0; i < 2; i++) alphabet.codeUnitAt(random.nextInt(alphabet.length))]);
}

/// Estado del negocio en memoria. Cada cambio se guarda también en el teléfono
/// (Drift) a través de [StoreRepository]; al abrir la app se vuelve a cargar.
class StoreState {
  const StoreState({
    this.device,
    this.defaultCreditLimitCents,
    this.clerks = const [],
    this.lockMinutes,
    this.businessType,
    this.modules,
    this.payMethods,
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
    this.tables = const [],
    this.extras = const [],
    this.orders = const [],
    this.orderItems = const [],
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
  final List<DiningTable> tables;

  /// Clave de este celular (la misma de los folios, "K7"). La pone el repositorio al abrir.
  final String? device;

  /// Tope general de fiado del negocio (null = sin tope). Cada cliente puede tener el suyo.
  final int? defaultCreditLimitCents;

  /// Tope del cliente: el suyo o, si no tiene, el general.
  int? creditLimitOf(String customerId) => customerById(customerId)?.creditLimitCents ?? defaultCreditLimitCents;

  /// Cómo quedaría la cuenta de un cliente al fiarle [extraCents] más.
  CreditCheck creditCheck(String customerId, int extraCents) =>
      CreditCheck(balanceCents: balanceOf(customerId), extraCents: extraCents, limitCents: creditLimitOf(customerId));

  /// Personas del mostrador con su PIN (solo en este aparato). Vacío = no se usan PIN.
  final List<Clerk> clerks;

  /// Minutos sin usar para bloquear y pedir el PIN otra vez (null = nunca).
  final int? lockMinutes;

  bool get usesPins => clerks.isNotEmpty;

  /// Tipo de negocio que eligió el dueño (null en negocios de antes: ven todo).
  final BusinessType? businessType;

  /// Módulos prendidos. null = todos (negocios de antes de poder elegir).
  final Set<Module>? modules;

  /// Formas de pago que acepta el negocio (efectivo siempre). null = las tres (negocios de antes).
  final Set<PayMethod>? payMethods;

  /// Formas de pago para los botones, en orden; efectivo siempre va.
  List<PayMethod> get acceptedMethods => [
    for (final m in PayMethod.values)
      if (m == PayMethod.efectivo || payMethods == null || payMethods!.contains(m)) m,
  ];

  bool uses(Module m) => modules == null || modules!.contains(m);

  /// Extras con precio del restaurante ("Extra queso" +\$10).
  final List<Extra> extras;

  List<Extra> get activeExtras => extras.where((e) => e.active).toList();
  final List<RestaurantOrder> orders;
  final List<OrderItem> orderItems;
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

  /// La caja abierta de ESTE celular (cada celular lleva su propio turno; las de otros también bajan).
  CashSession? get openSession {
    for (final s in sessions) {
      if (s.isOpen && isMine(s)) return s;
    }
    return null;
  }

  /// Las cajas de todos los celulares en [day]: los turnos que se abrieron ese día y, si es hoy, los que
  /// siguen abiertos. Este celular primero; luego los demás por lo que vendieron.
  List<DeviceCut> cutsOn(DateTime day, {DateTime? now}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final today = now ?? DateTime.now();
    final isToday = !today.isBefore(start) && today.isBefore(end);
    final byDevice = <String?, List<CashSession>>{};
    for (final s in sessions) {
      final opened = !s.openedAt.isBefore(start) && s.openedAt.isBefore(end);
      if (opened || (isToday && s.isOpen && s.openedAt.isBefore(end))) {
        byDevice.putIfAbsent(isMine(s) ? device : s.device, () => []).add(s);
      }
    }
    final cuts = [
      for (final e in byDevice.entries)
        DeviceCut(
          device: e.key,
          mine: e.key == device,
          sessions: e.value..sort((a, b) => b.openedAt.compareTo(a.openedAt)),
          summary: e.value.fold(CashSummary.zero, (a, s) => a + summaryFor(s)),
          people: {
            for (final s in e.value)
              for (final x in sales)
                if (x.sessionId == s.id && !x.cancelled && x.clerk != null) x.clerk!,
          }.toList(),
        ),
    ];
    cuts.sort((a, b) {
      if (a.mine != b.mine) return a.mine ? -1 : 1;
      return b.summary.totalSoldCents.compareTo(a.summary.totalSoldCents);
    });
    return cuts;
  }

  /// "Ventas por persona" de varios turnos juntos.
  List<({String name, int count, int cents})> salesByClerkIn(Iterable<CashSession> list) {
    final totals = <String, (int, int)>{};
    for (final s in list) {
      for (final r in salesByClerk(s)) {
        final (count, cents) = totals[r.name] ?? (0, 0);
        totals[r.name] = (count + r.count, cents + r.cents);
      }
    }
    return [for (final e in totals.entries) (name: e.key, count: e.value.$1, cents: e.value.$2)]
      ..sort((a, b) => b.cents.compareTo(a.cents));
  }

  /// Hay turnos de más de un celular (para ofrecer "Todas las cajas").
  bool get severalRegisters => {for (final s in sessions) isMine(s) ? device : s.device}.length > 1;

  /// El turno existe y sigue abierto (de cualquier celular).
  bool sessionIsOpen(String? sessionId) => sessionId != null && sessions.any((s) => s.id == sessionId && s.isOpen);

  /// Cortes cerrados de este celular, el más reciente primero.
  List<CashSession> get closedSessions =>
      sessions.where((s) => !s.isOpen && isMine(s)).toList()..sort((a, b) => b.closedAt!.compareTo(a.closedAt!));

  /// El turno es de este celular. Los de antes no dicen de qué celular son: se toman como propios si no
  /// tienen ventas de otro celular.
  bool isMine(CashSession s) {
    if (s.device != null) return device == null || s.device == device;
    return !sales.any((x) => x.sessionId == s.id && x.device != null && device != null && x.device != device);
  }

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

  // ---------- Restaurante ----------

  /// Zonas en el orden en que se crearon; las mesas sin zona van primero.
  List<String?> get zones {
    final byPosition = tables.where((t) => t.active).toList()..sort((a, b) => a.position.compareTo(b.position));
    final seen = <String?>[];
    for (final t in byPosition) {
      if (!seen.contains(t.zone)) seen.add(t.zone);
    }
    return [if (seen.contains(null)) null, ...seen.whereType<String>()];
  }

  /// Mesas activas agrupadas por zona y, dentro de cada zona, en su orden.
  List<DiningTable> get activeTables {
    final order = zones;
    return tables.where((t) => t.active).toList()..sort((a, b) {
      final z = order.indexOf(a.zone).compareTo(order.indexOf(b.zone));
      return z != 0 ? z : a.position.compareTo(b.position);
    });
  }

  List<DiningTable> tablesIn(String? zone) => activeTables.where((t) => t.zone == zone).toList();

  DiningTable? tableById(String id) => tables.where((t) => t.id == id).firstOrNull;

  RestaurantOrder? orderById(String id) => orders.where((o) => o.id == id).firstOrNull;

  List<RestaurantOrder> get openOrders =>
      orders.where((o) => o.isOpen).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  RestaurantOrder? openOrderOfTable(String tableId) => openOrders.where((o) => o.tableId == tableId).lastOrNull;

  List<OrderItem> itemsOfOrder(String orderId) => orderItems.where((i) => i.orderId == orderId).toList();

  /// Lo que falta por cobrar de la cuenta (sin lo que ya se pagó por platillos).
  int totalOfOrder(String orderId) => itemsOfOrder(orderId).fold(0, (a, i) => a + i.dueCents);

  /// Ya se cobró una parte de la cuenta por platillos.
  bool partlyPaid(String orderId) => itemsOfOrder(orderId).any((i) => i.paidQty > 0);

  /// "Mesa 4" o "Para llevar · Juan".
  String orderTitle(RestaurantOrder o) => o.takeout
      ? (o.label == null || o.label!.isEmpty ? 'Para llevar' : 'Para llevar · ${o.label}')
      : (tableById(o.tableId!)?.fullName ?? 'Mesa');

  /// Lo que cocina tiene que hacer o entregar: enviado, sin servir ni cancelar.
  List<OrderItem> kitchenItemsOf(String orderId) => itemsOfOrder(orderId)
      .where(
        (i) =>
            i.sent &&
            (i.status == KitchenStatus.pendiente ||
                i.status == KitchenStatus.preparando ||
                i.status == KitchenStatus.listo),
      )
      .toList();

  /// Comandas con algo en cocina, la que lleva más tiempo esperando primero.
  List<RestaurantOrder> get kitchenOrders {
    DateTime firstSent(RestaurantOrder o) =>
        kitchenItemsOf(o.id).map((i) => i.sentAt!).reduce((a, b) => a.isBefore(b) ? a : b);
    return orders.where((o) => o.status != OrderStatus.cancelada && kitchenItemsOf(o.id).isNotEmpty).toList()
      ..sort((a, b) => firstSent(a).compareTo(firstSent(b)));
  }

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

  /// Lo que dejó cada producto vendido en el turno: precio, costo y ganancia.
  ProfitReport profitFor(CashSession session) =>
      profitOf(sales.where((s) => s.sessionId == session.id && !s.cancelled));

  /// Ventas de un turno, la más reciente primero (las canceladas también, marcadas).
  List<Sale> salesOf(CashSession session) =>
      sales.where((s) => s.sessionId == session.id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Lo vendido en el turno por cada persona que atendió (sin las canceladas), de más a menos.
  /// Vacío si nadie tiene nombre (no se usan PIN).
  List<({String name, int count, int cents})> salesByClerk(CashSession session) {
    final totals = <String, (int, int)>{};
    var named = false;
    for (final s in sales) {
      if (s.sessionId != session.id || s.cancelled) continue;
      if (s.clerk != null) named = true;
      final key = s.clerk ?? 'Sin nombre';
      final (count, cents) = totals[key] ?? (0, 0);
      totals[key] = (count + 1, cents + s.totalCents);
    }
    if (!named) return const [];
    return [for (final e in totals.entries) (name: e.key, count: e.value.$1, cents: e.value.$2)]
      ..sort((a, b) => b.cents.compareTo(a.cents));
  }

  CashSummary summaryFor(CashSession session) {
    // Una venta cancelada no cuenta: su dinero se le regresó al cliente (o se le quitó la deuda).
    final sessionSales = sales.where((s) => s.sessionId == session.id && !s.cancelled);
    var cash = 0, other = 0, onCredit = 0, count = 0;
    for (final s in sessionSales) {
      count++;
      if (s.kind == SaleKind.fiada) {
        onCredit += s.totalCents;
        continue;
      }
      // Pagada: cada parte cuenta según cómo se pagó (pago mixto o cuenta en partes).
      final inCash = s.cashCents;
      cash += inCash;
      other += s.totalCents - inCash;
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
      switch (m.kind) {
        case CashKind.entrada:
          entradas += m.amountCents;
        case CashKind.gasto:
          gastos += m.amountCents;
        case CashKind.arqueo:
          break; // "Entregar caja" solo cuenta; no mete ni saca dinero
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
    String? device,
    int? defaultCreditLimitCents,
    bool clearCreditLimit = false,
    List<Clerk>? clerks,
    int? lockMinutes,
    bool clearLock = false,
    BusinessType? businessType,
    Set<Module>? modules,
    Set<PayMethod>? payMethods,
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
    List<DiningTable>? tables,
    List<Extra>? extras,
    List<RestaurantOrder>? orders,
    List<OrderItem>? orderItems,
    int? nextFolio,
  }) => StoreState(
    device: device ?? this.device,
    defaultCreditLimitCents: clearCreditLimit ? null : (defaultCreditLimitCents ?? this.defaultCreditLimitCents),
    clerks: clerks ?? this.clerks,
    lockMinutes: clearLock ? null : (lockMinutes ?? this.lockMinutes),
    businessType: businessType ?? this.businessType,
    modules: modules ?? this.modules,
    payMethods: payMethods ?? this.payMethods,
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
    tables: tables ?? this.tables,
    extras: extras ?? this.extras,
    orders: orders ?? this.orders,
    orderItems: orderItems ?? this.orderItems,
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
  StoreState build() => _withDevice(ref.read(initialDataProvider)?.store ?? StoreState.blank);

  /// Todo estado nuevo (alta, ejemplo, lo que bajó de la nube) sabe cuál es este celular.
  StoreState _withDevice(StoreState s) =>
      s.device == null ? s.copyWith(device: ref.read(repositoryProvider).deviceCode) : s;

  @override
  set state(StoreState value) => super.state = _withDevice(value);

  /// Guarda en orden, una escritura tras otra. Si falla se reporta sin tumbar la app.
  /// Con [urgent] se respalda casi al momento: la cocina está esperando la comanda.
  void _save(Future<void> Function(StoreRepository repo) write, {bool urgent = false}) {
    final repo = ref.read(repositoryProvider);
    _version++;
    _writes = _writes
        .then((_) => write(repo))
        .then((_) => ref.read(syncProvider.notifier).nudge(urgent: urgent))
        .catchError((Object e, StackTrace st) {
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
  void startBusiness(String name, {BusinessType type = BusinessType.otro}) {
    final fresh = StoreState.blank.copyWith(
      businessId: newId(),
      businessName: name.trim(),
      businessType: type,
      modules: type.defaultModules,
      payMethods: defaultPayMethods,
    );
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

  /// Cambia el tipo de negocio y los módulos que se ven (dueño y administradores).
  void setBusinessSetup({BusinessType? type, required Set<Module> modules}) {
    final t = type ?? state.businessType ?? BusinessType.otro;
    state = state.copyWith(businessType: t, modules: Set.unmodifiable(modules));
    _save((r) => r.setBusinessSetup(t, modules));
  }

  // ---------- Personas del mostrador (cambio de cajero con PIN) ----------

  /// Agrega o cambia a una persona (por su id).
  void saveClerk(Clerk clerk) {
    final exists = state.clerks.any((c) => c.id == clerk.id);
    state = state.copyWith(
      clerks: exists ? [for (final c in state.clerks) c.id == clerk.id ? clerk : c] : [...state.clerks, clerk],
    );
    _saveClerks();
  }

  void removeClerk(String id) {
    state = state.copyWith(
      clerks: [
        for (final c in state.clerks)
          if (c.id != id) c,
      ],
    );
    _saveClerks();
  }

  void setLockMinutes(int? minutes) {
    state = state.copyWith(lockMinutes: minutes, clearLock: minutes == null);
    _saveClerks();
  }

  /// Deja de pedir PIN en este aparato.
  void disablePins() {
    state = state.copyWith(clerks: const [], clearLock: true);
    _saveClerks();
  }

  void _saveClerks() {
    final clerks = state.clerks;
    final lock = state.lockMinutes;
    _save((r) => r.setClerks(clerks, lock));
  }

  /// Nombre de quien atiende ahora (para las ventas, gastos y abonos). null si no se usan PIN.
  String? get _clerkName {
    final id = ref.read(clerkSessionProvider).activeId;
    return id == null ? null : state.clerks.where((c) => c.id == id).firstOrNull?.name;
  }

  /// Prende o apaga un módulo.
  /// Prende o apaga una forma de pago (el efectivo no se apaga).
  void togglePayMethod(PayMethod m, bool on) {
    if (m == PayMethod.efectivo) return;
    final current = {...(state.payMethods ?? PayMethod.values.toSet())};
    on ? current.add(m) : current.remove(m);
    current.add(PayMethod.efectivo);
    state = state.copyWith(payMethods: Set.unmodifiable(current));
    _save((r) => r.setPayMethods(current));
  }

  void toggleModule(Module m, bool on) {
    final current = {...(state.modules ?? Module.values.toSet())};
    on ? current.add(m) : current.remove(m);
    setBusinessSetup(modules: current);
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

  /// Suma (o con [adjustment], corrige) la existencia de un producto.
  void addStock(String productId, double qty, {bool adjustment = false}) {
    final current = state.productById(productId);
    if (current == null || qty == 0) return;
    final updated = current.copyWith(stock: current.stock + qty);
    state = state.copyWith(products: [for (final p in state.products) p.id == productId ? updated : p]);
    _save((r) => r.addStock(updated, qty, adjustment: adjustment));
  }

  // ---------- Ventas ----------

  /// Registra la venta, descuenta inventario y, si es fiada, carga la deuda al cliente.
  Sale checkout({
    required List<SaleLine> lines,
    required SaleKind kind,
    PayMethod? method,
    int? receivedCents,
    String? customerId,
    String? orderId,
    int discountCents = 0,
    List<SalePayment> payments = const [],
  }) {
    assert(lines.isNotEmpty);
    // Un solo pago es lo mismo que pagar con ese método.
    if (payments.length == 1) {
      method = payments.single.method;
      payments = const [];
    }
    assert(kind == SaleKind.pagada || customerId != null);
    final now = _clock();
    final subtotal = lines.fold(0, (a, l) => a + l.totalCents);
    // Los pagos en partes siempre suman el total: si no cuadran, el último absorbe la diferencia.
    final total = (subtotal - discountCents.clamp(0, subtotal)).clamp(0, subtotal);
    final paidSum = payments.fold(0, (a, p) => a + p.amountCents);
    if (payments.isNotEmpty && paidSum != total) {
      final last = payments.last;
      final fixed = (last.amountCents + total - paidSum).clamp(0, total);
      payments = [
        ...payments.take(payments.length - 1),
        if (fixed > 0) SalePayment(method: last.method, amountCents: fixed),
      ];
    }
    final sale = Sale(
      id: newId(),
      folio: state.nextFolio,
      createdAt: now,
      lines: List.unmodifiable(lines),
      kind: kind,
      sessionId: state.openSession?.id,
      method: kind == SaleKind.pagada ? (payments.isNotEmpty ? null : (method ?? PayMethod.efectivo)) : null,
      payments: kind == SaleKind.pagada ? List.unmodifiable(payments) : const [],
      receivedCents: kind == SaleKind.pagada ? receivedCents : null,
      customerId: customerId,
      device: ref.read(repositoryProvider).deviceCode,
      orderId: orderId,
      discountCents: discountCents.clamp(0, subtotal),
      clerk: _clerkName,
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

  /// Cancela una venta del turno abierto: lo vendido regresa al inventario, deja de contar en la caja y,
  /// si fue fiada, se le quita esa deuda al cliente. Devuelve la venta cancelada (null si no se pudo).
  Sale? cancelSale(String saleId, {required String reason}) {
    final sale = state.sales.where((s) => s.id == saleId).firstOrNull;
    // Solo ventas de un turno abierto (de este celular o de otro: el dueño puede cancelar una del cajero).
    if (sale == null || sale.cancelled || !state.sessionIsOpen(sale.sessionId)) return null;
    final now = _now();
    final cancelled = sale.cancel(now, reason.trim().isEmpty ? 'Cancelada' : reason.trim());

    final back = <String, double>{};
    for (final l in sale.lines) {
      if (l.productId != null) back[l.productId!] = (back[l.productId!] ?? 0) + l.qty;
    }
    final restocked = [
      for (final p in state.products)
        if (p.trackStock && back.containsKey(p.id)) p.copyWith(stock: p.stock + back[p.id]!),
    ];
    final byId = {for (final p in restocked) p.id: p};
    final products = [for (final p in state.products) byId[p.id] ?? p];
    final reversal = sale.kind == SaleKind.fiada && sale.customerId != null
        ? CreditEntry(
            id: newId(),
            customerId: sale.customerId!,
            type: CreditType.cancelacion,
            amountCents: sale.totalCents,
            createdAt: now,
            saleId: sale.id,
            sessionId: sale.sessionId,
          )
        : null;
    state = state.copyWith(
      sales: [for (final s in state.sales) s.id == saleId ? cancelled : s],
      products: products,
      credit: reversal == null ? state.credit : [...state.credit, reversal],
    );
    _save((r) => r.cancelSale(sale: cancelled, restocked: restocked, reversal: reversal));
    return cancelled;
  }

  /// Devolución de una parte: [back] dice cuánto regresa de cada renglón (por posición).
  /// La venta original se cancela y se hace una nueva solo con lo que el cliente se queda, con su
  /// propio folio. Así inventario, caja y fiado cuadran solos. Devuelve la venta nueva, o null si
  /// regresó todo (entonces solo se cancela) o si no se pudo.
  Sale? returnItems(String saleId, Map<int, double> back, {required String reason}) {
    final sale = state.sales.where((s) => s.id == saleId).firstOrNull;
    final open = state.openSession;
    if (sale == null || sale.cancelled || open == null || sale.sessionId != open.id) return null;
    final kept = <SaleLine>[];
    final returned = <String>[];
    for (final (i, l) in sale.lines.indexed) {
      final r = (back[i] ?? 0).clamp(0, l.qty).toDouble();
      if (r > 0) returned.add('${qtyLabel(r)} ${l.name}');
      if (l.qty - r > 0.0001) kept.add(l.withQty(l.qty - r));
    }
    if (returned.isEmpty) return null;
    final what = returned.join(', ');
    if (kept.isEmpty) {
      cancelSale(saleId, reason: 'Devolvió todo: $reason');
      return null;
    }
    final newSubtotal = kept.fold(0, (a, l) => a + l.totalCents);
    final discount = sale.subtotalCents == 0 ? 0 : (sale.discountCents * newSubtotal / sale.subtotalCents).round();
    final device = ref.read(repositoryProvider).deviceCode;
    final nextLabel = '$device-${state.nextFolio.toString().padLeft(4, '0')}';
    cancelSale(saleId, reason: 'Devolvió $what ($reason). Queda en la venta $nextLabel');
    // Pagada en partes: lo devuelto sale primero del efectivo.
    final payments = sale.split
        ? reducePayments(sale.payments, sale.totalCents - (newSubtotal - discount))
        : const <SalePayment>[];
    return checkout(
      lines: kept,
      kind: sale.kind,
      method: sale.method,
      payments: payments,
      receivedCents: sale.kind == SaleKind.pagada ? newSubtotal - discount : null,
      customerId: sale.customerId,
      orderId: sale.orderId,
      discountCents: discount,
    );
  }

  // ---------- Clientes y fiados ----------

  Customer addCustomer(String name, {String? phone}) {
    final c = Customer(id: newId(), name: name.trim(), phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim());
    state = state.copyWith(customers: [...state.customers, c]);
    _save((r) => r.upsertCustomer(c));
    return c;
  }

  /// Tope de un cliente (null = usa el general).
  void setCustomerCreditLimit(String customerId, int? cents) {
    final c = state.customerById(customerId);
    if (c == null) return;
    final updated = c.withCreditLimit(cents?.clamp(0, Limits.maxMoneyCents));
    state = state.copyWith(customers: [for (final x in state.customers) x.id == customerId ? updated : x]);
    _save((r) => r.upsertCustomer(updated));
  }

  /// Tope general de fiado (null = sin tope).
  void setDefaultCreditLimit(int? cents) {
    final value = cents?.clamp(0, Limits.maxMoneyCents);
    state = state.copyWith(defaultCreditLimitCents: value, clearCreditLimit: value == null);
    _save((r) => r.setDefaultCreditLimit(value));
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
      clerk: _clerkName,
    );
    state = state.copyWith(credit: [...state.credit, entry]);
    _save((r) => r.insertCredit(entry));
  }

  // ---------- Caja ----------

  void openCash(int openingCents) {
    if (state.openSession != null) return;
    final session = CashSession(
      id: newId(),
      openedAt: _clock(),
      openingCents: openingCents,
      device: ref.read(repositoryProvider).deviceCode,
    );
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
      clerk: _clerkName,
    );
    state = state.copyWith(movements: [...state.movements, movement]);
    _save((r) => r.insertMovement(movement));
  }

  /// "Entregar caja": quien se va cuenta el cajón y se anota cuánto había y cuánto debía haber.
  /// No mueve el dinero de la caja. Devuelve la diferencia (positiva si sobra).
  int? handOverCash(int countedCents, {required String to}) {
    final session = state.openSession;
    if (session == null) return null;
    final expected = state.summaryFor(session).expectedCashCents;
    final diff = countedCents - expected;
    addMovement(
      CashKind.arqueo,
      countedCents,
      // Corto: el monto contado va a la derecha y quién lo entregó, abajo.
      'Entregó la caja a $to · ${diff == 0
          ? 'cuadró'
          : diff > 0
          ? 'sobraron ${money(diff)}'
          : 'faltaron ${money(-diff)}'}',
    );
    return diff;
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
