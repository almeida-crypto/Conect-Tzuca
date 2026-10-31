import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/ticket_text.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'module_widgets.dart';

/// Pacas y lotes: lo invertido, lo que se va cobrando y cuándo ya es ganancia.
class LotsScreen extends ConsumerWidget {
  const LotsScreen({super.key});

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final plan = ref.read(planProvider);
    final max = plan.limits.maxLots;
    if (max != null && ref.read(storeProvider).openLots.length >= max) {
      await showUpgradeSheet(
        context,
        reason:
            'En el plan ${plan.label} puedes llevar $max paca a la vez. '
            'Cierra la que ya terminaste o cambia de plan para llevar varias.',
        needed: Plan.emprendedor,
      );
      return;
    }
    if (!context.mounted) return;
    final lot = await showGSheet<Lot>(context, (_) => const _NewLotSheet());
    if (lot != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LotDetailScreen(lotId: lot.id)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final lots = [...store.lots]
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return b.startedAt.compareTo(a.startedAt);
      });
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        title: Text('Pacas y lotes', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: GButton(label: 'Nueva paca', icon: Icons.add, expand: true, onPressed: () => _new(context, ref)),
            ),
            if (lots.isEmpty)
              const EmptyInvite(
                title: 'Registra tu primera paca',
                body:
                    'Anota cuánto invertiste y, conforme vendas, cuánto cobraste. '
                    'Gavilán te dice cuánto falta para recuperar y desde cuándo ya es ganancia.',
              ),
            for (final lot in lots) _LotRow(lot: lot, recovered: store.recoveredOfLot(lot.id)),
          ],
        ),
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({required this.lot, required this.recovered});

  final Lot lot;
  final int recovered;

  @override
  Widget build(BuildContext context) {
    final missing = lot.investmentCents - recovered;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LotDetailScreen(lotId: lot.id))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.linea)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lot.name,
                    style: GText.sans(
                      size: 15,
                      weight: FontWeight.w800,
                      color: lot.isOpen ? GColors.tinta : GColors.tintaSuave,
                    ),
                  ),
                ),
                if (!lot.isOpen) Text('Cerrada', style: GText.muted()),
              ],
            ),
            const SizedBox(height: 6),
            ProgressStrip(fraction: lot.investmentCents == 0 ? 1 : recovered / lot.investmentCents),
            const SizedBox(height: 5),
            Text(
              missing > 0
                  ? 'Faltan ${money(missing)} para recuperar ${money(lot.investmentCents)}'
                  : 'Recuperada. Ganancia: ${money(-missing)}',
              style: GText.sans(size: 12.5, color: missing > 0 ? GColors.tintaSuave : GColors.monte),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewLotSheet extends ConsumerStatefulWidget {
  const _NewLotSheet();

  @override
  ConsumerState<_NewLotSheet> createState() => _NewLotSheetState();
}

class _NewLotSheetState extends ConsumerState<_NewLotSheet> {
  final _name = TextEditingController();
  final _investment = TextEditingController();
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _name.dispose();
    _investment.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parseMoney(_investment.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Ponle un nombre' : null;
      _amountError = (cents == null || cents == 0) ? 'Escribe cuánto invertiste' : null;
    });
    if (_nameError != null || _amountError != null) return;
    final lot = ref.read(storeProvider.notifier).addLot(_name.text, cents!);
    Navigator.of(context).pop(lot);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Nueva paca', caption: 'Lo que compraste de golpe'),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _nameError = null),
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Paca de ropa americana', errorText: _nameError),
        ),
        const SizedBox(height: 10),
        MoneyField(
          controller: _investment,
          label: '¿Cuánto invertiste?',
          error: _amountError,
          onChanged: (_) => setState(() => _amountError = null),
        ),
        const SizedBox(height: 14),
        GButton(label: 'Guardar paca', expand: true, big: true, onPressed: _save),
      ],
    );
  }
}

/// Una paca: barra de recuperación grande y registro rápido de ventas.
class LotDetailScreen extends ConsumerStatefulWidget {
  const LotDetailScreen({super.key, required this.lotId});

  final String lotId;

  @override
  ConsumerState<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends ConsumerState<LotDetailScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _sell() {
    final cents = parseMoney(_amount.text);
    if (cents == null || cents == 0) {
      setState(() => _error = 'Escribe cuánto cobraste');
      return;
    }
    ref.read(storeProvider.notifier).addLotSale(widget.lotId, cents, note: _note.text);
    _amount.clear();
    _note.clear();
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Venta de ${money(cents)} registrada')));
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar esta paca?'),
        content: Text(
          'Ya no podrás anotarle ventas. Queda guardada con su resultado.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cerrar paca')),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).closeLot(widget.lotId);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final lot = store.lots.firstWhere((l) => l.id == widget.lotId);
    final sales = store.salesOfLot(lot.id);
    final recovered = store.recoveredOfLot(lot.id);
    final missing = lot.investmentCents - recovered;
    final cashOpen = store.openSession != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.papel,
        surfaceTintColor: Colors.transparent,
        title: Text(lot.name, style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GColors.papelClaro,
                border: Border.all(color: GColors.linea),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(missing > 0 ? 'FALTA PARA RECUPERAR' : 'YA ES GANANCIA', style: GText.label()),
                  Text(
                    money(missing > 0 ? missing : -missing),
                    style: GText.amount(size: 38, color: missing > 0 ? GColors.oxido : GColors.monte),
                  ),
                  const SizedBox(height: 10),
                  ProgressStrip(fraction: lot.investmentCents == 0 ? 1 : recovered / lot.investmentCents, height: 16),
                  const SizedBox(height: 6),
                  Text(
                    'Cobrado ${money(recovered)} de ${money(lot.investmentCents)} invertidos · '
                    '${sales.length} ${sales.length == 1 ? 'venta' : 'ventas'}',
                    style: GText.muted(size: 12.5),
                  ),
                ],
              ),
            ),
            if (lot.isOpen) ...[
              const SizedBox(height: 18),
              Text('Vendí', style: GText.sans(size: 15, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              MoneyField(controller: _amount, error: _error, onChanged: (_) => setState(() => _error = null)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in [2000, 5000, 8000, 10000, 15000, 20000])
                    SizedBox(
                      width: 76,
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
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Nota (opcional): 2 blusas'),
              ),
              const SizedBox(height: 10),
              GButton(label: 'Registrar venta', kind: GButtonKind.money, expand: true, big: true, onPressed: _sell),
              const SizedBox(height: 6),
              Text(
                cashOpen
                    ? 'Entra en efectivo al corte de caja de hoy.'
                    : 'La caja está cerrada: esta venta no entra al corte.',
                style: GText.muted(),
              ),
            ],
            const SizedBox(height: 20),
            if (sales.isNotEmpty) Text('Ventas', style: GText.sans(size: 15, weight: FontWeight.w800)),
            for (final s in sales)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GColors.linea)),
                ),
                child: Row(
                  children: [
                    Text(dateTimeLabel(s.createdAt), style: GText.mono(size: 11, color: GColors.tintaSuave)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.note ?? '', style: GText.sans(size: 13, weight: FontWeight.w400)),
                    ),
                    Text(money(s.amountCents), style: GText.mono(size: 12.5)),
                  ],
                ),
              ),
            if (lot.isOpen) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _close,
                child: Text('Cerrar esta paca', style: GText.sans(size: 13.5, color: GColors.rojo)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
