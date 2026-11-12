import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import 'catalog_table_screen.dart';
import 'product_form.dart';
import 'starter_catalog_screen.dart';

/// Cuando el negocio todavía no tiene productos: formas fáciles de dar de alta los primeros.
class FirstProductsCard extends ConsumerWidget {
  const FirstProductsCard({super.key, this.onQuickSale});

  /// En Cobrar: cobrar por monto mientras tanto.
  final VoidCallback? onQuickSale;

  Future<void> _starter(BuildContext context) async {
    final added = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => const StarterCatalogScreen()));
    if (added != null && added > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listo: ${added == 1 ? 'se agregó 1 producto' : 'se agregaron $added productos'}')),
      );
    }
  }

  Future<void> _one(BuildContext context, WidgetRef ref) async {
    if (!await ensureRoomForProduct(context, ref) || !context.mounted) return;
    await showProductForm(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(permissionsProvider).editCatalog;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return GCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agrega tus primeros productos', style: GText.sans(size: 18, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            canEdit
                ? 'Con tus productos aquí cobras con un toque y la app lleva tu inventario. Elige cómo empezar:'
                : 'Pídele al dueño que agregue los productos. Mientras, puedes cobrar por monto.',
            style: GText.sans(size: 13.5, weight: FontWeight.w400, color: GColors.tintaSuave),
          ),
          if (canEdit) ...[
            const SizedBox(height: 12),
            _Option(
              icon: Icons.checklist_rounded,
              color: GColors.marca,
              title: 'Elegir de una lista',
              text: 'Productos comunes de tiendita: márcalos y ponles tu precio.',
              highlighted: true,
              onTap: () => _starter(context),
            ),
            _Option(
              icon: Icons.add_rounded,
              color: GColors.cenote,
              title: 'Agregar uno por uno',
              text: 'Con su nombre, precio y, si quieres, su código de barras.',
              onTap: () => _one(context, ref),
            ),
            if (wide)
              _Option(
                icon: Icons.table_chart_outlined,
                color: GColors.cafe,
                title: 'Pegar desde Excel',
                text: 'Si ya tienes tu lista en una hoja de cálculo.',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CatalogTableScreen())),
              ),
          ],
          if (onQuickSale != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onQuickSale,
                icon: const Icon(Icons.dialpad_rounded, size: 18, color: GColors.tintaSuave),
                label: Text(
                  '¿Solo quieres cobrar ya? Venta rápida por monto',
                  style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.tintaSuave),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlighted ? GColors.marcaSuave : GColors.fondo,
        borderRadius: BorderRadius.circular(GShape.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(GShape.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: highlighted ? GColors.superficie : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GShape.radiusSmall),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GText.sans(size: 14.5, weight: FontWeight.w800)),
                      const SizedBox(height: 1),
                      Text(
                        text,
                        style: GText.sans(size: 12.5, weight: FontWeight.w400, color: GColors.tintaSuave),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
