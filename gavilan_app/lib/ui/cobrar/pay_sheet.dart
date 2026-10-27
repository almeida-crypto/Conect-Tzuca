import 'package:flutter/material.dart';
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

Future<void> showPaySheet(BuildContext context) => showGSheet(context, (_) => const _PaySheet());

/// Billetes que suele dar el cliente, mayores o iguales al total.
List<int> suggestedBills(int totalCents) {
  const bills = [2000, 5000, 10000, 20000, 50000, 100000];
  return bills.where((b) => b >= totalCents && b != totalCents).take(3).toList();
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet();

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  PayMethod _method = PayMethod.efectivo;
  int? _received; // null = paga justo
  final _other = TextEditingController();
  bool _otherMode = false;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _finish({required SaleKind kind, String? customerId}) {
    final total = ref.read(cartTotalProvider);
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
    final sale = ref
        .read(storeProvider.notifier)
        .checkout(
          lines: ref.read(cartProvider),
          kind: kind,
          method: _method,
          receivedCents: received ?? (kind == SaleKind.pagada ? total : null),
          customerId: customerId,
        );
    ref.read(cartProvider.notifier).clear();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => TicketScreen(saleId: sale.id)));
  }

  Future<void> _fiar() async {
    final customer = await pickCustomerForCredit(context, ref);
    if (customer == null || !mounted) return;
    _finish(kind: SaleKind.fiada, customerId: customer.id);
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final received = _otherMode ? parseMoney(_other.text) : _received;
    final change = (_method == PayMethod.efectivo && received != null) ? received - total : 0;

    return Column(
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
                child: GChip(
                  label: 'Otro',
                  selected: _otherMode,
                  onTap: () => setState(() {
                    _otherMode = true;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
          if (_otherMode) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _other,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
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
      ],
    );
  }
}
