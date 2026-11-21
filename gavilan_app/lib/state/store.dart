import '../domain/business.dart';
import '../core/labels.dart';
import '../core/limits.dart';
import '../core/money.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../domain/layaway_rules.dart';
import '../domain/models.dart';
import '../domain/variants.dart';
import '../domain/plan.dart';
import '../domain/profit.dart';
import '../domain/purchases.dart';
import '../domain/floor_layout.dart';
import '../domain/restaurant.dart';
import 'app_state.dart';
import 'seed.dart';
import 'sync.dart';
import '../domain/clerk.dart';
import 'clerk_session.dart';

part 'store_state.dart';
part 'store_restaurant.dart';
part 'store_modules.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Clave de dos caracteres para los folios de un teléfono (sin I, O, 0 ni 1, que se confunden).
String newDeviceCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return String.fromCharCodes([for (var i = 0; i < 2; i++) alphabet.codeUnitAt(random.nextInt(alphabet.length))]);
}

/// Dónde se guardan los cambios. main() lo cambia por Drift en el teléfono.
final repositoryProvider = Provider<StoreRepository>((ref) => MemoryRepository());

/// Lo que se cargó del teléfono al abrir la app (null = primer arranque).
final initialDataProvider = Provider<LoadedData?>((ref) => null);

/// Lo básico del negocio: guardar, ventas, caja, clientes y fiados. Restaurante y módulos van aparte
/// (store_restaurant.dart, store_modules.dart) y [StoreNotifier] junta todo.
abstract class _StoreCore extends Notifier<StoreState> {
  _StoreCore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

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
        // Con cuenta, el plan puede venir cambiado de la nube.
        if (loaded != null) ref.read(planProvider.notifier).follow(loaded.plan);
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

  /// Les pone código a los productos que no traen, para imprimir sus etiquetas: un EAN-13 interno que
  /// empieza con 20 (no choca con los de marca). Se guarda en el producto, así el lector los encuentra.
  void giveCodes(Iterable<String> productIds) {
    final taken = {for (final p in state.products) ?p.barcode};
    for (final id in productIds) {
      final p = state.productById(id);
      if (p == null || (p.barcode ?? '').isNotEmpty) continue;
      final code = newInternalCode(taken);
      taken.add(code);
      saveProduct(p.copyWith(barcode: code));
    }
  }

  /// Guarda un modelo con sus tallas y colores. Cada combinación de [drafts] trae cuántas piezas hay (si es
  /// nueva) o cuántas llegaron (si ya existía). Las que ya no están en la lista se ocultan (no se borran: sus
  /// ventas siguen en los reportes). Precio, costo, icono y dónde se vende son los del modelo.
  void saveModel(Product model, List<({String? size, String? color, double qty})> drafts, {double? minStock}) {
    final prior = state.productById(model.id);
    // Un producto suelto que pasa a tener tallas: su existencia se reparte en las tallas.
    if (prior != null && !state.isModel(prior) && prior.trackStock && prior.stock != 0) {
      addStock(prior.id, -prior.stock, adjustment: true);
    }
    final base = model.copyWith(trackStock: false, stock: 0, clearBarcode: true, clearMinStock: true);
    saveProduct(base);
    final existing = {
      for (final v in state.products.where((p) => p.parentId == base.id)) variantKey(v.size, v.color): v,
    };
    final seen = <String>{};
    for (final d in drafts) {
      final key = variantKey(d.size, d.color);
      if (!seen.add(key)) continue;
      final old = existing[key];
      final name = variantName(base.name, d.size, d.color);
      if (old == null) {
        saveProduct(
          Product(
            id: newId(),
            parentId: base.id,
            size: d.size,
            color: d.color,
            name: name,
            priceCents: base.priceCents,
            costCents: base.costCents,
            iconId: base.iconId,
            trackStock: true,
            stock: d.qty.clamp(0, Limits.maxQty),
            minStock: minStock,
            place: base.place,
          ),
        );
      } else {
        saveProduct(
          old.copyWith(
            name: name,
            priceCents: base.priceCents,
            costCents: base.costCents,
            iconId: base.iconId,
            trackStock: true,
            minStock: minStock,
            clearMinStock: minStock == null,
            active: true,
            place: base.place,
          ),
        );
        if (d.qty > 0) addStock(old.id, d.qty);
      }
    }
    for (final e in existing.entries) {
      if (!seen.contains(e.key) && e.value.active) saveProduct(e.value.copyWith(active: false));
    }
  }

  /// "Ya no lo vendo": lo oculta; si es un modelo, también sus tallas.
  void hideProduct(String productId) {
    final p = state.productById(productId);
    if (p == null) return;
    for (final v in state.variantsOf(productId)) {
      saveProduct(v.copyWith(active: false));
    }
    saveProduct(p.copyWith(active: false));
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
    int tipCents = 0,
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
    // La propina solo va en lo pagado (lo fiado no deja propina).
    final tip = kind == SaleKind.pagada ? tipCents.clamp(0, 10000000) : 0;
    final total = (subtotal - discountCents.clamp(0, subtotal)).clamp(0, subtotal) + tip;
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
      tipCents: tip,
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
    if (sale == null || sale.cancelled) return null;
    if (state.hadExchangeToday(sale)) return null;
    // De un turno abierto (de este celular o de otro: el dueño puede cancelar una del cajero), o de un corte
    // ya cerrado: entonces ese corte no cambia y lo que se devuelve se anota en la caja abierta de este celular.
    final late = !state.sessionIsOpen(sale.sessionId);
    final open = state.openSession;
    if (late && open == null) return null;
    final now = _now();
    final why = reason.trim().isEmpty ? 'Cancelada' : reason.trim();
    final cancelled = sale.cancel(
      now,
      late ? '$why (cancelada el ${now.day}/${now.month})' : why,
      inSession: late ? open!.id : null,
    );

    // Lo que ya se devolvió en otro día ya regresó al inventario y al cliente: no se cuenta dos veces.
    final returned = state.returnedOf(sale.id);
    final earlier = state.returnsOf(sale.id);
    final back = <String, double>{};
    for (final l in sale.lines) {
      final left = l.qty - (returned[l.key] ?? 0);
      if (l.productId != null && left > 0.0001) back[l.productId!] = (back[l.productId!] ?? 0) + left;
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
            amountCents: sale.totalCents - earlier.fold<int>(0, (a, r) => a + r.amountCents),
            createdAt: now,
            saleId: sale.id,
            sessionId: late ? open!.id : sale.sessionId,
          )
        : null;
    state = state.copyWith(
      sales: [for (final s in state.sales) s.id == saleId ? cancelled : s],
      products: products,
      credit: reversal == null ? state.credit : [...state.credit, reversal],
    );
    _save((r) => r.cancelSale(sale: cancelled, restocked: restocked, reversal: reversal));
    // Lo que se le regresa en efectivo sale de la caja de hoy.
    final cashBack = sale.cashCents - earlier.fold<int>(0, (a, r) => a + r.cashCents);
    if (late && sale.kind == SaleKind.pagada && cashBack > 0) {
      addMovement(CashKind.gasto, cashBack, 'Devolución de la venta ${sale.folioLabel}');
    }
    return cancelled;
  }

  /// Cambio (de talla, de color o de producto): el cliente regresa [back] (cuánto de cada renglón, por
  /// posición) de una venta pagada y se lleva [newLines]. Lo que regresa vuelve al inventario y paga parte de la
  /// venta nueva; solo se cobra la diferencia (con [method]) o, si lo nuevo vale menos, se le devuelve en
  /// efectivo. Necesita la caja abierta. null si no se pudo.
  ({Sale sale, SaleReturn ret})? exchange(
    String saleId,
    Map<int, double> back,
    List<SaleLine> newLines, {
    PayMethod method = PayMethod.efectivo,
    int? receivedCents,
    String reason = 'Cambio',
  }) {
    final original = state.sales.where((s) => s.id == saleId).firstOrNull;
    final open = state.openSession;
    if (original == null ||
        original.cancelled ||
        original.kind != SaleKind.pagada ||
        open == null ||
        newLines.isEmpty) {
      return null;
    }
    final already = state.returnedOf(original.id);
    final earlier = state.returnsOf(original.id);
    final factor = original.subtotalCents == 0 ? 1.0 : original.totalCents / original.subtotalCents;
    final lines = <ReturnedLine>[];
    for (final (i, l) in original.lines.indexed) {
      final left = l.qty - (already[l.key] ?? 0);
      final r = (back[i] ?? 0).clamp(0, left < 0 ? 0 : left).toDouble();
      if (r <= 0) continue;
      lines.add(
        ReturnedLine(
          key: l.key,
          productId: l.productId,
          name: l.name,
          qty: r,
          amountCents: (r * l.unitCents * factor).round(),
        ),
      );
    }
    if (lines.isEmpty) return null;
    final leftCents = original.totalCents - earlier.fold<int>(0, (a, r) => a + r.amountCents);
    final value = lines.fold<int>(0, (a, l) => a + l.amountCents).clamp(0, leftCents);
    final newTotal = newLines.fold(0, (a, l) => a + l.totalCents);
    final diff = newTotal - value;
    // Lo devuelto entra como efectivo a la venta nueva y sale igual en el cambio: en el cajón solo queda la
    // diferencia. Si la diferencia se paga con tarjeta o transferencia, va como un pago aparte.
    final payments = diff > 0 && method != PayMethod.efectivo
        ? [SalePayment(method: PayMethod.efectivo, amountCents: value), SalePayment(method: method, amountCents: diff)]
        : const <SalePayment>[];
    final sale = checkout(
      lines: newLines,
      kind: SaleKind.pagada,
      method: payments.isEmpty ? PayMethod.efectivo : null,
      payments: payments,
      receivedCents: payments.isEmpty && diff > 0 ? (receivedCents ?? diff) + value : null,
      customerId: original.customerId,
    );
    final ret = SaleReturn(
      id: newId(),
      saleId: original.id,
      sessionId: open.id,
      lines: lines,
      amountCents: value,
      cashCents: value,
      reason: reason.trim().isEmpty ? 'Cambio' : reason.trim(),
      clerk: _clerkName,
      createdAt: _now(),
      exchangeSaleId: sale.id,
    );
    final backByProduct = <String, double>{};
    for (final l in lines) {
      if (l.productId != null) backByProduct[l.productId!] = (backByProduct[l.productId!] ?? 0) + l.qty;
    }
    final restocked = [
      for (final p in state.products)
        if (p.trackStock && backByProduct.containsKey(p.id)) p.copyWith(stock: p.stock + backByProduct[p.id]!),
    ];
    final byId = {for (final p in restocked) p.id: p};
    state = state.copyWith(
      saleReturns: [...state.saleReturns, ret],
      products: [for (final p in state.products) byId[p.id] ?? p],
    );
    _save((r) => r.recordReturn(ret: ret, restocked: restocked));
    return (sale: sale, ret: ret);
  }

  /// Devolución de una parte de una venta de un corte ya cerrado. Ese corte no cambia: lo devuelto vuelve al
  /// inventario, el efectivo sale de la caja abierta de hoy (como gasto) y, si fue fiada, se le quita de la
  /// deuda. Se puede devolver varias veces, hasta lo que compró. Si regresa todo lo que quedaba y no había
  /// devuelto nada antes, mejor se cancela la venta. null si no se pudo (sin caja abierta, nada que devolver).
  SaleReturn? returnFromPastSale(String saleId, Map<int, double> back, {required String reason}) {
    final sale = state.sales.where((s) => s.id == saleId).firstOrNull;
    final open = state.openSession;
    if (sale == null || sale.cancelled || open == null || state.sessionIsOpen(sale.sessionId)) return null;
    final already = state.returnedOf(sale.id);
    final earlier = state.returnsOf(sale.id);
    // El descuento de la venta se reparte: cada peso devuelto vale lo que se cobró por él.
    final factor = sale.subtotalCents == 0 ? 1.0 : sale.totalCents / sale.subtotalCents;
    final lines = <ReturnedLine>[];
    var everything = true;
    for (final (i, l) in sale.lines.indexed) {
      final left = l.qty - (already[l.key] ?? 0);
      final r = (back[i] ?? 0).clamp(0, left < 0 ? 0 : left).toDouble();
      if (left - r > 0.0001) everything = false;
      if (r <= 0) continue;
      lines.add(
        ReturnedLine(
          key: l.key,
          productId: l.productId,
          name: l.name,
          qty: r,
          amountCents: (r * l.unitCents * factor).round(),
        ),
      );
    }
    if (lines.isEmpty) return null;
    final why = reason.trim().isEmpty ? 'Devolución' : reason.trim();
    if (everything && earlier.isEmpty) {
      cancelSale(saleId, reason: 'Devolvió todo: $why');
      return null;
    }
    // Lo que se devuelve no pasa de lo que falta por devolver del total (por los centavos del redondeo).
    final leftCents = sale.totalCents - earlier.fold<int>(0, (a, r) => a + r.amountCents);
    var amount = lines.fold<int>(0, (a, l) => a + l.amountCents);
    if (everything || amount > leftCents) amount = leftCents;
    // Pagada: primero de lo que pagó en efectivo (como al devolver el mismo día).
    final cashLeft = sale.kind == SaleKind.pagada
        ? sale.cashCents - earlier.fold<int>(0, (a, r) => a + r.cashCents)
        : 0;
    final cash = amount < cashLeft ? amount : (cashLeft < 0 ? 0 : cashLeft);
    final now = _now();
    final ret = SaleReturn(
      id: newId(),
      saleId: sale.id,
      sessionId: open.id,
      lines: lines,
      amountCents: amount,
      cashCents: cash,
      reason: why,
      clerk: _clerkName,
      createdAt: now,
    );
    final backByProduct = <String, double>{};
    for (final l in lines) {
      if (l.productId != null) backByProduct[l.productId!] = (backByProduct[l.productId!] ?? 0) + l.qty;
    }
    final restocked = [
      for (final p in state.products)
        if (p.trackStock && backByProduct.containsKey(p.id)) p.copyWith(stock: p.stock + backByProduct[p.id]!),
    ];
    final byId = {for (final p in restocked) p.id: p};
    final reversal = sale.kind == SaleKind.fiada && sale.customerId != null
        ? CreditEntry(
            id: newId(),
            customerId: sale.customerId!,
            type: CreditType.cancelacion,
            amountCents: amount,
            createdAt: now,
            saleId: sale.id,
            sessionId: open.id,
            clerk: _clerkName,
          )
        : null;
    state = state.copyWith(
      saleReturns: [...state.saleReturns, ret],
      products: [for (final p in state.products) byId[p.id] ?? p],
      credit: reversal == null ? null : [...state.credit, reversal],
    );
    _save((r) => r.recordReturn(ret: ret, restocked: restocked, reversal: reversal));
    if (cash > 0) {
      final note = 'Devolución de la venta ${sale.folioLabel}: ${ret.summary}';
      addMovement(CashKind.gasto, cash, note.length > 120 ? '${note.substring(0, 117)}...' : note);
    }
    return ret;
  }

  /// Devolución de una parte: [back] dice cuánto regresa de cada renglón (por posición).
  /// La venta original se cancela y se hace una nueva solo con lo que el cliente se queda, con su
  /// propio folio. Así inventario, caja y fiado cuadran solos. Devuelve la venta nueva, o null si
  /// regresó todo (entonces solo se cancela) o si no se pudo.
  Sale? returnItems(String saleId, Map<int, double> back, {required String reason}) {
    final sale = state.sales.where((s) => s.id == saleId).firstOrNull;
    final open = state.openSession;
    if (sale == null || sale.cancelled || open == null || sale.sessionId != open.id) return null;
    // Ya tuvo un cambio: rehacerla movería otra vez lo que ya pagó la venta nueva.
    if (state.hadExchangeToday(sale)) return null;
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
      name: state.registerName,
    );
    state = state.copyWith(sessions: [...state.sessions, session]);
    _save((r) => r.upsertSession(session));
  }

  /// Pone (o quita, con null) la foto de un producto. Los bytes ya vienen chicos (600×600 JPEG).
  /// La ruta cambia con cada foto: así los demás celulares saben que hay una nueva.
  void setProductPhoto(String productId, Uint8List? bytes) {
    final p = state.productById(productId);
    if (p == null) return;
    final path = bytes == null ? null : '${state.businessId}/$productId-${_clock().millisecondsSinceEpoch}.jpg';
    final updated = path == null ? p.copyWith(clearPhoto: true) : p.copyWith(photoPath: path);
    state = state.copyWith(
      products: [for (final x in state.products) x.id == productId ? updated : x],
      photos: path == null ? null : {...state.photos, path: bytes!},
    );
    _save((r) async {
      if (path != null) await r.savePhoto(productId, path, bytes!);
      await r.upsertProduct(updated, isNew: false);
    });
  }

  /// Pone (o quita, con null) el logo del negocio. Los bytes ya vienen listos ([prepareLogo]).
  /// Como las fotos, la ruta cambia con cada logo para que los demás celulares bajen el nuevo.
  void setLogo(Uint8List? bytes) {
    final path = bytes == null ? null : '${state.businessId}/logo-${_clock().millisecondsSinceEpoch}.png';
    state = state.copyWith(
      logoPath: path,
      clearLogo: path == null,
      photos: path == null ? null : {...state.photos, path: bytes!},
    );
    _save((r) => r.setLogo(path, bytes));
  }

  /// Prende o apaga imprimir solas las comandas nuevas en la cocina de este aparato.
  void setKitchenPrint(bool on) {
    state = state.copyWith(kitchenPrint: on);
    _save((r) => r.setKitchenPrint(on));
  }

  /// Prende o apaga imprimir solo el ticket al cobrar en este aparato.
  void setTicketPrint(bool on) {
    state = state.copyWith(ticketPrint: on);
    _save((r) => r.setTicketPrint(on));
  }

  /// Nombre de la caja de este celular. Si la caja está abierta, el turno también lo toma.
  void renameRegister(String? name) {
    final clean = name?.trim();
    final value = clean == null || clean.isEmpty ? null : clean;
    final open = state.openSession;
    final renamed = open?.renamed(value);
    state = state.copyWith(
      registerName: value,
      clearRegisterName: value == null,
      sessions: renamed == null ? null : [for (final s in state.sessions) s.id == renamed.id ? renamed : s],
    );
    _save((r) async {
      await r.setRegisterName(value);
      if (renamed != null) await r.upsertSession(renamed);
    });
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
}

/// Todo lo que cambia el negocio. Cada cambio se guarda en el teléfono y se respalda.
class StoreNotifier extends _StoreCore with _RestaurantOps, _ModuleOps {
  StoreNotifier({super.clock});
}

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);
