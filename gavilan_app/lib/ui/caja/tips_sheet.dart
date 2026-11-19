import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Reparte entre una o varias personas la propina en partes iguales. El sobrante de centavos va a las primeras,
/// para que la suma dé justo [cents].
List<int> splitEvenly(int cents, int people) {
  if (people <= 0) return const [];
  final base = cents ~/ people;
  final extra = cents % people;
  return [for (var i = 0; i < people; i++) base + (i < extra ? 1 : 0)];
}

/// "Propinas del turno": cuánto se juntó y cuánto falta entregar. Solo sale si hubo propinas; repartirlas
/// es opcional (hay lugares donde se la queda el mesero que atendió y no hace falta anotar nada).
class TipsCard extends ConsumerWidget {
  const TipsCard({super.key, required this.summary});

  final CashSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final pending = s.tipsPendingCents;
    return GCard(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GColors.cafe.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.volunteer_activism_outlined, color: GColors.cafe),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Propinas del turno · ${money(s.tipsCents)}',
                  style: GText.sans(size: 15, weight: FontWeight.w800),
                ),
                Text(
                  s.tipsPaidCents == 0
                      ? 'Para el equipo. Repartirlas es opcional.'
                      : pending == 0
                      ? 'Ya se entregaron todas'
                      : 'Entregadas ${money(s.tipsPaidCents)} · faltan ${money(pending)}',
                  style: GText.muted(size: 12.5),
                ),
              ],
            ),
          ),
          if (pending > 0)
            SoftButton(
              label: 'Repartir',
              icon: Icons.call_split_rounded,
              color: GColors.cafe,
              onTap: () => showGSheet<void>(context, (_) => TipsSheet(pendingCents: pending)),
            ),
        ],
      ),
    );
  }
}

/// Repartir la propina: a quién (de los que cobraron, los del PIN o un nombre nuevo) y en partes iguales o
/// a mano. Cada entrega queda anotada en la caja y sale del efectivo.
class TipsSheet extends ConsumerStatefulWidget {
  const TipsSheet({super.key, required this.pendingCents});

  final int pendingCents;

  @override
  ConsumerState<TipsSheet> createState() => _TipsSheetState();
}

class _TipsSheetState extends ConsumerState<TipsSheet> {
  final _people = <String>[];
  final _extra = <String>[];
  final _byHand = <String, TextEditingController>{};
  final _newName = TextEditingController();
  bool _even = true;
  String? _error;

  @override
  void dispose() {
    _newName.dispose();
    for (final c in _byHand.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Quien cobró en el turno y las personas con PIN: los nombres que más se usan.
  List<String> _suggestions(StoreState store) {
    final session = store.openSession;
    final names = <String>{
      if (session != null)
        for (final s in store.sales)
          if (s.sessionId == session.id && s.clerk != null) s.clerk!,
      for (final c in store.clerks) c.name,
      ..._extra,
    };
    return names.toList();
  }

  void _toggle(String name) => setState(() {
    _error = null;
    _people.contains(name) ? _people.remove(name) : _people.add(name);
  });

  void _addName() {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (!_extra.contains(name)) _extra.add(name);
      if (!_people.contains(name)) _people.add(name);
      _newName.clear();
      _error = null;
    });
  }

  Map<String, int> _amounts() {
    if (_even) {
      final parts = splitEvenly(widget.pendingCents, _people.length);
      return {for (final (i, p) in _people.indexed) p: parts[i]};
    }
    return {for (final p in _people) p: parseMoney(_byHand[p]?.text ?? '') ?? 0};
  }

  void _give() {
    final amounts = _amounts()..removeWhere((_, c) => c <= 0);
    final total = amounts.values.fold(0, (a, c) => a + c);
    if (amounts.isEmpty) {
      setState(() => _error = 'Elige a quién y cuánto');
      return;
    }
    if (total > widget.pendingCents) {
      setState(() => _error = 'Son ${money(total)}: más de lo que hay de propina (${money(widget.pendingCents)})');
      return;
    }
    final store = ref.read(storeProvider.notifier);
    for (final e in amounts.entries) {
      store.addMovement(CashKind.propina, e.value, 'Propina para ${e.key}');
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Se anotó: ${money(total)} de propina entregados. Sale del efectivo.')));
  }

  @override
  Widget build(BuildContext context) {
    final names = _suggestions(ref.watch(storeProvider));
    final amounts = _amounts();
    final total = amounts.values.fold(0, (a, c) => a + c);
    for (final p in _people) {
      _byHand.putIfAbsent(p, TextEditingController.new);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader('Repartir propinas', caption: 'Hay ${money(widget.pendingCents)} por entregar'),
        const SizedBox(height: 8),
        Text('¿A quién?', style: GText.label()),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final n in names)
              FilterChip(label: Text(n), selected: _people.contains(n), onSelected: (_) => _toggle(n)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newName,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(hintText: 'Otro nombre (Juan, el mesero)', counterText: ''),
                onSubmitted: (_) => _addName(),
              ),
            ),
            const SizedBox(width: 8),
            SoftButton(label: 'Agregar', icon: Icons.person_add_alt_1_rounded, onTap: _addName),
          ],
        ),
        if (_people.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GChip(label: 'Partes iguales', selected: _even, onTap: () => setState(() => _even = true)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GChip(label: 'A mano', selected: !_even, onTap: () => setState(() => _even = false)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _people)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(p, style: GText.sans(size: 14.5, weight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 130,
                    child: _even
                        ? Text(
                            money(amounts[p] ?? 0),
                            textAlign: TextAlign.right,
                            style: GText.figures(size: 15, weight: FontWeight.w800),
                          )
                        : TextField(
                            controller: _byHand[p],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: const [MoneyInputFormatter()],
                            textAlign: TextAlign.right,
                            onChanged: (_) => setState(() => _error = null),
                            decoration: const InputDecoration(prefixText: '\$ ', hintText: '0', isDense: true),
                          ),
                  ),
                ],
              ),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: GText.sans(size: 13, color: GColors.rojo)),
          ),
        const SizedBox(height: 10),
        Text('Cada entrega queda anotada en la caja y sale del efectivo.', style: GText.muted(size: 12.5)),
        const SizedBox(height: 12),
        GButton(
          label: total > 0 ? 'Entregar ${money(total)}' : 'Entregar',
          icon: Icons.check_rounded,
          expand: true,
          onPressed: _people.isEmpty ? null : _give,
        ),
      ],
    );
  }
}
