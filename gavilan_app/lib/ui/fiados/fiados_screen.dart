import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/share.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Libreta digital de fiados.
class FiadosScreen extends ConsumerWidget {
  const FiadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(planProvider);
    final debtors = store.debtors;
    final now = DateTime.now();
    final max = plan.limits.maxDebtors;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenTitle(
          'Fiados',
          subtitle: max == null ? 'Quién te debe y desde cuándo' : '${debtors.length} de $max clientes con deuda',
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: GColors.tinta, width: 2),
              bottom: BorderSide(color: GColors.linea),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EN LA CALLE', style: GText.label()),
              const SizedBox(height: 2),
              Text(money(store.totalOnCreditCents), style: GText.amount(size: 34, color: GColors.rojo)),
            ],
          ),
        ),
        if (debtors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nadie te debe. Cuando fíes desde Cobrar, aquí aparece la cuenta de cada cliente.',
              textAlign: TextAlign.center,
              style: GText.muted(size: 14),
            ),
          ),
        for (final d in debtors) _DebtorRow(debtor: d, now: now),
        if (debtors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text('Raya roja: más de 2 semanas sin pagar.', style: GText.muted()),
          ),
      ],
    );
  }
}

class _DebtorRow extends ConsumerWidget {
  const _DebtorRow({required this.debtor, required this.now});

  final Debtor debtor;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final late = now.difference(debtor.since).inDays > 14;
    final business = ref.watch(storeProvider).businessName;
    return InkWell(
      onTap: () => showGSheet(context, (_) => _DebtorDetail(customerId: debtor.customer.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: late ? GColors.rojo : GColors.ocre, width: 3),
            bottom: const BorderSide(color: GColors.linea),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(debtor.customer.name, style: GText.sans(size: 14, weight: FontWeight.w800)),
                  Text(
                    debtor.entries.any((e) => e.type == CreditType.abono)
                        ? 'Último abono ${daysAgo(debtor.since, now)}'
                        : 'Debe desde ${daysAgo(debtor.since, now)}',
                    style: GText.muted(size: 11.5),
                  ),
                ],
              ),
            ),
            Text(money(debtor.balanceCents, hideZeroCents: true), style: GText.amount(size: 16)),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: GColors.tinta,
                side: const BorderSide(color: GColors.tinta),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => showAbonoSheet(context, debtor.customer.id),
              child: Text('Abonar', style: GText.sans(size: 12.5, weight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Recordar por WhatsApp',
              icon: const Icon(Icons.chat_outlined, color: GColors.monte),
              onPressed: () => shareText(
                context,
                reminderText(business: business, name: debtor.customer.name, balanceCents: debtor.balanceCents),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Historial de cargos y abonos de un cliente.
class _DebtorDetail extends ConsumerWidget {
  const _DebtorDetail({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final c = store.customerById(customerId)!;
    final entries = store.credit.where((e) => e.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final balance = store.balanceOf(customerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(c.name, caption: c.phone == null ? 'Cliente' : 'WhatsApp ${c.phone}'),
        Row(
          children: [
            Text('Saldo', style: GText.sans(size: 14)),
            const Spacer(),
            Text(money(balance), style: GText.amount(size: 26, color: balance > 0 ? GColors.rojo : GColors.monte)),
          ],
        ),
        const SizedBox(height: 10),
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Text(dateTimeLabel(e.createdAt), style: GText.mono(size: 11, color: GColors.tintaSuave)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.type == CreditType.cargo
                        ? 'Compra fiada'
                        : 'Abono${e.method == null ? '' : ' (${e.method!.label.toLowerCase()})'}',
                    style: GText.sans(size: 13, weight: FontWeight.w400),
                  ),
                ),
                Text(
                  '${e.type == CreditType.cargo ? '+' : '-'}${money(e.amountCents)}',
                  style: GText.mono(size: 12, color: e.type == CreditType.cargo ? GColors.rojo : GColors.monte),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (balance > 0)
          GButton(
            label: 'Registrar abono',
            kind: GButtonKind.money,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              showAbonoSheet(context, customerId);
            },
          ),
      ],
    );
  }
}

Future<void> showAbonoSheet(BuildContext context, String customerId) =>
    showGSheet(context, (_) => _AbonoSheet(customerId: customerId));

class _AbonoSheet extends ConsumerStatefulWidget {
  const _AbonoSheet({required this.customerId});

  final String customerId;

  @override
  ConsumerState<_AbonoSheet> createState() => _AbonoSheetState();
}

class _AbonoSheetState extends ConsumerState<_AbonoSheet> {
  final _amount = TextEditingController();
  PayMethod _method = PayMethod.efectivo;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save(int balance) {
    final cents = parseMoney(_amount.text);
    if (cents == null || cents == 0) {
      setState(() => _error = 'Escribe cuánto abona');
      return;
    }
    if (cents > balance) {
      setState(() => _error = 'Es más de lo que debe (${money(balance)})');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    ref.read(storeProvider.notifier).addAbono(widget.customerId, cents, _method);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Abono de ${money(cents)} registrado')));
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final c = store.customerById(widget.customerId)!;
    final balance = store.balanceOf(widget.customerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('Abono de ${c.name}', caption: 'Debe ${money(balance)}'),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GText.amount(size: 26),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(prefixText: '\$ ', hintText: '0.00', errorText: _error),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final v in [5000, 10000].where((v) => v < balance)) ...[
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
              const SizedBox(width: 6),
            ],
            Expanded(
              child: GChip(
                label: 'Todo',
                selected: parseMoney(_amount.text) == balance,
                onTap: () => setState(() {
                  _amount.text = (balance / 100).toStringAsFixed(2);
                  _error = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final m in PayMethod.values) ...[
              Expanded(
                child: GChip(label: m.short, selected: _method == m, onTap: () => setState(() => _method = m)),
              ),
              if (m != PayMethod.values.last) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        GButton(
          label: 'Guardar abono',
          kind: GButtonKind.money,
          expand: true,
          big: true,
          onPressed: () => _save(balance),
        ),
      ],
    );
  }
}
