import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';

/// Módulo adicional del documento maestro y qué plan lo incluye.
class _Module {
  const _Module(this.icon, this.title, this.subtitle, this.needed, this.unlocked);

  final IconData icon;
  final String title;
  final String subtitle;
  final Plan needed;
  final bool Function(PlanLimits) unlocked;
}

final _modules = [
  _Module(
    Icons.shopping_bag_outlined,
    'Apartados',
    'Foto del artículo, anticipo y fecha límite',
    Plan.emprendedor,
    (l) => l.layaways,
  ),
  _Module(
    Icons.checkroom_outlined,
    'Pacas y lotes',
    'Cuánto falta para recuperar lo invertido',
    Plan.semilla,
    (l) => true,
  ),
  _Module(
    Icons.event_note_outlined,
    'Pedidos por tanda',
    'Cochinita del domingo, marquesitas, cenas',
    Plan.emprendedor,
    (l) => l.batches,
  ),
  _Module(
    Icons.table_restaurant_outlined,
    'Mesas y cocina',
    'Meseros, comandas y pantalla de cocina',
    Plan.negocio,
    (l) => l.restaurant,
  ),
  _Module(Icons.groups_outlined, 'Equipo y roles', 'Dueño, cajeros, meseros y cocina', Plan.negocio, (l) => l.team),
  _Module(Icons.print_outlined, 'Impresora de tickets', 'Térmica por Bluetooth o USB', Plan.negocio, (l) => l.printer),
  _Module(
    Icons.computer_outlined,
    'Panel web en la laptop',
    'Reportes y catálogo desde la computadora',
    Plan.emprendedor,
    (l) => l.webPanel,
  ),
];

class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final store = ref.watch(storeProvider);
    final limits = plan.limits;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenTitle('Más'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GColors.papelClaro,
                border: Border.all(color: GColors.tinta, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.businessName, style: GText.sans(size: 16, weight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            PlanBadge(plan),
                            const SizedBox(width: 8),
                            Text(plan.price, style: GText.muted()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Mi plan',
                    style: GText.sans(size: 13, weight: FontWeight.w800, color: GColors.oxido),
                  ),
                  const Icon(Icons.chevron_right, color: GColors.oxido),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Módulos', style: GText.sans(size: 15, weight: FontWeight.w800)),
        ),
        for (final m in _modules) _ModuleRow(module: m, unlocked: m.unlocked(limits), plan: plan),
      ],
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module, required this.unlocked, required this.plan});

  final _Module module;
  final bool unlocked;
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (!unlocked) {
          showUpgradeSheet(
            context,
            reason: '${module.title}: ${module.subtitle.toLowerCase()}.',
            needed: module.needed,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${module.title} está incluido en tu plan. Se construye en la siguiente etapa.')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.linea)),
        ),
        child: Row(
          children: [
            Icon(module.icon, color: unlocked ? GColors.pardo : GColors.tintaTenue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: GText.sans(
                      size: 14,
                      weight: FontWeight.w800,
                      color: unlocked ? GColors.tinta : GColors.tintaSuave,
                    ),
                  ),
                  Text(module.subtitle, style: GText.muted(size: 12)),
                ],
              ),
            ),
            if (unlocked)
              Text('Pronto', style: GText.sans(size: 11.5, color: GColors.tintaSuave))
            else ...[
              const Icon(Icons.lock_outline, size: 16, color: GColors.tintaSuave),
              const SizedBox(width: 4),
              PlanBadge(module.needed),
            ],
          ],
        ),
      ),
    );
  }
}
