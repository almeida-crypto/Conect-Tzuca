import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/share.dart';
import '../../core/ticket_text.dart';
import '../../domain/layaway_rules.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../cobrar/customer_picker.dart';
import '../inventario/product_search.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/photo_picker.dart';
import 'layaway_rules_screen.dart';
import 'module_widgets.dart';

/// En qué va cada apartado.
enum _Tab { activos, porEntregar, entregados, cancelados }

bool _inTab(Layaway l, _Tab t) => switch (t) {
  _Tab.activos => l.status == LayawayStatus.activo,
  _Tab.porEntregar => l.status == LayawayStatus.liquidado && !l.delivered,
  _Tab.entregados => l.status == LayawayStatus.liquidado && l.delivered,
  _Tab.cancelados => l.status == LayawayStatus.cancelado,
};

/// Apartados: el cliente deja anticipo, abona, liquida antes de la fecha límite y se lo lleva.
class LayawaysScreen extends ConsumerStatefulWidget {
  const LayawaysScreen({super.key});

  @override
  ConsumerState<LayawaysScreen> createState() => _LayawaysScreenState();
}

class _LayawaysScreenState extends ConsumerState<LayawaysScreen> {
  _Tab _filter = _Tab.activos;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final now = DateTime.now();
    final list = store.layaways.where((l) => _inTab(l, _filter)).toList()
      ..sort((a, b) {
        if (_filter == _Tab.activos) {
          final da = a.dueDate ?? DateTime(2100), db = b.dueDate ?? DateTime(2100);
          return da.compareTo(db);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    final pendingTotal = store.layaways
        .where((l) => l.status == LayawayStatus.activo)
        .fold(0, (a, l) => a + store.pendingOfLayaway(l.id));
    final reminders = [
      for (final l in store.layaways)
        if (reminderFor(
              l,
              pendingCents: store.pendingOfLayaway(l.id),
              lastPaymentAt: store.lastPaymentOfLayaway(l.id),
              now: now,
            )
            case final reason?)
          (layaway: l, reason: reason),
    ];
    final credits = [
      for (final c in store.customers)
        if (store.creditOf(c.id) case final cents when cents > 0) (customer: c, cents: cents),
    ];
    final counts = {for (final t in _Tab.values) t: store.layaways.where((l) => _inTab(l, t)).length};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Apartados', style: GText.sans(size: 17, weight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LayawayRulesScreen())),
            icon: const Icon(Icons.rule_rounded, size: 18),
            label: Text('Reglas', style: GText.sans(size: 13.5, color: GColors.marca)),
          ),
          const SizedBox(width: 6),
        ],
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
            if (reminders.isNotEmpty) _RemindersCard(reminders: reminders),
            if (credits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Text(
                  'Saldo a favor: ${credits.map((c) => '${c.customer.name} ${money(c.cents, hideZeroCents: true)}').join(' · ')}',
                  style: GText.sans(size: 13, color: GColors.cenoteOscuro),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(
                children: [
                  for (final pair in [
                    [(_Tab.activos, 'Activos'), (_Tab.porEntregar, 'Por entregar')],
                    [(_Tab.entregados, 'Entregados'), (_Tab.cancelados, 'Cancelados')],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          for (final (i, (t, label)) in pair.indexed) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: GChip(
                                label: counts[t]! > 0 && (t == _Tab.activos || t == _Tab.porEntregar)
                                    ? '$label (${counts[t]})'
                                    : label,
                                selected: _filter == t,
                                onTap: () => setState(() => _filter = t),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (list.isEmpty)
              EmptyInvite(
                title: switch (_filter) {
                  _Tab.activos => 'Sin apartados activos',
                  _Tab.porEntregar => 'Nada por entregar',
                  _ => 'Nada por aquí',
                },
                body: switch (_filter) {
                  _Tab.activos =>
                    'Cuando un cliente deje un anticipo por unos zapatos, una prenda o un artículo, regístralo aquí '
                        'y lleva sus abonos hasta que lo liquide.',
                  _Tab.porEntregar => 'Aquí salen los que ya se pagaron completos y siguen guardados en la tienda.',
                  _ => 'Aquí aparecen los apartados que ya terminaron.',
                },
              ),
            for (final l in list) _LayawayRow(layaway: l, now: now),
          ],
        ),
      ),
    );
  }
}

/// A quién avisarle hoy: se acerca la fecha, ya pasó, le toca abonar o ya puede recogerlo.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.reminders});

  final List<({Layaway layaway, ReminderReason reason})> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return GCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 18, color: GColors.marca),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Por avisar hoy', style: GText.sans(size: 14, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final r in reminders.take(8))
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.customerById(r.layaway.customerId)?.name ?? 'Cliente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GText.sans(size: 13.5, weight: FontWeight.w700),
                      ),
                      Text(
                        '${reminderTitle(r.reason)} · ${r.layaway.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GText.muted(size: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => sendLayawayReminder(context, ref, r.layaway.id, r.reason),
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: Text('Avisar', style: GText.sans(size: 13, color: GColors.marca)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Abre WhatsApp (o el menú de compartir) con el recordatorio y lo anota, para no repetirlo en un par de días.
Future<void> sendLayawayReminder(BuildContext context, WidgetRef ref, String layawayId, ReminderReason reason) async {
  final store = ref.read(storeProvider);
  final l = store.layawayById(layawayId);
  if (l == null) return;
  final text = reminderMessage(
    reason,
    business: store.businessName,
    customer: store.customerById(l.customerId)?.name ?? '',
    what: l.description,
    pending: money(store.pendingOfLayaway(l.id)),
    paid: money(store.paidOfLayaway(l.id)),
    total: money(l.totalCents),
    due: l.dueDate == null ? null : dayLabel(l.dueDate!),
  );
  await shareText(context, text);
  ref.read(storeProvider.notifier).markLayawayReminded(layawayId);
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
    final toDeliver = layaway.status == LayawayStatus.liquidado && !layaway.delivered;
    return InkWell(
      onTap: () => showGSheet(context, (_) => _LayawayDetail(layawayId: layaway.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: overdue ? GColors.rojo : (toDeliver ? GColors.cenote : GColors.izamal), width: 3),
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
                Text(switch (layaway.status) {
                  LayawayStatus.activo => 'Debe ${money(pending, hideZeroCents: true)}',
                  LayawayStatus.liquidado when toDeliver => 'Por entregar',
                  LayawayStatus.liquidado => 'Entregado',
                  LayawayStatus.cancelado => 'Cancelado',
                }, style: layaway.status == LayawayStatus.activo ? GText.amount(size: 15) : GText.muted(size: 12.5)),
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
            if (layaway.status == LayawayStatus.activo) ...[
              const SizedBox(height: 6),
              ProgressStrip(fraction: layaway.totalCents == 0 ? 1 : paid / layaway.totalCents, height: 7),
            ],
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

typedef _Piece = ({String? productId, String name, double qty, int unitCents});

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
  late final LayawayRules _rules = ref.read(storeProvider).layawayRules;
  late DateTime? _due = _rules.days == null ? null : DateTime.now().add(Duration(days: _rules.days!));
  PayMethod _method = PayMethod.efectivo;
  Uint8List? _photo;
  int? _every;
  bool _useCredit = true;

  /// Piezas del inventario. Sin piezas se escribe a mano qué se aparta.
  final _pieces = <_Piece>[];

  /// El precio se escribió a mano (un descuento): ya no se recalcula con las piezas.
  bool _totalEdited = false;
  final _errors = <String, String>{};

  @override
  void dispose() {
    _description.dispose();
    _total.dispose();
    _deposit.dispose();
    super.dispose();
  }

  int get _piecesTotal => _pieces.fold(0, (a, p) => a + (p.unitCents * p.qty).round());

  void _syncTotal() {
    if (!_totalEdited) _total.text = _pieces.isEmpty ? '' : centsInput(_piecesTotal);
  }

  /// Agrega una pieza del inventario. Un modelo con tallas pregunta cuál; no se aparta lo que no hay.
  Future<void> _addPiece() async {
    final p = await pickProduct(context, title: '¿Qué se aparta?', sizeTitle: 'Talla que se aparta');
    if (p == null || !mounted) return;
    final taken = _pieces.where((x) => x.productId == p.id).fold(0.0, (a, x) => a + x.qty);
    if (p.trackStock && p.stock - taken < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p.stock - taken <= 0 ? '${p.name} está agotado' : 'Solo hay ${qtyLabel(p.stock)}')),
      );
      return;
    }
    setState(() {
      final i = _pieces.indexWhere((x) => x.productId == p.id);
      if (i >= 0) {
        final x = _pieces[i];
        _pieces[i] = (productId: x.productId, name: x.name, qty: x.qty + 1, unitCents: x.unitCents);
      } else {
        _pieces.add((productId: p.id, name: p.name, qty: 1, unitCents: p.priceCents));
      }
      _errors.remove('description');
      _syncTotal();
    });
  }

  void _removePiece(int i) => setState(() {
    final x = _pieces[i];
    if (x.qty > 1) {
      _pieces[i] = (productId: x.productId, name: x.name, qty: x.qty - 1, unitCents: x.unitCents);
    } else {
      _pieces.removeAt(i);
    }
    _syncTotal();
  });

  void _save() {
    final store = ref.read(storeProvider);
    final total = parseMoney(_total.text);
    final deposit = _deposit.text.trim().isEmpty ? 0 : parseMoney(_deposit.text);
    final available = _customer == null ? 0 : store.creditOf(_customer!.id);
    final credit = _useCredit && total != null ? available.clamp(0, total) : 0;
    setState(() {
      _errors.clear();
      if (_customer == null) _errors['customer'] = 'Elige el cliente';
      if (_pieces.isEmpty && _description.text.trim().isEmpty) _errors['description'] = 'Escribe qué se aparta';
      if (total == null || total == 0) _errors['total'] = 'Escribe el precio';
      if (deposit == null) _errors['deposit'] = 'Monto no válido';
      if (total != null && deposit != null) {
        if (deposit + credit > total) {
          _errors['deposit'] = credit > 0
              ? 'Con su saldo a favor ya pasa del precio'
              : 'El anticipo es mayor que el precio';
        } else if (deposit + credit < _rules.minDepositFor(total)) {
          _errors['deposit'] = 'El anticipo mínimo es ${money(_rules.minDepositFor(total))} (${_rules.minDepositPct}%)';
        }
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
          items: List.of(_pieces),
          payEveryDays: _every,
          useCreditCents: credit,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final credit = _customer == null ? 0 : store.creditOf(_customer!.id);
    final total = parseMoney(_total.text) ?? 0;
    final minDeposit = _rules.minDepositFor(total);
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
        if (credit > 0)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useCredit,
            activeThumbColor: GColors.cenote,
            onChanged: (v) => setState(() => _useCredit = v),
            title: Text('Usar su saldo a favor: ${money(credit)}', style: GText.sans(size: 14)),
            subtitle: Text('De un apartado que canceló. No entra a la caja: ya había entrado.', style: GText.muted()),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Qué se aparta', style: GText.label())),
            TextButton.icon(
              onPressed: _addPiece,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Del inventario', style: GText.sans(size: 13, color: GColors.marca)),
            ),
          ],
        ),
        for (final (i, p) in _pieces.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.qty == 1 ? p.name : '${qtyLabel(p.qty)} × ${p.name}',
                    style: GText.sans(size: 13.5, weight: FontWeight.w600),
                  ),
                ),
                Text(money((p.unitCents * p.qty).round()), style: GText.figures(size: 12.5)),
                IconButton(
                  tooltip: 'Quitar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: GColors.tintaSuave),
                  onPressed: () => _removePiece(i),
                ),
              ],
            ),
          ),
        if (_pieces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text('Salen del inventario: quedan guardadas para el cliente.', style: GText.muted(size: 12)),
          ),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _errors.remove('description')),
          decoration: InputDecoration(
            labelText: _pieces.isEmpty ? 'O escríbelo' : 'Nota (opcional)',
            hintText: _pieces.isEmpty ? 'Vestido azul talla M' : 'Se lo prueba el sábado',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MoneyField(
                controller: _total,
                label: 'Precio',
                error: _errors['total'],
                onChanged: (_) => setState(() => _totalEdited = _pieces.isNotEmpty),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneyField(
                controller: _deposit,
                label: 'Anticipo',
                hint: '0',
                error: _errors['deposit'],
                onChanged: (_) => setState(() => _errors.remove('deposit')),
              ),
            ),
          ],
        ),
        if (minDeposit > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Anticipo mínimo: ${money(minDeposit)} (${_rules.minDepositPct}%)'
              '${credit > 0 && _useCredit ? ', cuenta su saldo a favor' : ''}',
              style: GText.muted(size: 12),
            ),
          ),
        if (_totalEdited && _pieces.isNotEmpty && total != _piecesTotal)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              total < _piecesTotal
                  ? 'Descuento de ${money(_piecesTotal - total)} sobre el precio de las piezas'
                  : 'Más que el precio de las piezas (${money(_piecesTotal)})',
              style: GText.muted(size: 12),
            ),
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
        Text('Abona', style: GText.label()),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final (days, label) in [
              (null, 'Cuando pueda'),
              (7, 'Cada semana'),
              (15, 'Cada quincena'),
              (30, 'Cada mes'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _every == days,
                onSelected: (_) => setState(() => _every = days),
              ),
          ],
        ),
        if (_every != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Te avisamos cuando le toque, para mandarle su recordatorio.', style: GText.muted(size: 12)),
          ),
        if (_rules.cancelText.isNotEmpty || (_rules.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text([_rules.cancelText, ?_rules.note].where((t) => t.isNotEmpty).join(' '), style: GText.muted(size: 12)),
        ],
        const SizedBox(height: 12),
        GButton(label: 'Guardar apartado', expand: true, big: true, onPressed: _save),
      ],
    );
  }
}

/// Detalle: piezas, abonos, comprobante por WhatsApp, entregar y cancelar.
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
    final items = store.itemsOfLayaway(l.id);
    final rules = store.layawayRules;
    final b = StringBuffer()
      ..writeln('*${store.businessName}*')
      ..writeln('Comprobante de apartado')
      ..writeln('')
      ..writeln('Cliente: ${c?.name ?? ''}');
    if (items.isEmpty) {
      b.writeln('Artículo: ${l.description}');
    } else {
      for (final i in items) {
        b.writeln('${i.qty == 1 ? '' : '${qtyLabel(i.qty)} × '}${i.name}  ${money(i.totalCents)}');
      }
    }
    b.writeln('Precio: ${money(l.totalCents)}');
    for (final p in store.paymentsOfLayaway(l.id)) {
      b.writeln('${dateTimeLabel(p.createdAt)}  ${_paymentKind(l, p).toLowerCase()} ${money(p.amountCents)}');
    }
    b
      ..writeln('')
      ..writeln('*Pagado: ${money(paid)}*');
    if (l.status == LayawayStatus.cancelado) {
      b.writeln('*CANCELADO*');
      if (l.refundCents > 0) b.writeln('Se te devolvió: ${money(l.refundCents)}');
      if (l.creditCents > 0) b.writeln('Saldo a favor: ${money(l.creditCents)}');
    } else if (l.status == LayawayStatus.liquidado || pending == 0) {
      b.writeln(l.delivered ? '*LIQUIDADO Y ENTREGADO*. ¡Gracias!' : '*LIQUIDADO*. Ya puedes pasar por él. ¡Gracias!');
    } else {
      b.writeln('*Resta: ${money(pending)}*');
      if (l.dueDate != null) b.writeln('Fecha límite: ${dayLabel(l.dueDate!)}');
      if (rules.cancelText.isNotEmpty) b.writeln(rules.cancelText);
      if ((rules.note ?? '').isNotEmpty) b.writeln(rules.note);
    }
    return b.toString().trimRight();
  }

  Future<void> _changePhoto() async {
    final l = ref.read(storeProvider).layawayById(widget.layawayId)!;
    final choice = await pickPhoto(context, hasPhoto: l.photoPath != null);
    if (choice == null || !mounted) return;
    ref.read(storeProvider.notifier).setLayawayPhoto(widget.layawayId, choice.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final l = store.layawayById(widget.layawayId)!;
    final c = store.customerById(l.customerId);
    final paid = store.paidOfLayaway(l.id);
    final pending = store.pendingOfLayaway(l.id);
    final active = l.status == LayawayStatus.activo;
    final toDeliver = l.status == LayawayStatus.liquidado && !l.delivered;
    final photo = store.photoOfLayaway(l);
    final canPhoto = active && ref.watch(planProvider).limits.photos;
    final items = store.itemsOfLayaway(l.id);
    final reminder = reminderFor(
      l,
      pendingCents: pending,
      lastPaymentAt: store.lastPaymentOfLayaway(l.id),
      now: DateTime.now(),
    );

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
        if (items.isNotEmpty) ...[
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: GColors.tintaSuave),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.qty == 1 ? i.name : '${qtyLabel(i.qty)} × ${i.name}',
                      style: GText.sans(size: 13.5, weight: FontWeight.w600),
                    ),
                  ),
                  Text(money(i.totalCents), style: GText.figures(size: 12)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (l.status) {
                    LayawayStatus.activo => 'RESTA',
                    LayawayStatus.liquidado when toDeliver => 'LIQUIDADO · POR ENTREGAR',
                    LayawayStatus.liquidado => 'ENTREGADO',
                    LayawayStatus.cancelado => 'CANCELADO',
                  }, style: GText.label()),
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
        if (l.payEveryDays != null && active) ...[
          const SizedBox(height: 2),
          Text('Abona cada ${l.payEveryDays} días', style: GText.muted()),
        ],
        if (l.delivered) ...[
          const SizedBox(height: 6),
          Text('Se lo llevó el ${dateTimeLabel(l.deliveredAt!)}', style: GText.muted()),
        ],
        if (l.status == LayawayStatus.cancelado && (l.refundCents > 0 || l.creditCents > 0 || paid > 0)) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (l.refundCents > 0) 'Se le devolvió ${money(l.refundCents)}',
              if (l.creditCents > 0)
                'saldo a favor ${money(l.creditCents)} (le quedan ${money(store.creditLeftOf(l.id))})',
              if (paid - l.refundCents - l.creditCents > 0)
                'se quedó el negocio ${money(paid - l.refundCents - l.creditCents)}',
            ].join(' · '),
            style: GText.muted(),
          ),
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
                    p.fromCredit ? _paymentKind(l, p) : '${_paymentKind(l, p)} (${p.method.label.toLowerCase()})',
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
        if (toDeliver) ...[
          const SizedBox(height: 12),
          GButton(
            label: 'Ya se lo llevó',
            icon: Icons.shopping_bag_outlined,
            kind: GButtonKind.money,
            expand: true,
            onPressed: () => ref.read(storeProvider.notifier).deliverLayaway(l.id),
          ),
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
        if (reminder != null) ...[
          const SizedBox(height: 8),
          GButton(
            label: 'Recordarle: ${reminderTitle(reminder).toLowerCase()}',
            icon: Icons.notifications_active_outlined,
            kind: GButtonKind.outline,
            expand: true,
            onPressed: () => sendLayawayReminder(context, ref, l.id, reminder),
          ),
        ],
        if (l.kept)
          TextButton(
            onPressed: () => showGSheet(context, (_) => _CancelSheet(layawayId: l.id)),
            child: Text('Cancelar apartado', style: GText.sans(size: 13.5, color: GColors.rojo)),
          ),
      ],
    );
  }
}

String _paymentKind(Layaway l, LayawayPayment p) =>
    p.fromCredit ? 'Saldo a favor' : (p.createdAt == l.createdAt ? 'Anticipo' : 'Abono');

/// Cancelar según las reglas del negocio: cuánto se le devuelve, cuánto queda como saldo a favor y cuánto se
/// queda el negocio. Las piezas regresan al inventario.
class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet({required this.layawayId});

  final String layawayId;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  late final LayawayRules _rules = ref.read(storeProvider).layawayRules;

  /// Con "decidirlo cada vez" se escoge aquí; si no, la regla del dueño.
  late CancelRule _rule = _rules.cancel == CancelRule.preguntar ? CancelRule.devolverTodo : _rules.cancel;
  bool _fromCash = true;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final l = store.layawayById(widget.layawayId)!;
    final paid = store.paidOfLayaway(l.id);
    final split = cancelSplit(_rule, paid: paid, deposit: store.depositOfLayaway(l.id), keepPct: _rules.keepPct);
    final pieces = store.itemsOfLayaway(l.id).where((i) => i.productId != null).toList();
    final noCash = store.openSession == null;
    final cashBlocked = split.refund > 0 && _fromCash && noCash;

    Widget line(String label, int cents, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GText.sans(size: 14))),
          Text(money(cents), style: GText.amount(size: 16, color: color ?? GColors.tinta)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader('¿Cancelar el apartado?', caption: store.customerById(l.customerId)?.name),
        if (_rules.cancel == CancelRule.preguntar && paid > 0) ...[
          Text('¿Qué pasa con lo abonado?', style: GText.label()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final r in CancelRule.values.where((r) => r != CancelRule.preguntar))
                ChoiceChip(
                  label: Text(switch (r) {
                    CancelRule.devolverTodo => 'Devolver todo',
                    CancelRule.quedarsePorcentaje => 'Quedarme el ${_rules.keepPct}%',
                    CancelRule.quedarseAnticipo => 'Quedarme el anticipo',
                    CancelRule.noDevolver => 'No devolver',
                    CancelRule.saldoAFavor => 'Saldo a favor',
                    CancelRule.preguntar => '',
                  }),
                  selected: _rule == r,
                  onSelected: (_) => setState(() => _rule = r),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ] else if (paid > 0) ...[
          Text('Tu regla: ${_rules.cancel.label.toLowerCase()}.', style: GText.muted(size: 13)),
          const SizedBox(height: 8),
        ],
        line('Abonó', paid),
        if (split.refund > 0) line('Se le devuelve', split.refund, color: GColors.marca),
        if (split.credit > 0) line('Queda como saldo a favor', split.credit, color: GColors.cenote),
        if (split.kept > 0) line('Se queda el negocio', split.kept),
        if (split.refund > 0) ...[
          const SizedBox(height: 10),
          Text('¿Cómo se lo devuelves?', style: GText.label()),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GChip(
                  label: 'Efectivo de la caja',
                  selected: _fromCash,
                  onTap: () => setState(() => _fromCash = true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GChip(
                  label: 'Transferencia',
                  selected: !_fromCash,
                  onTap: () => setState(() => _fromCash = false),
                ),
              ),
            ],
          ),
          if (cashBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No hay caja abierta: ábrela en Caja para sacar el efectivo.',
                style: GText.sans(size: 12.5, color: GColors.rojo),
              ),
            )
          else if (_fromCash)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Sale del efectivo de la caja y se anota en el corte.', style: GText.muted(size: 12)),
            ),
        ],
        if (pieces.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${pieces.length == 1 ? 'La pieza regresa' : 'Las piezas regresan'} al inventario.',
            style: GText.muted(size: 12.5),
          ),
        ],
        const SizedBox(height: 14),
        GButton(
          label: 'Cancelar apartado',
          kind: GButtonKind.dark,
          expand: true,
          onPressed: cashBlocked
              ? null
              : () {
                  ref
                      .read(storeProvider.notifier)
                      .cancelLayaway(
                        l.id,
                        refundCents: split.refund,
                        creditCents: split.credit,
                        refundFromCash: _fromCash,
                      );
                  Navigator.of(context).pop();
                },
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('No, dejarlo como está')),
      ],
    );
  }
}

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
