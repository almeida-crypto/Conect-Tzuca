import '../../core/limits.dart';

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
import '../fiados/credit_limit.dart';
import 'customer_picker.dart';
import 'split_pay_sheet.dart';
import '../restaurant/split_items_sheet.dart';
import 'ticket_screen.dart';

/// Cobra la cuenta del mostrador o, con [orderId], la comanda de una mesa. Con [items], solo esos
/// platillos de la mesa (cuenta dividida por platillos: cuántas piezas de cada uno).
Future<void> showPaySheet(BuildContext context, {String? orderId, Map<String, double>? items}) =>
    showGSheet(context, (_) => _PaySheet(orderId: orderId, items: items));

/// Billetes que suele dar el cliente, mayores o iguales al total.
List<int> suggestedBills(int totalCents) {
  const bills = [2000, 5000, 10000, 20000, 50000, 100000];
  return bills.where((b) => b >= totalCents && b != totalCents).take(3).toList();
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({this.orderId, this.items});

  final String? orderId;
  final Map<String, double>? items;

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

  /// Descuento a toda la cuenta, en centavos.
  int _discount = 0;

  int _subtotal() => _subtotalOf(ref.read(storeProvider), ref.read(cartTotalProvider));

  /// Lo que se cobra: el carrito, lo que falta de la mesa o solo los platillos elegidos.
  int _subtotalOf(StoreState store, int cartTotal) {
    final orderId = widget.orderId;
    if (orderId == null) return cartTotal;
    final items = widget.items;
    if (items == null) return store.totalOfOrder(orderId);
    return [
      for (final i in store.itemsOfOrder(orderId))
        if (items.containsKey(i.id)) (i.unitWithExtrasCents * items[i.id]!.clamp(0, i.dueQty)).round(),
    ].fold(0, (a, c) => a + c);
  }

  Future<void> _askDiscount() async {
    final cents = await showDiscountDialog(context, subtotalCents: _subtotal(), currentCents: _discount);
    if (cents != null && mounted) {
      setState(() {
        _discount = cents;
        _received = null;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _other.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  void _finish({required SaleKind kind, String? customerId, List<SalePayment> payments = const [], int? cashReceived}) {
    final orderId = widget.orderId;
    final total = (_subtotal() - _discount).clamp(0, _subtotal());
    int? received = cashReceived;
    if (kind == SaleKind.pagada && payments.isEmpty && _method == PayMethod.efectivo) {
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
    final paid = payments.isNotEmpty ? received : received ?? (kind == SaleKind.pagada ? total : null);
    final Sale sale;
    if (orderId == null) {
      sale = store.checkout(
        lines: ref.read(cartProvider),
        kind: kind,
        method: _method,
        receivedCents: paid,
        customerId: customerId,
        discountCents: _discount,
        payments: payments,
      );
      ref.read(cartProvider.notifier).clear();
    } else if (widget.items != null) {
      final charged = store.chargeOrderItems(
        orderId,
        widget.items!,
        kind: kind,
        method: _method,
        receivedCents: paid,
        customerId: customerId,
        discountCents: _discount,
        payments: payments,
      );
      if (charged == null) {
        setState(() => _error = 'Esos platillos ya se cobraron');
        return;
      }
      sale = charged;
    } else {
      sale = store.chargeOrder(
        orderId,
        kind: kind,
        method: _method,
        receivedCents: paid,
        customerId: customerId,
        discountCents: _discount,
        payments: payments,
      );
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
      final next = (_otherMode ? _other.text : '') + ch;
      final ok = const MoneyInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: next));
      if (ok.text == next) _setOther(next);
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

  /// Pagar en partes (iguales o con varios métodos).
  Future<void> _split(int totalCents, SplitMode mode) async {
    final methods = ref.read(storeProvider).acceptedMethods;
    final result = await showSplitPaySheet(
      context,
      totalCents: totalCents,
      mode: methods.length < 2 ? SplitMode.iguales : mode,
      methods: methods,
    );
    if (result == null || !mounted) return;
    _finish(kind: SaleKind.pagada, payments: result.payments, cashReceived: result.cashReceived);
  }

  /// En una mesa: por platillos, en partes iguales o con varios métodos.
  Future<void> _divide(int totalCents) async {
    // En el mostrador o si ya se eligieron platillos: solo partes iguales o varios métodos.
    if (widget.orderId == null || widget.items != null) return _split(totalCents, SplitMode.libres);
    final mixed = ref.read(storeProvider).acceptedMethods.length > 1;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, icon, title, sub) in const [
              (
                'platillos',
                Icons.restaurant_menu_rounded,
                'Por platillos',
                'Cada quien paga lo que comió, con su ticket',
              ),
              ('iguales', Icons.groups_rounded, 'Partes iguales', 'El total entre varias personas'),
              ('libres', Icons.payments_outlined, 'Varios métodos', 'Una parte en efectivo y otra con tarjeta'),
            ].where((o) => mixed || o.$1 != 'libres'))
              ListTile(
                leading: Icon(icon, color: GColors.cenote),
                title: Text(title, style: GText.sans(size: 15, weight: FontWeight.w700)),
                subtitle: Text(sub, style: GText.muted(size: 12.5)),
                onTap: () => Navigator.of(ctx).pop(key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'platillos':
        final navigator = Navigator.of(context);
        final orderId = widget.orderId!;
        navigator.pop();
        await showSplitByItemsSheet(navigator.context, orderId: orderId);
      case 'iguales':
        await _split(totalCents, SplitMode.iguales);
      default:
        await _split(totalCents, SplitMode.libres);
    }
  }

  Future<void> _fiar(int totalCents) async {
    final customer = await pickCustomerForCredit(context, ref);
    if (customer == null || !mounted) return;
    // Si se pasa de su tope: aviso y, para un cajero, el PIN del dueño o un encargado.
    if (!await confirmCreditLimit(context, ref, customer, totalCents) || !mounted) return;
    _finish(kind: SaleKind.fiada, customerId: customer.id);
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _subtotalOf(ref.watch(storeProvider), ref.watch(cartTotalProvider));
    final total = (subtotal - _discount).clamp(0, subtotal);
    final received = _otherMode ? parseMoney(_other.text) : _received;
    final change = (_method == PayMethod.efectivo && received != null) ? received - total : 0;

    final keyboard = MediaQuery.sizeOf(context).width >= 900;
    final methods = ref.watch(storeProvider).acceptedMethods;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Cobrar', caption: widget.items == null ? 'Total a cobrar' : 'Sus platillos'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(money(total), style: GText.amount(size: 40))),
              TextButton.icon(
                onPressed: _askDiscount,
                icon: Icon(
                  _discount > 0 ? Icons.edit_rounded : Icons.sell_outlined,
                  size: 18,
                  color: GColors.tintaSuave,
                ),
                label: Text(
                  _discount > 0 ? 'Cambiar descuento' : 'Descuento',
                  style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.tintaSuave),
                ),
              ),
            ],
          ),
          if (_discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Productos ${money(subtotal)}  ·  '),
                    TextSpan(
                      text: 'Descuento -${money(_discount)}',
                      style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.cenote),
                    ),
                  ],
                ),
                style: GText.muted(size: 13),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(methods.length < 2 ? 'Solo efectivo' : 'Forma de pago', style: GText.sans(size: 12)),
              ),
              TextButton.icon(
                onPressed: total > 0 ? () => _divide(total) : null,
                icon: const Icon(Icons.call_split_rounded, size: 18, color: GColors.cenote),
                label: Text(
                  widget.orderId == null ? 'Pagar en partes' : 'Dividir la cuenta',
                  style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.cenote),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          PayMethodChips(
            selected: _method,
            onPick: (m) => setState(() {
              _method = m;
              _error = null;
            }),
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
                inputFormatters: const [MoneyInputFormatter()],
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
              GButton(
                label: 'Fiar',
                kind: GButtonKind.outline,
                icon: Icons.menu_book_outlined,
                onPressed: () => _fiar(total),
              ),
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

/// Pide un descuento en porcentaje o en pesos. Devuelve los centavos a descontar (0 para quitarlo),
/// o null si se canceló.
Future<int?> showDiscountDialog(BuildContext context, {required int subtotalCents, int currentCents = 0}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _DiscountDialog(subtotalCents: subtotalCents, currentCents: currentCents),
    );

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.subtotalCents, required this.currentCents});

  final int subtotalCents;
  final int currentCents;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  // El campo vive lo mismo que el diálogo: se libera al cerrarse por completo, no antes.
  late final _field = TextEditingController(text: widget.currentCents == 0 ? '' : centsInput(widget.currentCents));
  late bool _percent = widget.currentCents == 0;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int? _cents() {
    final text = _field.text.trim();
    if (text.isEmpty) return 0;
    if (_percent) {
      final p = double.tryParse(text);
      if (p == null || p < 0 || p > 100) return null;
      return (widget.subtotalCents * p / 100).round();
    }
    final c = parseMoney(text);
    return c == null || c > widget.subtotalCents ? null : c;
  }

  void _mode(bool percent) => setState(() {
    _percent = percent;
    _field.clear();
  });

  @override
  Widget build(BuildContext context) {
    final value = _cents();
    return AlertDialog(
      title: Text('Descuento', style: GText.sans(size: 18, weight: FontWeight.w800)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: GChip(label: 'Porcentaje', selected: _percent, onTap: () => _mode(true)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GChip(label: 'Pesos', selected: !_percent, onTap: () => _mode(false)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_percent)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in const [5, 10, 15, 20])
                    GChip(label: '$p%', selected: _field.text == '$p', onTap: () => setState(() => _field.text = '$p')),
                ],
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _percent ? const [QtyInputFormatter()] : const [MoneyInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: _percent ? null : '\$ ',
                suffixText: _percent ? '%' : null,
                hintText: _percent ? '10' : '20',
                errorText: value == null ? (_percent ? 'Entre 0 y 100' : 'No puede ser más que la cuenta') : null,
              ),
            ),
            const SizedBox(height: 12),
            if (value != null)
              Text(
                'Se descuentan ${money(value)} · queda ${money(widget.subtotalCents - value)}',
                style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.cenote),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.currentCents > 0)
          TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text('Quitar descuento')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: value == null ? null : () => Navigator.of(context).pop(value),
          child: Text(
            'Aplicar',
            style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.cenote),
          ),
        ),
      ],
    );
  }
}
