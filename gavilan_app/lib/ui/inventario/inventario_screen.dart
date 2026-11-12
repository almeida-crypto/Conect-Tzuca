import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';
import 'catalog_table_screen.dart';
import 'first_products.dart';
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
    if (!await ensureRoomForProduct(context, ref) || !mounted) return;
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
          trailing: ref.watch(permissionsProvider).editCatalog
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En la computadora: cambiar muchos productos a la vez, como en Excel.
                    if (MediaQuery.sizeOf(context).width >= 900) ...[
                      GButton(
                        label: 'Editar en tabla',
                        icon: Icons.table_chart_outlined,
                        kind: GButtonKind.outline,
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatalogTableScreen())),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GButton(label: 'Agregar', icon: Icons.add, onPressed: _add),
                  ],
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o código',
              prefixIcon: Icon(Icons.search_rounded, size: 22),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SoftButton(
                label: _onlyLow ? 'Ver todos' : 'Solo por acabarse ($low)',
                icon: _onlyLow ? Icons.close_rounded : Icons.warning_amber_rounded,
                color: _onlyLow ? GColors.tinta : const Color(0xFFB27C00),
                onTap: () => setState(() => _onlyLow = !_onlyLow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isNotEmpty)
          GCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, p) in list.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 70, color: GColors.linea),
                  _StockRow(product: p),
                ],
              ],
            ),
          ),
        if (all.isEmpty) const FirstProductsCard(),
        if (list.isEmpty && all.isNotEmpty)
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
    final barColor = p.isLow ? GColors.rojo : (fill < 0.5 ? GColors.izamal : GColors.cenote);
    return InkWell(
      onTap: () => showProductForm(context, product: p),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          children: [
            ProductBadge(p.iconId, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: GText.sans(size: 14.5, weight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        money(p.priceCents, hideZeroCents: true),
                        style: GText.figures(size: 12, color: GColors.tintaTenue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (p.trackStock)
                    // La barra se llena al aparecer.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 6,
                        color: GColors.hundido,
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fill),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FractionallySizedBox(
                            widthFactor: v,
                            child: Container(
                              decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(99)),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Text('Sin control de existencia', style: GText.muted(size: 12)),
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
