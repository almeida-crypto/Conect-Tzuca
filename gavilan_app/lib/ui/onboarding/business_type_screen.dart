import 'package:flutter/material.dart';

import '../../domain/business.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';

IconData businessTypeIcon(BusinessType t) => switch (t) {
  BusinessType.tienda => Icons.storefront_rounded,
  BusinessType.restaurante => Icons.restaurant_rounded,
  BusinessType.ropa => Icons.checkroom_rounded,
  BusinessType.encargos => Icons.event_note_rounded,
  BusinessType.otro => Icons.apps_rounded,
};

/// "¿Qué tipo de negocio es?": decide qué se ve al empezar. Devuelve el tipo elegido.
class BusinessTypeScreen extends StatelessWidget {
  const BusinessTypeScreen({super.key, this.current});

  /// El tipo de ahora, si se está cambiando desde "Más".
  final BusinessType? current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: GColors.fondo, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('¿Qué tipo de negocio es?', style: GText.title()),
                const SizedBox(height: 6),
                Text(
                  'Así te mostramos solo lo que vas a usar. Lo puedes cambiar después en Más.',
                  style: GText.sans(size: 14, weight: FontWeight.w400, color: GColors.tintaSuave),
                ),
                const SizedBox(height: 18),
                for (final (i, t) in BusinessType.values.indexed)
                  EnterAnimation(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TypeCard(type: t, selected: t == current, onTap: () => Navigator.of(context).pop(t)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.selected, required this.onTap});

  final BusinessType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final modules = type == BusinessType.otro
        ? 'Todos los módulos'
        : type.defaultModules.isEmpty
        ? 'Cobrar, fiados, inventario y caja'
        : 'Incluye ${_list([for (final m in type.defaultModules) m.label.toLowerCase()])}';
    return Material(
      color: GColors.superficie,
      borderRadius: BorderRadius.circular(GShape.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(GShape.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GShape.radius),
            border: Border.all(color: selected ? GColors.marca : GColors.linea, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: GColors.marcaSuave, borderRadius: BorderRadius.circular(12)),
                child: Icon(businessTypeIcon(type), color: GColors.marca, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: GText.sans(size: 16, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(type.examples, style: GText.muted(size: 13)),
                    const SizedBox(height: 4),
                    Text(
                      modules,
                      style: GText.sans(size: 12.5, weight: FontWeight.w700, color: GColors.cenote),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
            ],
          ),
        ),
      ),
    );
  }
}

/// "a", "a y b", "a, b y c". Si algún nombre ya trae "y" ("pacas y lotes"), la última va con coma: ", y".
String _list(List<String> items) {
  if (items.length <= 1) return items.join();
  final glue = items.any((i) => i.contains(' y ')) ? ', y ' : ' y ';
  return '${items.sublist(0, items.length - 1).join(', ')}$glue${items.last}';
}
