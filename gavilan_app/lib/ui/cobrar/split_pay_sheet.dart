import 'package:flutter/material.dart';

import '../../core/limits.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Cómo se reparte el pago: en partes iguales o con montos libres (pago mixto).
enum SplitMode { iguales, libres }

/// Lo que se eligió en "Pagar en partes": los pagos y con cuánto pagaron lo de efectivo (para el cambio).
typedef SplitResult = ({List<SalePayment> payments, int? cashReceived});

/// Divide [total] en [n] partes que suman exacto (los centavos que sobran van a las primeras).
List<int> equalParts(int total, int n) {
  final base = total ~/ n;
  final extra = total - base * n;
  return [for (var i = 0; i < n; i++) base + (i < extra ? 1 : 0)];
}

/// "Pagar en partes": varias personas pagan una parte igual, o un cliente paga una parte en efectivo y
/// otra con tarjeta o transferencia. Devuelve null si se cierra sin cobrar.
Future<SplitResult?> showSplitPaySheet(
  BuildContext context, {
  required int totalCents,
  SplitMode mode = SplitMode.iguales,
  List<PayMethod> methods = PayMethod.values,
}) => showGSheet<SplitResult>(
  context,
  (_) =>
      _SplitPaySheet(total: totalCents, initialMode: methods.length < 2 ? SplitMode.iguales : mode, methods: methods),
);

class _Part {
  _Part(this.method, [String amount = '']) : amount = TextEditingController(text: amount);

  PayMethod method;
  final TextEditingController amount;
}

class _SplitPaySheet extends StatefulWidget {
  const _SplitPaySheet({required this.total, required this.initialMode, required this.methods});

  final int total;
  final SplitMode initialMode;

  /// Formas de pago que acepta el negocio.
  final List<PayMethod> methods;

  @override
  State<_SplitPaySheet> createState() => _SplitPaySheetState();
}

class _SplitPaySheetState extends State<_SplitPaySheet> {
  late SplitMode _mode = widget.initialMode;

  // Partes iguales.
  int _people = 2;
  late List<PayMethod> _equalMethods = List.filled(_people, PayMethod.efectivo);

  // Montos libres: empieza con efectivo y tarjeta.
  late final List<_Part> _parts = [
    _Part(PayMethod.efectivo),
    _Part(widget.methods.length > 1 ? widget.methods[1] : PayMethod.efectivo),
  ];

  final _received = TextEditingController();
  String? _error;

  /// Mientras no se escriba a mano el último pago, se llena solo con lo que falta.
  bool _lastTouched = false;

  void _onAmount(int index) {
    if (index == _parts.length - 1) {
      _lastTouched = true;
    } else if (!_lastTouched) {
      final others = [
        for (final (i, p) in _parts.indexed)
          if (i != _parts.length - 1) parseMoney(p.amount.text) ?? 0,
      ].fold(0, (a, c) => a + c);
      final left = widget.total - others;
      _parts.last.amount.text = left > 0 ? (left / 100).toStringAsFixed(2) : '';
    }
    setState(() => _error = null);
  }

  @override
  void dispose() {
    for (final p in _parts) {
      p.amount.dispose();
    }
    _received.dispose();
    super.dispose();
  }

  void _setPeople(int n) => setState(() {
    _people = n.clamp(2, 20);
    _equalMethods = [
      for (var i = 0; i < _people; i++) i < _equalMethods.length ? _equalMethods[i] : PayMethod.efectivo,
    ];
    _error = null;
  });

  List<SalePayment> get _payments => switch (_mode) {
    SplitMode.iguales => [
      for (final (i, cents) in equalParts(widget.total, _people).indexed)
        SalePayment(method: _equalMethods[i], amountCents: cents),
    ],
    SplitMode.libres => [
      for (final p in _parts)
        if ((parseMoney(p.amount.text) ?? 0) > 0)
          SalePayment(method: p.method, amountCents: parseMoney(p.amount.text)!),
    ],
  };

  int get _assigned => _payments.fold(0, (a, p) => a + p.amountCents);

  void _addPart() {
    final left = widget.total - _assigned;
    setState(() {
      _parts.add(_Part(PayMethod.efectivo, left > 0 ? (left / 100).toStringAsFixed(2) : ''));
      _lastTouched = false;
      _error = null;
    });
  }

  void _removePart(int i) {
    final p = _parts.removeAt(i);
    disposeAfterClose(p.amount);
    setState(() => _error = null);
  }

  void _done() {
    final payments = _payments;
    final assigned = _assigned;
    if (assigned != widget.total) {
      setState(
        () => _error = assigned < widget.total
            ? 'Faltan ${money(widget.total - assigned)} por repartir'
            : 'Sobran ${money(assigned - widget.total)}',
      );
      return;
    }
    final cash = payments.where((p) => p.method == PayMethod.efectivo).fold(0, (a, p) => a + p.amountCents);
    final received = cash == 0 ? null : parseMoney(_received.text);
    if (received != null && received < cash) {
      setState(() => _error = 'Con eso no alcanza para lo de efectivo (${money(cash)})');
      return;
    }
    Navigator.of(context).pop<SplitResult>((payments: payments, cashReceived: received));
  }

  Widget _methodChips(PayMethod selected, ValueChanged<PayMethod> onPick) => widget.methods.length < 2
      ? const SizedBox.shrink()
      : Row(
          children: [
            for (final (i, m) in widget.methods.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: GChip(label: m.short, selected: selected == m, onTap: () => onPick(m)),
              ),
            ],
          ],
        );

  @override
  Widget build(BuildContext context) {
    final payments = _payments;
    final assigned = _assigned;
    final left = widget.total - assigned;
    final cash = payments.where((p) => p.method == PayMethod.efectivo).fold(0, (a, p) => a + p.amountCents);
    final received = parseMoney(_received.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('Pagar en partes', caption: 'Total ${money(widget.total)}'),
        if (widget.methods.length > 1)
          Row(
            children: [
              Expanded(
                child: GChip(
                  label: 'Partes iguales',
                  selected: _mode == SplitMode.iguales,
                  onTap: () => setState(() {
                    _mode = SplitMode.iguales;
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GChip(
                  label: 'Varios métodos',
                  selected: _mode == SplitMode.libres,
                  onTap: () => setState(() {
                    _mode = SplitMode.libres;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        if (_mode == SplitMode.iguales) ...[
          Row(
            children: [
              Expanded(
                child: Text('¿Entre cuántos?', style: GText.sans(size: 14, weight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                tooltip: 'Menos',
                onPressed: _people > 2 ? () => _setPeople(_people - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$_people',
                  textAlign: TextAlign.center,
                  style: GText.figures(size: 22, weight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Más',
                onPressed: _people < 20 ? () => _setPeople(_people + 1) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cada quien paga ${money(equalParts(widget.total, _people).first)}'
            '${widget.total % _people == 0 ? '' : ' (los centavos que sobran van en las primeras partes)'}.',
            style: GText.muted(size: 13),
          ),
          const SizedBox(height: 10),
          for (final (i, cents) in equalParts(widget.total, _people).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Parte ${i + 1}', style: GText.sans(size: 14, weight: FontWeight.w700)),
                      const Spacer(),
                      Text(money(cents), style: GText.figures(size: 15, weight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _methodChips(_equalMethods[i], (m) => setState(() => _equalMethods[i] = m)),
                ],
              ),
            ),
        ] else ...[
          for (final (i, p) in _parts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: p.amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: const [MoneyInputFormatter()],
                          onChanged: (_) => _onAmount(i),
                          style: GText.amount(size: 20),
                          decoration: InputDecoration(
                            labelText: 'Pago ${i + 1}',
                            prefixText: '\$ ',
                            hintText: i == _parts.length - 1 && left > 0 ? (left / 100).toStringAsFixed(2) : '0.00',
                          ),
                        ),
                      ),
                      if (_parts.length > 2)
                        IconButton(
                          tooltip: 'Quitar este pago',
                          onPressed: () => _removePart(i),
                          icon: const Icon(Icons.close_rounded, color: GColors.tintaTenue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _methodChips(p.method, (m) => setState(() => p.method = m)),
                ],
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _parts.length < 6 ? _addPart : null,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Otro pago'),
              ),
              const Spacer(),
              Text(
                left == 0
                    ? 'Completo'
                    : left > 0
                    ? 'Faltan ${money(left)}'
                    : 'Sobran ${money(-left)}',
                style: GText.sans(
                  size: 13.5,
                  weight: FontWeight.w800,
                  color: left == 0 ? GColors.cenote : GColors.rojo,
                ),
              ),
            ],
          ),
        ],
        if (cash > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _received,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Con cuánto pagan',
                    prefixText: '\$ ',
                    helperText: 'En efectivo son ${money(cash)}. Opcional, para el cambio',
                    helperMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Cambio', style: GText.muted(size: 12)),
                  Text(money(received == null || received < cash ? 0 : received - cash), style: GText.amount(size: 20)),
                ],
              ),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.rojo),
            ),
          ),
        const SizedBox(height: 14),
        GButton(
          label: 'Cobrar ${money(widget.total)}',
          kind: GButtonKind.money,
          expand: true,
          big: true,
          onPressed: _done,
        ),
      ],
    );
  }
}
