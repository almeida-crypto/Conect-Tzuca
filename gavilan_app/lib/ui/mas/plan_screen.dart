import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Comparación de planes. Mientras no hay cobro de suscripciones, "Probar este plan" solo cambia la vista previa.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(planProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Mi plan', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                Text(
                  'Sin anuncios en ningún plan. La app se ve igual en todos; cambian los límites y lo que incluye.',
                  style: GText.sans(size: 13.5, weight: FontWeight.w400, color: GColors.tintaSuave),
                ),
                const SizedBox(height: 14),
                for (final (i, p) in Plan.values.indexed)
                  EnterAnimation(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PlanCard(
                        plan: p,
                        current: p == current,
                        onTry: () {
                          ref.read(planProvider.notifier).set(p);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Viendo la app como plan ${p.label}. No se cobra nada.')),
                          );
                        },
                      ),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.current, required this.onTry});

  final Plan plan;
  final bool current;
  final VoidCallback onTry;

  Color get _accent => switch (plan) {
    Plan.semilla => GColors.cafe,
    Plan.emprendedor => GColors.marca,
    Plan.negocio => GColors.cenote,
  };

  @override
  Widget build(BuildContext context) {
    final (amount, period) = plan.priceParts;
    final soon = planComingSoon(plan);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: GColors.superficie,
        borderRadius: BorderRadius.circular(GShape.radius + 4),
        border: Border.all(color: current ? GColors.marca : Colors.transparent, width: 2),
        boxShadow: GShape.shadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PlanBadge(plan),
              if (plan == Plan.negocio) ...[
                const SizedBox(width: 6),
                Text('El más completo', style: GText.muted(size: 12)),
              ],
              const Spacer(),
              if (current)
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                  decoration: BoxDecoration(color: GColors.marca, borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Tu plan',
                        style: GText.sans(size: 12, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(amount, style: GText.amount(size: 28)),
              if (period != null) ...[const SizedBox(width: 6), Text(period, style: GText.muted(size: 13))],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.profile,
            style: GText.sans(size: 13, weight: FontWeight.w400, color: GColors.tintaSuave),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: GColors.linea),
          const SizedBox(height: 10),
          for (final h in planHighlights(plan)) _Feature(text: h, color: _accent),
          for (final h in soon) _Feature(text: h, color: GColors.tintaTenue, soon: true),
          if (!current) ...[
            const SizedBox(height: 14),
            GButton(label: 'Probar este plan', kind: GButtonKind.outline, expand: true, onPressed: onTry),
          ],
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text, required this.color, this.soon = false});

  final String text;
  final Color color;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(soon ? Icons.schedule_rounded : Icons.check_rounded, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (soon)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: GColors.hundido, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          'Pronto',
                          style: GText.sans(size: 11, weight: FontWeight.w800, color: GColors.tintaSuave),
                        ),
                      ),
                    ),
                ],
              ),
              style: GText.sans(size: 14, weight: FontWeight.w500, color: soon ? GColors.tintaSuave : GColors.tinta),
            ),
          ),
        ],
      ),
    );
  }
}
