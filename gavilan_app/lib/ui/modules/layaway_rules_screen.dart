import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../domain/layaway_rules.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';

/// Las reglas del apartado de este negocio: las pone el dueño y las sigue todo el equipo. Salen en el
/// comprobante para que el cliente las conozca desde el principio.
class LayawayRulesScreen extends ConsumerStatefulWidget {
  const LayawayRulesScreen({super.key});

  @override
  ConsumerState<LayawayRulesScreen> createState() => _LayawayRulesScreenState();
}

class _LayawayRulesScreenState extends ConsumerState<LayawayRulesScreen> {
  late LayawayRules _rules = ref.read(storeProvider).layawayRules;
  late final _note = TextEditingController(text: _rules.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    final rules = LayawayRules(
      cancel: _rules.cancel,
      keepPct: _rules.keepPct,
      days: _rules.days,
      minDepositPct: _rules.minDepositPct,
      note: note.isEmpty ? null : note,
    );
    ref.read(storeProvider.notifier).setLayawayRules(rules);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reglas guardadas')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(permissionsProvider).manageCredit;
    Widget chips<T>(List<(T, String)> options, T selected, ValueChanged<T> onPick) => Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: canEdit ? (_) => setState(() => onPick(value)) : null,
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Reglas del apartado', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              canEdit
                  ? 'Las sigue todo tu equipo y salen en el comprobante, para que el cliente las sepa desde el principio.'
                  : 'Las pone el dueño. Salen en el comprobante del cliente.',
              style: GText.muted(size: 13.5),
            ),
            const SizedBox(height: 18),
            Text('Plazo para liquidar', style: GText.label()),
            const SizedBox(height: 6),
            chips<int?>(
              [
                (15, '15 días'),
                (30, '30 días'),
                (45, '45 días'),
                (60, '60 días'),
                (90, '90 días'),
                (null, 'Sin fecha'),
              ],
              _rules.days,
              (v) => _rules = _rules.copyWith(days: v, noDays: v == null),
            ),
            const SizedBox(height: 4),
            Text('Es la fecha límite que sale al apartar; se puede cambiar en cada apartado.', style: GText.muted()),
            const SizedBox(height: 18),
            Text('Anticipo mínimo', style: GText.label()),
            const SizedBox(height: 6),
            chips<int?>(
              [(null, 'El que quiera'), (10, '10%'), (20, '20%'), (30, '30%'), (50, '50%')],
              _rules.minDepositPct,
              (v) => _rules = _rules.copyWith(minDepositPct: v, noMinDeposit: v == null),
            ),
            const SizedBox(height: 18),
            Text('Si el cliente cancela', style: GText.label()),
            const SizedBox(height: 4),
            RadioGroup<CancelRule>(
              groupValue: _rules.cancel,
              onChanged: (v) {
                if (canEdit && v != null) setState(() => _rules = _rules.copyWith(cancel: v));
              },
              child: Column(
                children: [
                  for (final r in CancelRule.values)
                    RadioListTile<CancelRule>(
                      value: r,
                      enabled: canEdit,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: GColors.marca,
                      title: Text(r.label, style: GText.sans(size: 14, weight: FontWeight.w600)),
                      subtitle: r == CancelRule.preguntar
                          ? Text('Al cancelar se escoge qué hacer', style: GText.muted(size: 12))
                          : null,
                    ),
                ],
              ),
            ),
            if (_rules.cancel == CancelRule.quedarsePorcentaje) ...[
              const SizedBox(height: 4),
              Text('¿Cuánto se queda el negocio?', style: GText.sans(size: 13.5)),
              const SizedBox(height: 6),
              chips<int>(
                [(5, '5%'), (10, '10%'), (15, '15%'), (20, '20%'), (30, '30%'), (50, '50%')],
                _rules.keepPct,
                (v) => _rules = _rules.copyWith(keepPct: v),
              ),
            ],
            if (_rules.cancel == CancelRule.saldoAFavor) ...[
              const SizedBox(height: 4),
              Text(
                'El saldo se usa como anticipo de otro apartado. Si le alcanza para todo, queda liquidado y se lo '
                'lleva en el momento.',
                style: GText.muted(size: 12.5),
              ),
            ],
            const SizedBox(height: 18),
            Text('Condiciones (opcional)', style: GText.label()),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              enabled: canEdit,
              maxLines: 3,
              minLines: 2,
              inputFormatters: [maxChars(Limits.maxNoteLength)],
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'No hay cambios en ropa interior ni en ofertas'),
            ),
            const SizedBox(height: 20),
            if (canEdit) GButton(label: 'Guardar reglas', expand: true, big: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
