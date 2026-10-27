import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/plan.dart';

/// Plan activo. Mientras no hay cobros reales, se puede cambiar desde "Mi plan" para previsualizar.
class PlanNotifier extends Notifier<Plan> {
  @override
  Plan build() => Plan.semilla;

  void set(Plan plan) => state = plan;
}

final planProvider = NotifierProvider<PlanNotifier, Plan>(PlanNotifier.new);

/// Indicador de conexión. Por ahora es una simulación; con PowerSync vendrá del estado real.
class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final onlineProvider = NotifierProvider<OnlineNotifier, bool>(OnlineNotifier.new);

/// Carrito de la venta en curso.
class CartNotifier extends Notifier<List<SaleLine>> {
  @override
  List<SaleLine> build() => const [];

  void addProduct(Product p, {double qty = 1}) {
    final i = state.indexWhere((l) => l.productId == p.id);
    if (i >= 0) {
      setQty(state[i].key, state[i].qty + qty);
    } else {
      state = [
        ...state,
        SaleLine(
          key: p.id,
          productId: p.id,
          name: p.name,
          unitCents: p.priceCents,
          unitCostCents: p.costCents,
          qty: qty,
        ),
      ];
    }
  }

  void addQuick(String key, String name, int cents) {
    state = [...state, SaleLine(key: key, name: name, unitCents: cents, qty: 1)];
  }

  void setQty(String key, double qty) {
    state = qty <= 0
        ? state.where((l) => l.key != key).toList()
        : [for (final l in state) l.key == key ? l.withQty(qty) : l];
  }

  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartNotifier, List<SaleLine>>(CartNotifier.new);

final cartTotalProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (a, l) => a + l.totalCents));
