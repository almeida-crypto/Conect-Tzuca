import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';
import 'variant_picker.dart';

/// Buscar un producto (por nombre o código). Un modelo con tallas pregunta después cuál; con [onlyAvailable]
/// las tallas agotadas no se pueden escoger. null si se canceló.
Future<Product?> pickProduct(
  BuildContext context, {
  String title = '¿Qué producto?',
  String? sizeTitle,
  bool onlyAvailable = true,
}) async {
  final picked = await showGSheet<Product>(context, (_) => _ProductSearch(title: title));
  if (picked == null || !context.mounted) return null;
  final store = ProviderScope.containerOf(context).read(storeProvider);
  if (!store.isModel(picked)) return picked;
  return pickVariant(context, picked, onlyAvailable: onlyAvailable, title: sizeTitle);
}

class _ProductSearch extends ConsumerStatefulWidget {
  const _ProductSearch({required this.title});

  final String title;

  @override
  ConsumerState<_ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<_ProductSearch> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final q = _q.trim().toLowerCase();
    final byCode = q.isEmpty ? null : store.productByBarcode(q);
    final list = [
      ?byCode,
      ...store.activeProducts.where((p) => p.id != byCode?.id && (q.isEmpty || p.name.toLowerCase().contains(q))),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(widget.title),
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre o código',
            prefixIcon: Icon(Icons.search_rounded, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No hay productos que coincidan.', textAlign: TextAlign.center, style: GText.muted(size: 14)),
          ),
        for (final p in list.take(40))
          Builder(
            builder: (context) {
              final model = store.isModel(p);
              final stock = model ? store.stockOfModel(p.id) : (p.trackStock ? p.stock : null);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProductThumb(p, size: 38),
                title: Text(p.name, style: GText.sans(size: 14, weight: FontWeight.w600)),
                subtitle: Text(
                  [
                    money(p.priceCents, hideZeroCents: true),
                    if (model) '${store.variantsOf(p.id).length} tallas',
                    if (stock != null) stock <= 0 ? 'agotado' : 'hay ${qtyLabel(stock)}',
                  ].join(' · '),
                  style: GText.muted(size: 12),
                ),
                onTap: () => Navigator.of(context).pop(p),
              );
            },
          ),
      ],
    );
  }
}
