import 'package:flutter/foundation.dart';
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
import '../cobrar/customer_picker.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';
import 'module_widgets.dart';

/// Apartados: el cliente deja anticipo, abona y liquida antes de la fecha límite.
class LayawaysScreen extends ConsumerStatefulWidget {
  const LayawaysScreen({super.key});

  @override
  ConsumerState<LayawaysScreen> createState() => _LayawaysScreenState();
}

class _LayawaysScreenState extends ConsumerState<LayawaysScreen> {
  LayawayStatus _filter = LayawayStatus.activo;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final now = DateTime.now();
    final list = store.layaways.where((l) => l.status == _filter).toList()
      ..sort((a, b) {
        final da = a.dueDate ?? DateTime(2100), db = b.dueDate ?? DateTime(2100);
        return da.compareTo(db);
      });
    final pendingTotal = store.layaways
        .where((l) => l.status == LayawayStatus.activo)
        .fold(0, (a, l) => a + store.pendingOfLayaway(l.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Apartados', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GButton(
                label: 'Nuevo apartado',
                icon: Icons.add,
                expand: true,
                onPressed: () => showGSheet(context, (_) => const _NewLayawaySheet()),
              ),
            ),
            if (pendingTotal > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text('Por cobrar en apartados: ${money(pendingTotal)}', style: GText.sans(size: 13.5)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  for (final (s, label) in [
                    (LayawayStatus.activo, 'Activos'),
                    (LayawayStatus.liquidado, 'Liquidados'),
                    (LayawayStatus.cancelado, 'Cancelados'),
                  ]) ...[
                    Expanded(
                      child: GChip(label: label, selected: _filter == s, onTap: () => setState(() => _filter = s)),
                    ),
                    if (s != LayawayStatus.cancelado) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            if (list.isEmpty)
              EmptyInvite(
                title: _filter == LayawayStatus.activo ? 'Sin apartados activos' : 'Nada por aquí',
                body: _filter == LayawayStatus.activo
                    ? 'Cuando un cliente deje un anticipo por una prenda o un artículo, regístralo aquí '
                          'y lleva sus abonos hasta que lo liquide.'
                    : 'Aquí aparecen los apartados que ya terminaron.',
              ),
            for (final l in list) _LayawayRow(layaway: l, now: now),
          ],
        ),
      ),
    );
  }
}

class _LayawayRow extends ConsumerWidget {
  const _LayawayRow({required this.layaway, required this.now});

  final Layaway layaway;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final customer = store.customerById(layaway.customerId);
    final paid = store.paidOfLayaway(layaway.id);
    final pending = store.pendingOfLayaway(layaway.id);
    final overdue =
        layaway.status == LayawayStatus.activo &&
        layaway.dueDate != null &&
        layaway.dueDate!.isBefore(now) &&
        pending > 0;
    return InkWell(
      onTap: () => showGSheet(context, (_) => _LayawayDetail(layawayId: layaway.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: overdue ? GColors.rojo : GColors.izamal, width: 3),
            bottom: const BorderSide(color: GColors.linea),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(customer?.name ?? 'Cliente', style: GText.sans(size: 14, weight: FontWeight.w800)),
                ),
                Text(
                  layaway.status == LayawayStatus.activo ? 'Debe ${money(pending, hideZeroCents: true)}' : '',
                  style: GText.amount(size: 15),
                ),
              ],
            ),
            Row(
              children: [
                if (store.photoOfLayaway(layaway) case final photo?) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(photo, width: 22, height: 22, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    layaway.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.muted(size: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressStrip(fraction: layaway.totalCents == 0 ? 1 : paid / layaway.totalCents, height: 7),
            if (layaway.dueDate != null && layaway.status == LayawayStatus.activo) ...[
              const SizedBox(height: 4),
              Text(
                dueLabel(layaway.dueDate!, now),
                style: GText.sans(size: 11.5, color: overdue ? GColors.rojo : GColors.tintaSuave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewLayawaySheet extends ConsumerStatefulWidget {
  const _NewLayawaySheet();

  @override
  ConsumerState<_NewLayawaySheet> createState() => _NewLayawaySheetState();
}

class _NewLayawaySheetState extends ConsumerState<_NewLayawaySheet> {
  final _description = TextEditingController();
  final _total = TextEditingController();
  final _deposit = TextEditingController();
  Customer? _customer;
  DateTime? _due = DateTime.now().add(const Duration(days: 30));
  PayMethod _method = PayMethod.efectivo;
  Uint8List? _photo;
  final _errors = <String, String>{};

  @override
  void dispose() {
    _description.dispose();
    _total.dispose();
    _deposit.dispose();
    super.dispose();
  }

  void _save() {
    final total = parseMoney(_total.text);
    final deposit = _deposit.text.trim().isEmpty ? 0 : parseMoney(_deposit.text);
    setState(() {
      _errors.clear();
      if (_customer == null) _errors['customer'] = 'Elige el cliente';
      if (_description.text.trim().isEmpty) _errors['description'] = 'Escribe qué se aparta';
      if (total == null || total == 0) _errors['total'] = 'Escribe el precio';
      if (deposit == null) _errors['deposit'] = 'Monto no válido';
      if (total != null && deposit != null && deposit > total) {
        _errors['deposit'] = 'El anticipo es mayor que el precio';
      }
    });
    if (_errors.isNotEmpty) return;
    ref
        .read(storeProvider.notifier)
        .addLayaway(
          customerId: _customer!.id,
          description: _description.text,
          totalCents: total!,
          dueDate: _due,
          depositCents: deposit!,
          method: _method,
          photo: _photo,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Nuevo apartado'),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: GColors.tinta,
            side: BorderSide(color: _errors['customer'] == null ? GColors.linea : GColors.rojo),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GShape.radiusSmall)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () async {
            final c = await pickCustomer(context, title: '¿Quién aparta?');
            if (c != null) {
              setState(() {
                _customer = c;
                _errors.remove('customer');
              });
            }
          },
          icon: const Icon(Icons.person_outline),
          label: Text(_customer?.name ?? 'Elegir cliente', style: GText.sans(size: 15)),
        ),
        if (_errors['customer'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_errors['customer']!, style: GText.sans(size: 12, color: GColors.rojo)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: '¿Qué se aparta?',
            hintText: 'Vestido azul talla M',
            errorText: _errors['description'],
          ),
        ),
        if (ref.watch(planProvider).limits.photos) ...[
          const SizedBox(height: 10),
          _PhotoField(
            photo: _photo,
            onPick: () async {
              final choice = await pickPhoto(context, hasPhoto: _photo != null);
              if (choice != null && mounted) setState(() => _photo = choice.bytes);
            },
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MoneyField(controller: _total, label: 'Precio', error: _errors['total']),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneyField(controller: _deposit, label: 'Anticipo', hint: '0', error: _errors['deposit']),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PayMethodChips(selected: _method, onPick: (m) => setState(() => _method = m)),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(
            _due == null ? 'Sin fecha límite' : 'Fecha límite: ${dayLabel(_due!)}',
            style: GText.sans(size: 14),
          ),
          trailing: _due == null
              ? null
              : IconButton(
                  tooltip: 'Quitar fecha',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _due = null),
                ),
          onTap: () async {
            final d = await pickDay(context, initial: _due, first: DateTime.now());
            if (d != null) setState(() => _due = d);
          },
        ),
        const SizedBox(height: 8),
        GButton(label: 'Guardar apartado', expand: true, big: true, onPressed: _save),
      ],
    );
  }
}

/// Detalle: abonos, comprobante por WhatsApp y cancelación.
class _LayawayDetail extends ConsumerStatefulWidget {
  const _LayawayDetail({required this.layawayId});

  final String layawayId;

  @override
  ConsumerState<_LayawayDetail> createState() => _LayawayDetailState();
}

class _LayawayDetailState extends ConsumerState<_LayawayDetail> {
  final _amount = TextEditingController();
  PayMethod _method = PayMethod.efectivo;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pay(int pending) {
    final cents = parseMoney(_amount.text);
    if (cents == null || cents == 0) {
      setState(() => _error = 'Escribe cuánto abona');
      return;
    }
    if (cents > pending) {
      setState(() => _error = 'Es más de lo que debe (${money(pending)})');
      return;
    }
    ref.read(storeProvider.notifier).addLayawayPayment(widget.layawayId, cents, _method);
    _amount.clear();
    setState(() => _error = null);
  }

  String _receipt(StoreState store, Layaway l, Customer? c) {
    final paid = store.paidOfLayaway(l.id);
    final pending = store.pendingOfLayaway(l.id);
    final b = StringBuffer()
      ..writeln('*${store.businessName}*')
      ..writeln('Comprobante de apartado')
      ..writeln('')
      ..writeln('Cliente: ${c?.name ?? ''}')
      ..writeln('Artículo: ${l.description}')
      ..writeln('Precio: ${money(l.totalCents)}');
    for (final p in store.paymentsOfLayaway(l.id)) {
      b.writeln('${dateTimeLabel(p.createdAt)}  ${_paymentKind(l, p).toLowerCase()} ${money(p.amountCents)}');
    }
    b
      ..writeln('')
      ..writeln('*Pagado: ${money(paid)}*');
    if (l.status == LayawayStatus.liquidado || pending == 0) {
      b.writeln('*LIQUIDADO*. ¡Gracias!');
    } else {
      b.writeln('*Resta: ${money(pending)}*');
      if (l.dueDate != null) b.writeln('Fecha límite: ${dayLabel(l.dueDate!)}');
    }
    return b.toString().trimRight();
  }

  Future<void> _changePhoto() async {
    final l = ref.read(storeProvider).layawayById(widget.layawayId)!;
    final choice = await pickPhoto(context, hasPhoto: l.photoPath != null);
    if (choice == null || !mounted) return;
    ref.read(storeProvider.notifier).setLayawayPhoto(widget.layawayId, choice.bytes);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el apartado?'),
        content: Text(
          'El artículo vuelve a estar disponible. Lo abonado queda registrado; '
          'si devuelves dinero, anótalo como gasto en la caja.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Cancelar apartado',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(storeProvider.notifier).cancelLayaway(widget.layawayId);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final l = store.layawayById(widget.layawayId)!;
    final c = store.customerById(l.customerId);
    final paid = store.paidOfLayaway(l.id);
    final pending = store.pendingOfLayaway(l.id);
    final active = l.status == LayawayStatus.activo;
    final photo = store.photoOfLayaway(l);
    final canPhoto = active && ref.watch(planProvider).limits.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(l.description, caption: c?.name ?? 'Cliente'),
        if (photo != null) ...[
          GestureDetector(
            onTap: () => showPhotoViewer(context, photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GShape.radiusSmall),
              child: Image.memory(photo, height: 170, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          if (canPhoto)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _changePhoto,
                icon: const Icon(Icons.photo_camera_outlined, size: 16),
                label: Text('Cambiar foto', style: GText.sans(size: 12.5, color: GColors.marca)),
              ),
            )
          else
            const SizedBox(height: 10),
        ] else if (l.photoPath != null) ...[
          // Otro celular la tomó y todavía no baja: llega al respaldar.
          Text('La foto se baja al respaldar', style: GText.muted(size: 12.5)),
          const SizedBox(height: 10),
        ] else if (canPhoto)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _changePhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text('Agregar foto del artículo', style: GText.sans(size: 13, color: GColors.marca)),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'RESTA' : (l.status == LayawayStatus.liquidado ? 'LIQUIDADO' : 'CANCELADO'),
                    style: GText.label(),
                  ),
                  Text(
                    money(active ? pending : paid),
                    style: GText.amount(size: 30, color: active ? GColors.marca : GColors.cenote),
                  ),
                ],
              ),
            ),
            Text('Pagado ${money(paid)}\nde ${money(l.totalCents)}', textAlign: TextAlign.right, style: GText.muted()),
          ],
        ),
        const SizedBox(height: 8),
        ProgressStrip(fraction: l.totalCents == 0 ? 1 : paid / l.totalCents, height: 12),
        if (l.dueDate != null && active) ...[
          const SizedBox(height: 6),
          Text('Fecha límite: ${dayLabel(l.dueDate!)} · ${dueLabel(l.dueDate!, DateTime.now())}', style: GText.muted()),
        ],
        const SizedBox(height: 10),
        for (final p in store.paymentsOfLayaway(l.id))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Text(dateTimeLabel(p.createdAt), style: GText.figures(size: 11, color: GColors.tintaSuave)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_paymentKind(l, p)} (${p.method.label.toLowerCase()})',
                    style: GText.sans(size: 13, weight: FontWeight.w400),
                  ),
                ),
                Text(money(p.amountCents), style: GText.figures(size: 12, color: GColors.cenote)),
              ],
            ),
          ),
        if (active) ...[
          const SizedBox(height: 12),
          MoneyField(
            controller: _amount,
            label: 'Abono',
            error: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          PayMethodChips(selected: _method, onPick: (m) => setState(() => _method = m)),
          const SizedBox(height: 10),
          GButton(label: 'Registrar abono', kind: GButtonKind.money, expand: true, onPressed: () => _pay(pending)),
        ],
        const SizedBox(height: 8),
        GButton(
          label: 'Mandar comprobante',
          icon: Icons.send_outlined,
          kind: GButtonKind.outline,
          expand: true,
          onPressed: () => photo == null
              ? shareText(context, _receipt(store, l, c))
              : shareTextWithImage(context, _receipt(store, l, c), photo, fileName: 'apartado.jpg'),
        ),
        if (active)
          TextButton(
            onPressed: _cancel,
            child: Text('Cancelar apartado', style: GText.sans(size: 13.5, color: GColors.rojo)),
          ),
      ],
    );
  }
}

String _paymentKind(Layaway l, LayawayPayment p) => p.createdAt == l.createdAt ? 'Anticipo' : 'Abono';

/// Foto opcional al dar de alta el apartado: para que no haya dudas de cuál artículo es.
class _PhotoField extends StatelessWidget {
  const _PhotoField({required this.photo, required this.onPick});

  final Uint8List? photo;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(GShape.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: GColors.linea),
          borderRadius: BorderRadius.circular(GShape.radiusSmall),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: photo == null
                  ? Container(
                      width: 52,
                      height: 52,
                      color: GColors.hundido,
                      child: const Icon(Icons.add_a_photo_outlined, color: GColors.tintaSuave),
                    )
                  : Image.memory(photo!, width: 52, height: 52, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo == null ? 'Foto del artículo' : 'Foto lista',
                    style: GText.sans(size: 14, weight: FontWeight.w700),
                  ),
                  Text(
                    photo == null ? 'Opcional: para saber cuál es cuando vengan a pagar' : 'Toca para cambiarla',
                    style: GText.muted(size: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
