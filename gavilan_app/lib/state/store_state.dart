part of 'store.dart';

/// Estado del negocio en memoria. Cada cambio se guarda también en el teléfono
/// (Drift) a través de [StoreRepository]; al abrir la app se vuelve a cargar.
class StoreState {
  const StoreState({
    this.photos = const {},
    this.saleReturns = const [],
    this.logoPath,
    this.device,
    this.registerName,
    this.kitchenPrint = false,
    this.ticketPrint = false,
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
    this.floorItems = const [],
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

  /// Paredes, puertas, barra... del plano de mesas.
  final List<FloorItem> floorItems;

  /// Fotos de producto que ya están en este celular (por su ruta en la nube).
  final Map<String, Uint8List> photos;

  /// Bytes de la foto de un producto, si ya está aquí.
  Uint8List? photoOf(Product p) => p.photoPath == null ? null : photos[p.photoPath];

  /// Bytes de la foto de un apartado, si ya está aquí.
  Uint8List? photoOfLayaway(Layaway l) => l.photoPath == null ? null : photos[l.photoPath];

  /// Devoluciones de ventas de cortes ya cerrados (las del mismo turno rehacen la venta).
  final List<SaleReturn> saleReturns;

  List<SaleReturn> returnsOf(String saleId) => [
    for (final r in saleReturns)
      if (r.saleId == saleId) r,
  ];

  /// Cuánto ya se devolvió de cada renglón de la venta (por su clave).
  Map<String, double> returnedOf(String saleId) {
    final out = <String, double>{};
    for (final r in returnsOf(saleId)) {
      for (final l in r.lines) {
        out[l.key] = (out[l.key] ?? 0) + l.qty;
      }
    }
    return out;
  }

  /// Ruta en la nube del logo del negocio (va en la misma carpeta que las fotos). null = sin logo.
  final String? logoPath;

  /// Bytes del logo (PNG con fondo blanco), si ya está en este celular.
  Uint8List? get logo => logoPath == null ? null : photos[logoPath];

  /// Clave de este celular (la misma de los folios, "K7"). La pone el repositorio al abrir.
  final String? device;

  /// Nombre de la caja de este celular ("Mostrador"). null = se ve "Caja K7".
  final String? registerName;

  /// En la cocina de este aparato se imprime sola cada comanda nueva (solo en la computadora).
  final bool kitchenPrint;

  /// En este aparato el ticket se imprime solo al cobrar (solo en la computadora). Apagado: se imprime
  /// cuando el cliente lo pide.
  final bool ticketPrint;

  /// Cómo se llama una caja: su nombre o la clave del celular.
  static String registerLabel(String? name, String? device) =>
      name != null && name.isNotEmpty ? name : (device == null ? 'Caja' : 'Caja $device');

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
          name: (e.value..sort((a, b) => b.openedAt.compareTo(a.openedAt))).first.name,
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

  /// Lo dibujado en el plano de una zona (sin lo que se quitó).
  List<FloorItem> floorItemsIn(String? zone) => floorItems.where((f) => f.active && f.zone == zone).toList();

  FloorItem? floorItemById(String id) {
    for (final f in floorItems) {
      if (f.id == id) return f;
    }
    return null;
  }

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
      profitOf(sales.where((s) => s.sessionId == session.id && s.countsInItsCut));

  /// Ventas de un turno, la más reciente primero (las canceladas también, marcadas).
  List<Sale> salesOf(CashSession session) =>
      sales.where((s) => s.sessionId == session.id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Lo vendido en el turno por cada persona que atendió (sin las canceladas), de más a menos.
  /// Vacío si nadie tiene nombre (no se usan PIN).
  List<({String name, int count, int cents})> salesByClerk(CashSession session) {
    final totals = <String, (int, int)>{};
    var named = false;
    for (final s in sales) {
      if (s.sessionId != session.id || !s.countsInItsCut) continue;
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
    // Una venta cancelada en su mismo turno no cuenta (se le regresó el dinero ahí). Si se canceló después,
    // en otro turno, el corte de su día no cambia: la devolución quedó como gasto en el turno nuevo.
    final sessionSales = sales.where((s) => s.sessionId == session.id && s.countsInItsCut);
    var cash = 0, other = 0, onCredit = 0, count = 0, cashTips = 0, otherTips = 0;
    for (final s in sessionSales) {
      count++;
      if (s.kind == SaleKind.fiada) {
        onCredit += s.totalCents;
        continue;
      }
      // Pagada: cada parte cuenta según cómo se pagó (pago mixto o cuenta en partes). La propina sale
      // primero del efectivo (es lo común: el cliente deja el cambio) y lo demás de lo otro.
      final inCash = s.cashCents;
      final tipCash = s.tipCents.clamp(0, inCash);
      final tipOther = s.tipCents - tipCash;
      cashTips += tipCash;
      otherTips += tipOther;
      cash += inCash - tipCash;
      other += s.paidCents - inCash - tipOther;
    }
    var cashAbonos = 0, otherAbonos = 0;
    for (final e in credit.where((e) => e.sessionId == session.id && e.type == CreditType.abono)) {
      if (e.method == PayMethod.efectivo) {
        cashAbonos += e.amountCents;
      } else {
        otherAbonos += e.amountCents;
      }
    }
    var entradas = 0, gastos = 0, tipsPaid = 0;
    for (final m in movements.where((m) => m.sessionId == session.id)) {
      switch (m.kind) {
        case CashKind.entrada:
          entradas += m.amountCents;
        case CashKind.gasto:
          gastos += m.amountCents;
        case CashKind.propina:
          tipsPaid += m.amountCents;
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
      cashTipsCents: cashTips,
      otherTipsCents: otherTips,
      tipsPaidCents: tipsPaid,
    );
  }

  StoreState copyWith({
    Map<String, Uint8List>? photos,
    List<SaleReturn>? saleReturns,
    String? logoPath,
    bool clearLogo = false,
    String? device,
    String? registerName,
    bool clearRegisterName = false,
    bool? kitchenPrint,
    bool? ticketPrint,
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
    List<FloorItem>? floorItems,
    List<Extra>? extras,
    List<RestaurantOrder>? orders,
    List<OrderItem>? orderItems,
    int? nextFolio,
  }) => StoreState(
    photos: photos ?? this.photos,
    saleReturns: saleReturns ?? this.saleReturns,
    logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    device: device ?? this.device,
    registerName: clearRegisterName ? null : (registerName ?? this.registerName),
    kitchenPrint: kitchenPrint ?? this.kitchenPrint,
    ticketPrint: ticketPrint ?? this.ticketPrint,
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
    floorItems: floorItems ?? this.floorItems,
    extras: extras ?? this.extras,
    orders: orders ?? this.orders,
    orderItems: orderItems ?? this.orderItems,
    nextFolio: nextFolio ?? this.nextFolio,
  );
}
