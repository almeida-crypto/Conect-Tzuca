import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';
import 'product_form.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  String _q = '';
  bool _onlyLow = false;

  Future<void> _add() async {
    final store = ref.read(storeProvider);
    final plan = ref.read(planProvider);
    final max = plan.limits.maxProducts;
    if (max != null && store.activeProducts.length >= max) {
      await showUpgradeSheet(
        context,
        reason:
            'Tu plan ${plan.label} permite hasta $max productos. '
            'Puedes desactivar los que ya no vendes o cambiar de plan.',
        needed: plan == Plan.semilla ? Plan.emprendedor : Plan.negocio,
      );
      return;
    }
    if (!mounted) return;
    await showProductForm(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(planProvider);
    final q = _q.trim().toLowerCase();
    final all = store.activeProducts;
    final low = all.where((p) => p.isLow).length;
    final list =
        all
            .where((p) => !_onlyLow || p.isLow)
            .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final max = plan.limits.maxProducts;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenTitle(
          'Inventario',
          subtitle: [
            low == 0 ? 'Nada por acabarse' : '$low ${low == 1 ? 'producto' : 'productos'} por acabarse',
            if (max != null) '${all.length} de $max productos',
          ].join(' · '),
          trailing: GButton(label: 'Agregar', icon: Icons.add, onPressed: _add),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o código',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: Text('Solo por acabarse ($low)', style: GText.sans(size: 12.5)),
                selected: _onlyLow,
                onSelected: (v) => setState(() => _onlyLow = v),
                selectedColor: GColors.ocre.withValues(alpha: 0.35),
                backgroundColor: GColors.papel2,
                side: const BorderSide(color: GColors.linea),
                showCheckmark: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final p in list) _StockRow(product: p),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No hay productos que coincidan.', textAlign: TextAlign.center, style: GText.muted(size: 14)),
          ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    // La barra se llena respecto a 4 veces el mínimo (o 20 piezas si no hay mínimo).
    final ref = (p.minStock ?? 5) * 4;
    final fill = p.trackStock ? (p.stock / ref).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () => showProductForm(context, product: p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.linea)),
        ),
        child: Row(
          children: [
            Icon(productIcon(p.iconId), size: 20, color: GColors.pardo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.name, overflow: TextOverflow.ellipsis, style: GText.sans(size: 13.5)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        money(p.priceCents, hideZeroCents: true),
                        style: GText.mono(size: 11, color: GColors.tintaSuave),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (p.trackStock)
                    Container(
                      height: 6,
                      color: GColors.papel2,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(color: p.isLow ? GColors.rojo : GColors.pardo),
                      ),
                    )
                  else
                    Text('Sin control de existencia', style: GText.muted(size: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                p.trackStock ? qtyLabel(p.stock) : '—',
                textAlign: TextAlign.right,
                style: GText.amount(size: 17, color: p.isLow ? GColors.rojo : GColors.tinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
