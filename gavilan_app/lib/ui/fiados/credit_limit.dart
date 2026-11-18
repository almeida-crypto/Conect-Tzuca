import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../clerks/lock_screen.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Días sin abonar: ámbar desde 30, rojo desde 60.
const lateAmberDays = 30;
const lateRedDays = 60;

const _amber = Color(0xFFB27C00);

/// Color del atraso de un cliente (null = va bien).
Color? lateColor(int days) => days >= lateRedDays
    ? GColors.rojo
    : days >= lateAmberDays
    ? _amber
    : null;

/// Poner el tope de fiado: el general del negocio ([customerId] null) o el de un cliente.
Future<void> showCreditLimitSheet(BuildContext context, {String? customerId}) =>
    showGSheet<void>(context, (_) => _CreditLimitSheet(customerId: customerId));

class _CreditLimitSheet extends ConsumerStatefulWidget {
  const _CreditLimitSheet({this.customerId});

  final String? customerId;

  @override
  ConsumerState<_CreditLimitSheet> createState() => _CreditLimitSheetState();
}

class _CreditLimitSheetState extends ConsumerState<_CreditLimitSheet> {
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeProvider);
    final current = widget.customerId == null
        ? store.defaultCreditLimitCents
        : store.customerById(widget.customerId!)?.creditLimitCents;
    _amount = TextEditingController(text: current == null ? '' : (current / 100).toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save(int? cents) {
    final store = ref.read(storeProvider.notifier);
    if (widget.customerId == null) {
      store.setDefaultCreditLimit(cents);
    } else {
      store.setCustomerCreditLimit(widget.customerId!, cents);
    }
    Navigator.of(context).pop();
  }

  void _saveTyped() {
    final cents = parseMoney(_amount.text);
    if (cents == null) {
      setState(() => _error = 'Escribe hasta cuánto puede deber');
      return;
    }
    _save(cents);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final customer = widget.customerId == null ? null : store.customerById(widget.customerId!);
    final general = store.defaultCreditLimitCents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          customer == null ? 'Tope general' : 'Tope de ${customer.name}',
          caption: customer == null ? 'Para todos los clientes' : 'Lo más que puede deber',
        ),
        Text(
          customer == null
              ? 'Lo más que puede deber cada cliente. A quien quieras darle más (o menos), le pones su propio tope.'
              : general == null
              ? 'Si no le pones tope, puede deber lo que sea.'
              : 'Si no le pones uno propio, usa el general: ${money(general, hideZeroCents: true)}.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          style: GText.amount(size: 26),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _saveTyped(),
          decoration: InputDecoration(prefixText: '\$ ', hintText: '0', errorText: _error),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, v) in const [50000, 100000, 200000, 500000].indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: GChip(
                  label: money(v, hideZeroCents: true),
                  selected: parseMoney(_amount.text) == v,
                  onTap: () => setState(() {
                    _amount.text = (v / 100).toStringAsFixed(0);
                    _error = null;
                  }),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        GButton(label: 'Guardar tope', kind: GButtonKind.money, expand: true, onPressed: _saveTyped),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _save(null),
          child: Text(
            customer == null
                ? 'Sin tope general'
                : general == null
                ? 'Sin tope'
                : 'Usar el general',
            style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.tintaSuave),
          ),
        ),
      ],
    );
  }
}

/// Antes de fiar: si con esta venta el cliente se pasa de su tope, avisa. El dueño o un encargado pueden
/// seguir; un cajero necesita el PIN de alguno de ellos (si se usan PIN). true = se puede fiar.
Future<bool> confirmCreditLimit(BuildContext context, WidgetRef ref, Customer customer, int totalCents) async {
  final check = ref.read(storeProvider).creditCheck(customer.id, totalCents);
  if (!check.over) return true;
  final can = ref.read(permissionsProvider).manageCredit;
  final usesPins = ref.read(storeProvider).usesPins;
  final limit = money(check.limitCents!, hideZeroCents: true);
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: _amber),
      title: Text('${customer.name} se pasa de su tope'),
      content: Text(
        '${check.balanceCents > 0 ? 'Debe ${money(check.balanceCents)}' : 'No debe nada'} y su tope es $limit. '
        'Con esta venta quedaría en ${money(check.afterCents)}.'
        '${can
            ? ''
            : usesPins
            ? '\n\nPara fiarle de más, el dueño o un encargado pone su PIN.'
            : '\n\nPídele al dueño que le suba el tope.'}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No fiar')),
        if (can || usesPins)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(can ? 'Fiar de todos modos' : 'Pedir PIN'),
          ),
      ],
    ),
  );
  if (answer != true || !context.mounted) return false;
  if (can) return true;
  return allowOrAskPin(context, ref, allowed: (c) => c.manageCredit, action: 'Fiarle de más a ${customer.name}');
}
