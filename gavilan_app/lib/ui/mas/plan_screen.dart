import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Comparación de planes. Mientras no hay cobro de suscripciones, "Ver la app así" solo cambia la vista previa.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(planProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        title: Text('Mi plan', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              'Sin anuncios en ningún plan. El diseño es el mismo; cambian los límites y los módulos.',
              style: GText.muted(size: 13),
            ),
            const SizedBox(height: 12),
            for (final p in Plan.values) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GColors.papelClaro,
                  border: Border.all(color: p == current ? GColors.oxido : GColors.linea, width: p == current ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PlanBadge(p),
                        const Spacer(),
                        if (p == current)
                          Text(
                            'Tu plan',
                            style: GText.sans(size: 12, weight: FontWeight.w800, color: GColors.oxido),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(p.price, style: GText.amount(size: 20)),
                    const SizedBox(height: 4),
                    Text(p.profile, style: GText.muted(size: 12.5)),
                    const SizedBox(height: 8),
                    for (final h in planHighlights(p))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check, size: 16, color: GColors.monte),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(h, style: GText.sans(size: 13, weight: FontWeight.w400)),
                            ),
                          ],
                        ),
                      ),
                    if (p != current) ...[
                      const SizedBox(height: 12),
                      GButton(
                        label: 'Ver la app así (vista previa)',
                        kind: GButtonKind.outline,
                        expand: true,
                        onPressed: () {
                          ref.read(planProvider.notifier).set(p);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Vista previa del plan ${p.label}. No se cobra nada.')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
