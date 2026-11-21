import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';

/// Escoger la talla (y color) de un modelo. Con [onlyAvailable] (al apartar) las agotadas no se pueden tocar.
Future<Product?> pickVariant(BuildContext context, Product model, {bool onlyAvailable = false, String? title}) =>
    showGSheet<Product>(context, (_) => _VariantPicker(model: model, onlyAvailable: onlyAvailable, title: title));

class _VariantPicker extends ConsumerWidget {
  const _VariantPicker({required this.model, required this.onlyAvailable, this.title});

  final Product model;
  final bool onlyAvailable;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final variants = store.variantsOf(model.id);
    final colors = {for (final v in variants) v.color};
    // Con colores: una fila por color, con sus tallas. Sin colores: todas las tallas juntas.
    final groups = <String?, List<Product>>{};
    for (final v in variants) {
      groups.putIfAbsent(colors.length > 1 || v.color != null ? v.color : null, () => []).add(v);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Padding(padding: const EdgeInsets.only(right: 12, top: 6), child: ProductThumb(model, size: 40)),
            Expanded(
              child: SheetHeader(
                title ?? model.name,
                caption: '${money(model.priceCents, hideZeroCents: true)} · escoge la talla',
              ),
            ),
          ],
        ),
        if (variants.isEmpty) Text('Este modelo no tiene tallas a la venta.', style: GText.muted(size: 14)),
        for (final g in groups.entries) ...[
          if (g.key != null) ...[
            const SizedBox(height: 6),
            Text(g.key!, style: GText.label()),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in g.value)
                _SizeTile(
                  variant: v,
                  price: v.priceCents == model.priceCents ? null : v.priceCents,
                  // Con colores en filas, la talla basta; sin tallas, el color.
                  label: (g.key != null ? v.size : null) ?? v.variantLabel,
                  available: v.trackStock ? v.stock : null,
                  enabled: !onlyAvailable || !v.trackStock || v.stock > 0,
                  onTap: () => Navigator.of(context).pop(v),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.variant,
    this.price,
    required this.label,
    required this.available,
    required this.enabled,
    required this.onTap,
  });

  final Product variant;

  /// Precio de esta talla cuando no es el del modelo.
  final int? price;
  final String label;
  final double? available;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = available != null && available! <= 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          '$label, ${out
              ? 'agotada'
              : available == null
              ? ''
              : 'quedan ${qtyLabel(available!)}'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(GShape.radiusSmall),
          child: Container(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: GColors.superficie,
              border: Border.all(color: out ? GColors.linea : GColors.tinta.withValues(alpha: 0.25), width: 1.5),
              borderRadius: BorderRadius.circular(GShape.radiusSmall),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: GText.sans(size: 16, weight: FontWeight.w800)),
                if (price != null)
                  Text(money(price!, hideZeroCents: true), style: GText.figures(size: 11.5, color: GColors.marca)),
                const SizedBox(height: 2),
                Text(
                  out ? 'Agotada' : (available == null ? '—' : 'Hay ${qtyLabel(available!)}'),
                  style: GText.sans(size: 11.5, color: out ? GColors.rojo : GColors.tintaSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
