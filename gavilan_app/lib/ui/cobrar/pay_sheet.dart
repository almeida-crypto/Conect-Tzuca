import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'customer_picker.dart';
import 'ticket_screen.dart';

/// Cobra la cuenta del mostrador o, con [orderId], la comanda de una mesa.
Future<void> showPaySheet(BuildContext context, {String? orderId}) =>
    showGSheet(context, (_) => _PaySheet(orderId: orderId));

/// Billetes que suele dar el cliente, mayores o iguales al total.
List<int> suggestedBills(int totalCents) {
  const bills = [2000, 5000, 10000, 20000, 50000, 100000];
  return bills.where((b) => b >= totalCents && b != totalCents).take(3).toList();
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({this.orderId});

  final String? orderId;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  PayMethod _method = PayMethod.efectivo;
  int? _received; // null = paga justo
  final _other = TextEditingController();
  final _otherFocus = FocusNode();
  bool _otherMode = false;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  void _finish({required SaleKind kind, String? customerId}) {
    final orderId = widget.orderId;
    final total = orderId == null ? ref.read(cartTotalProvider) : ref.read(storeProvider).totalOfOrder(orderId);
    int? received;
    if (kind == SaleKind.pagada && _method == PayMethod.efectivo) {
      received = _otherMode ? parseMoney(_other.text) : _received;
      if (received != null && received < total) {
        setState(() => _error = 'Lo recibido es menos que el total');
        return;
      }
      if (_otherMode && received == null) {
        setState(() => _error = 'Escribe con cuánto paga');
        return;
      }
    }
    final store = ref.read(storeProvider.notifier);
    final paid = received ?? (kind == SaleKind.pagada ? total : null);
    final Sale sale;
    if (orderId == null) {
      sale = store.checkout(
        lines: ref.read(cartProvider),
        kind: kind,
        method: _method,
        receivedCents: paid,
        customerId: customerId,
      );
      ref.read(cartProvider.notifier).clear();
    } else {
      sale = store.chargeOrder(orderId, kind: kind, method: _method, receivedCents: paid, customerId: customerId);
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => TicketScreen(saleId: sale.id)));
  }

  /// Teclado: Enter cobra; un número empieza "¿Con cuánto paga?" sin tener que tocar "Otro".
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    // Mientras se escribe en "Otro", ese campo se encarga (Enter cobra desde ahí).
    if (e is! KeyDownEvent || _otherFocus.hasFocus) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.f2) {
      _finish(kind: SaleKind.pagada);
      return KeyEventResult.handled;
    }
    // Las cifras se escriben aquí mismo en "Otro" (sin mover el cursor al campo, que en el navegador
    // podría perder la primera tecla).
    final ch = e.character;
    if (_method == PayMethod.efectivo && ch != null && RegExp(r'^[0-9.]$').hasMatch(ch)) {
      _setOther((_otherMode ? _other.text : '') + ch);
      return KeyEventResult.handled;
    }
    if (_otherMode && key == LogicalKeyboardKey.backspace && _other.text.isNotEmpty) {
      _setOther(_other.text.substring(0, _other.text.length - 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setOther(String text) => setState(() {
    _otherMode = true;
    _error = null;
    _other.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  /// Tocar "Otro": abre el monto con el cursor listo para escribir.
  void _startOther() {
    setState(() {
      _otherMode = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otherFocus.requestFocus();
    });
  }

  Future<void> _fiar() async {
    final customer = await pickCustomerForCredit(context, ref);
    if (customer == null || !mounted) return;
    _finish(kind: SaleKind.fiada, customerId: customer.id);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.orderId == null
        ? ref.watch(cartTotalProvider)
        : ref.watch(storeProvider.select((s) => s.totalOfOrder(widget.orderId!)));
    final received = _otherMode ? parseMoney(_other.text) : _received;
    final change = (_method == PayMethod.efectivo && received != null) ? received - total : 0;

    final keyboard = MediaQuery.sizeOf(context).width >= 900;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('Cobrar', caption: 'Total a cobrar'),
          Text(money(total), style: GText.amount(size: 40)),
          const SizedBox(height: 14),
          Text('Forma de pago', style: GText.sans(size: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final m in PayMethod.values) ...[
                Expanded(
                  child: GChip(
                    label: m.short,
                    selected: _method == m,
                    onTap: () => setState(() {
                      _method = m;
                      _error = null;
                    }),
                  ),
                ),
                if (m != PayMethod.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
          if (_method == PayMethod.efectivo) ...[
            const SizedBox(height: 14),
            Text('¿Con cuánto paga?', style: GText.sans(size: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: GChip(
                    label: 'Justo',
                    selected: !_otherMode && _received == null,
                    onTap: () => setState(() {
                      _otherMode = false;
                      _received = null;
                      _error = null;
                    }),
                  ),
                ),
                for (final b in suggestedBills(total)) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: GChip(
                      label: money(b, hideZeroCents: true),
                      selected: !_otherMode && _received == b,
                      onTap: () => setState(() {
                        _otherMode = false;
                        _received = b;
                        _error = null;
                      }),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: GChip(label: 'Otro', selected: _otherMode, onTap: _startOther),
                ),
              ],
            ),
            if (_otherMode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _other,
                focusNode: _otherFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _finish(kind: SaleKind.pagada),
                decoration: const InputDecoration(hintText: '250', prefixText: '\$ '),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: GColors.linea),
                  bottom: BorderSide(color: GColors.linea),
                ),
              ),
              child: Row(
                children: [
                  Text('Cambio', style: GText.sans(size: 14)),
                  const Spacer(),
                  Text(
                    money(change < 0 ? 0 : change),
                    style: GText.amount(size: 24, color: change < 0 ? GColors.rojo : GColors.tinta),
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
          const SizedBox(height: 14),
          Row(
            children: [
              GButton(label: 'Fiar', kind: GButtonKind.outline, icon: Icons.menu_book_outlined, onPressed: _fiar),
              const SizedBox(width: 8),
              Expanded(
                child: GButton(
                  label: _method == PayMethod.efectivo
                      ? 'Cobrar en efectivo'
                      : 'Cobrar con ${_method.label.toLowerCase()}',
                  kind: GButtonKind.money,
                  expand: true,
                  big: true,
                  onPressed: () => _finish(kind: SaleKind.pagada),
                ),
              ),
            ],
          ),
          if (keyboard)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _method == PayMethod.efectivo
                    ? 'Escribe con cuánto paga y da Enter para cobrar'
                    : 'Da Enter para cobrar',
                textAlign: TextAlign.center,
                style: GText.muted(size: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
