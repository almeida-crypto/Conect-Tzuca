import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Elegir (o crear) a quién se le fía. Respeta el límite de deudores del plan.
Future<Customer?> pickCustomerForCredit(BuildContext context, WidgetRef ref) async {
  final picked = await showGSheet<Customer>(context, (_) => const _CustomerPicker());
  if (picked == null || !context.mounted) return null;
  final store = ref.read(storeProvider);
  final plan = ref.read(planProvider);
  final max = plan.limits.maxDebtors;
  final alreadyOwes = store.balanceOf(picked.id) > 0;
  if (max != null && !alreadyOwes && store.debtors.length >= max) {
    await showUpgradeSheet(
      context,
      reason:
          'Tu plan ${plan.label} permite hasta $max clientes con deuda al mismo tiempo. '
          'Cobra algún fiado o cambia de plan para fiarle a alguien más.',
      needed: Plan.emprendedor,
    );
    return null;
  }
  return picked;
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker();

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _q = '';
  bool _creating = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _create() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del cliente');
      return;
    }
    final c = ref.read(storeProvider.notifier).addCustomer(_name.text, phone: _phone.text);
    Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final q = _q.trim().toLowerCase();
    final list = store.customers.where((c) => q.isEmpty || c.name.toLowerCase().contains(q)).toList();

    if (_creating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('Nuevo cliente'),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'WhatsApp (opcional)', hintText: '997 123 4567'),
          ),
          const SizedBox(height: 14),
          GButton(label: 'Guardar y fiar', expand: true, onPressed: _create),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('¿A quién se le fía?'),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(hintText: 'Buscar cliente', prefixIcon: Icon(Icons.search, size: 20)),
        ),
        const SizedBox(height: 6),
        for (final c in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.name, style: GText.sans(size: 15, weight: FontWeight.w800)),
            subtitle: Text(
              store.balanceOf(c.id) > 0 ? 'Debe ${money(store.balanceOf(c.id))}' : 'Sin deuda',
              style: GText.muted(),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(c),
          ),
        const SizedBox(height: 8),
        GButton(
          label: 'Nuevo cliente',
          kind: GButtonKind.outline,
          icon: Icons.person_add_alt,
          expand: true,
          onPressed: () => setState(() {
            _creating = true;
            _name.text = _q;
          }),
        ),
        const SizedBox(height: 4),
        Text('Se registra como cargo en su cuenta de fiado.', style: GText.muted(), textAlign: TextAlign.center),
      ],
    );
  }
}
