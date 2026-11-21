import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../core/money.dart';
import '../../core/share.dart';
import '../../domain/models.dart';
import '../../domain/purchases.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../inventario/product_search.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'module_widgets.dart';

/// Compras a proveedores: lo que llega entra al inventario con su costo, y se lleva lo que se le debe a cada uno.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final suppliers = store.suppliers.where((s) => s.active).toList()
      ..sort((a, b) => store.debtToSupplier(b.id).compareTo(store.debtToSupplier(a.id)));
    final recent = [...store.purchases]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final debt = store.supplierDebt;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Compras a proveedores', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GButton(
                label: 'Llegó mercancía',
                icon: Icons.local_shipping_outlined,
                expand: true,
                onPressed: () => showGSheet(context, (_) => const _NewPurchaseSheet()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GButton(
                label: 'Armar pedido',
                icon: Icons.playlist_add_check_rounded,
                kind: GButtonKind.outline,
                expand: true,
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RestockScreen())),
              ),
            ),
            if (debt > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Le debes a proveedores: ${money(debt)}',
                  style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.rojo),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Proveedores', style: GText.label())),
                  TextButton.icon(
                    onPressed: () async {
                      final s = await _askSupplier(context);
                      if (s != null) ref.read(storeProvider.notifier).addSupplier(s.name, phone: s.phone);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Agregar', style: GText.sans(size: 13, color: GColors.marca)),
                  ),
                ],
              ),
            ),
            if (suppliers.isEmpty)
              const EmptyInvite(
                title: 'Sin proveedores todavía',
                body:
                    'Cuando llegue mercancía, regístrala aquí: entra al inventario con su costo y llevas lo que le '
                    'debes a cada proveedor.',
              ),
            for (final s in suppliers) _SupplierRow(supplier: s),
            if (recent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: Text('Últimas compras', style: GText.label()),
              ),
              for (final p in recent.take(15)) _PurchaseRow(purchase: p),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierRow extends ConsumerWidget {
  const _SupplierRow({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = ref.watch(storeProvider).debtToSupplier(supplier.id);
    return InkWell(
      onTap: () => showGSheet(context, (_) => _SupplierSheet(supplierId: supplier.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.linea)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name, style: GText.sans(size: 14.5, weight: FontWeight.w700)),
                  if (supplier.phone != null) Text(supplier.phone!, style: GText.muted(size: 12)),
                ],
              ),
            ),
            Text(
              debt > 0 ? 'Le debes ${money(debt, hideZeroCents: true)}' : 'Al corriente',
              style: debt > 0 ? GText.amount(size: 15, color: GColors.rojo) : GText.muted(size: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseRow extends ConsumerWidget {
  const _PurchaseRow({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final supplier = purchase.supplierId == null ? null : store.supplierById(purchase.supplierId!);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${supplier?.name ?? 'Sin proveedor'} · ${dayLabel(purchase.createdAt)}',
                  style: GText.sans(size: 13.5, weight: FontWeight.w700),
                ),
                Text(purchase.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: GText.muted(size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(money(purchase.totalCents, hideZeroCents: true), style: GText.figures(size: 13)),
        ],
      ),
    );
  }
}

/// Nombre y teléfono de un proveedor (nuevo o para corregir).
Future<({String name, String? phone})?> _askSupplier(BuildContext context, {Supplier? current}) async {
  final name = TextEditingController(text: current?.name ?? '');
  final phone = TextEditingController(text: current?.phone ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(current == null ? 'Nuevo proveedor' : 'Proveedor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [maxChars(Limits.maxNameLength)],
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Distribuidora del Sureste'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [maxChars(20)],
            decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
      ],
    ),
  );
  final result = ok == true && name.text.trim().isNotEmpty
      ? (name: name.text.trim(), phone: phone.text.trim().isEmpty ? null : phone.text.trim())
      : null;
  name.dispose();
  phone.dispose();
  return result;
}

/// Lo que se le pagó en el momento.
enum _PaidNow { todo, nada, parte }

class _Line {
  _Line(this.product, {required int costCents, this.qty = 1})
    : cost = TextEditingController(text: centsInput(costCents));

  final Product product;
  double qty;
  final TextEditingController cost;
}

class _NewPurchaseSheet extends ConsumerStatefulWidget {
  const _NewPurchaseSheet({this.supplierId, this.lines = const []});

  /// Desde un pedido: el proveedor y lo que se pidió, ya escritos (se pueden corregir).
  final String? supplierId;
  final List<(Product, double)> lines;

  @override
  ConsumerState<_NewPurchaseSheet> createState() => _NewPurchaseSheetState();
}

class _NewPurchaseSheetState extends ConsumerState<_NewPurchaseSheet> {
  late Supplier? _supplier = widget.supplierId == null
      ? null
      : ref.read(storeProvider).supplierById(widget.supplierId!);
  late final _lines = <_Line>[for (final (p, q) in widget.lines) _Line(p, costCents: p.costCents, qty: q)];
  bool _updateCost = true;
  _PaidNow _paid = _PaidNow.todo;
  final _part = TextEditingController();
  final _note = TextEditingController();
  PayMethod _method = PayMethod.efectivo;
  bool _fromCash = true;
  String? _error;

  @override
  void dispose() {
    for (final l in _lines) {
      l.cost.dispose();
    }
    _part.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _total => _lines.fold(0, (a, l) => a + ((parseMoney(l.cost.text) ?? 0) * l.qty).round());

  Future<void> _pickSupplier() async {
    final store = ref.read(storeProvider);
    final picked = await showGSheet<Supplier>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader('¿De qué proveedor?'),
          for (final s in store.suppliers.where((s) => s.active))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(s.name, style: GText.sans(size: 14.5, weight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop(s),
            ),
          TextButton.icon(
            onPressed: () async {
              final data = await _askSupplier(ctx);
              if (data != null && ctx.mounted) {
                Navigator.of(ctx).pop(ref.read(storeProvider.notifier).addSupplier(data.name, phone: data.phone));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Proveedor nuevo'),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _addLine() async {
    final p = await pickProduct(context, title: '¿Qué llegó?', sizeTitle: 'Talla que llegó', onlyAvailable: false);
    if (p == null || !mounted) return;
    setState(() {
      final i = _lines.indexWhere((l) => l.product.id == p.id);
      if (i >= 0) {
        _lines[i].qty += 1;
      } else {
        _lines.add(_Line(p, costCents: p.costCents));
      }
      _error = null;
    });
  }

  Future<void> _editQty(_Line l) async {
    final c = TextEditingController(text: qtyLabel(l.qty));
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.product.name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [QtyInputFormatter()],
          decoration: const InputDecoration(labelText: '¿Cuántos llegaron?'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Listo'))],
      ),
    );
    c.dispose();
    final q = v == null ? null : parseQty(v);
    if (q != null && q > 0) setState(() => l.qty = q);
  }

  void _save() {
    final store = ref.read(storeProvider);
    if (_lines.isEmpty) return setState(() => _error = 'Agrega lo que llegó');
    if (_lines.any((l) => parseMoney(l.cost.text) == null)) return setState(() => _error = 'Revisa los costos');
    final total = _total;
    final paid = switch (_paid) {
      _PaidNow.todo => total,
      _PaidNow.nada => 0,
      _PaidNow.parte => parseMoney(_part.text) ?? -1,
    };
    if (paid < 0 || paid > total) return setState(() => _error = 'Lo pagado debe ser entre \$0 y el total');
    if (_supplier == null && paid < total) {
      return setState(() => _error = 'Para quedar a deber, elige el proveedor');
    }
    final cash = _method == PayMethod.efectivo && _fromCash && store.openSession != null;
    ref
        .read(storeProvider.notifier)
        .addPurchase(
          supplierId: _supplier?.id,
          lines: [
            for (final l in _lines)
              PurchaseLine(
                productId: l.product.id,
                name: l.product.name,
                qty: l.qty,
                unitCostCents: parseMoney(l.cost.text)!,
              ),
          ],
          updateCost: _updateCost,
          paidCents: paid,
          method: _method,
          fromCash: cash,
          note: _note.text,
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Listo: ${_lines.length} ${_lines.length == 1 ? 'producto entró' : 'productos entraron'} al inventario',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final total = _total;
    final noCash = store.openSession == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('Llegó mercancía'),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: GColors.tinta,
            side: const BorderSide(color: GColors.linea),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GShape.radiusSmall)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            alignment: Alignment.centerLeft,
          ),
          onPressed: _pickSupplier,
          icon: const Icon(Icons.storefront_outlined),
          label: Text(_supplier?.name ?? 'Elegir proveedor (opcional)', style: GText.sans(size: 15)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Qué llegó', style: GText.label())),
            TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Agregar producto', style: GText.sans(size: 13, color: GColors.marca)),
            ),
          ],
        ),
        for (final (i, l) in _lines.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.product.name, style: GText.sans(size: 13.5, weight: FontWeight.w700)),
                      Text(
                        'Hay ${qtyLabel(l.product.trackStock ? l.product.stock : 0)} · vende a ${money(l.product.priceCents)}',
                        style: GText.muted(size: 11.5),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _editQty(l),
                  borderRadius: BorderRadius.circular(GShape.radiusSmall),
                  child: Container(
                    width: 52,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: GColors.linea),
                      borderRadius: BorderRadius.circular(GShape.radiusSmall),
                    ),
                    child: Text(qtyLabel(l.qty), style: GText.amount(size: 16)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 92,
                  child: TextField(
                    controller: l.cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [MoneyInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(isDense: true, prefixText: '\$ ', hintText: 'c/u'),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _lines.removeAt(i).cost.dispose()),
                  icon: const Icon(Icons.close, size: 18, color: GColors.tintaSuave),
                ),
              ],
            ),
          ),
        if (_lines.isNotEmpty) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _updateCost,
            onChanged: (v) => setState(() => _updateCost = v ?? true),
            title: Text('Guardar este costo en los productos', style: GText.sans(size: 13.5)),
            subtitle: Text('Así la ganancia se calcula con lo que pagaste ahora', style: GText.muted(size: 12)),
          ),
          Row(
            children: [
              Expanded(
                child: Text('Total de la compra', style: GText.sans(size: 15, weight: FontWeight.w700)),
              ),
              Text(money(total), style: GText.amount(size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Text('¿Cuánto le pagaste ahora?', style: GText.label()),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, (v, label)) in [
                (_PaidNow.todo, 'Todo'),
                (_PaidNow.parte, 'Una parte'),
                (_PaidNow.nada, 'Nada'),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GChip(label: label, selected: _paid == v, onTap: () => setState(() => _paid = v)),
                ),
              ],
            ],
          ),
          if (_paid == _PaidNow.parte) ...[
            const SizedBox(height: 8),
            MoneyField(controller: _part, label: 'Le pagué', onChanged: (_) => setState(() {})),
          ],
          if (_paid != _PaidNow.nada) ...[
            const SizedBox(height: 8),
            PayMethodChips(selected: _method, onPick: (m) => setState(() => _method = m)),
            if (_method == PayMethod.efectivo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fromCash && !noCash,
                activeThumbColor: GColors.marca,
                onChanged: noCash ? null : (v) => setState(() => _fromCash = v),
                title: Text('Salió del efectivo de la caja', style: GText.sans(size: 13.5)),
                subtitle: Text(
                  noCash ? 'No hay caja abierta: no se descuenta de ningún corte.' : 'Se descuenta en el corte de hoy.',
                  style: GText.muted(size: 12),
                ),
              ),
          ],
          if (_paid == _PaidNow.nada || _paid == _PaidNow.parte)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Lo que falta queda a deber con el proveedor.', style: GText.muted(size: 12)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            inputFormatters: [maxChars(Limits.maxNoteLength)],
            decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Factura 1234'),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: GText.sans(size: 13, color: GColors.rojo)),
          ),
        const SizedBox(height: 14),
        GButton(label: 'Guardar compra', expand: true, big: true, onPressed: _save),
      ],
    );
  }
}

/// Un proveedor: lo que se le debe, sus compras y pagos, y pagarle.
class _SupplierSheet extends ConsumerStatefulWidget {
  const _SupplierSheet({required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends ConsumerState<_SupplierSheet> {
  final _amount = TextEditingController();
  PayMethod _method = PayMethod.efectivo;
  bool _fromCash = true;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pay(int debt) {
    final cents = parseMoney(_amount.text);
    if (cents == null || cents <= 0) return setState(() => _error = 'Escribe cuánto le pagas');
    if (cents > debt) return setState(() => _error = 'Es más de lo que le debes (${money(debt)})');
    final cash = _method == PayMethod.efectivo && _fromCash && ref.read(storeProvider).openSession != null;
    ref.read(storeProvider.notifier).paySupplier(widget.supplierId, cents, _method, fromCash: cash);
    _amount.clear();
    setState(() => _error = null);
  }

  String _statement(StoreState store, Supplier s) {
    final b = StringBuffer()
      ..writeln('*${store.businessName}*')
      ..writeln('Cuenta con ${s.name}')
      ..writeln('');
    for (final p in store.purchasesOf(s.id).take(10)) {
      b.writeln('${dayLabel(p.createdAt)}  Compra ${money(p.totalCents)}');
    }
    for (final p in store.paymentsToSupplier(s.id).take(10)) {
      b.writeln('${dayLabel(p.createdAt)}  Pago ${money(p.amountCents)}');
    }
    b
      ..writeln('')
      ..writeln('*Saldo: ${money(store.debtToSupplier(s.id))}*');
    return b.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final s = store.supplierById(widget.supplierId)!;
    final debt = store.debtToSupplier(s.id);
    final noCash = store.openSession == null;
    final history = <(DateTime, String, int, bool)>[
      for (final p in store.purchasesOf(s.id)) (p.createdAt, 'Compra · ${p.summary}', p.totalCents, true),
      for (final p in store.paymentsToSupplier(s.id))
        (
          p.createdAt,
          'Pago (${p.method.label.toLowerCase()}${p.fromCash ? ', de la caja' : ''})',
          p.amountCents,
          false,
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(s.name, caption: s.phone ?? 'Proveedor'),
        Text(debt > 0 ? 'LE DEBES' : 'AL CORRIENTE', style: GText.label()),
        Text(
          money(debt.clamp(0, 1 << 40)),
          style: GText.amount(size: 30, color: debt > 0 ? GColors.rojo : GColors.cenote),
        ),
        if (debt > 0) ...[
          const SizedBox(height: 12),
          MoneyField(
            controller: _amount,
            label: 'Le pago',
            error: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          PayMethodChips(selected: _method, onPick: (m) => setState(() => _method = m)),
          if (_method == PayMethod.efectivo)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fromCash && !noCash,
              activeThumbColor: GColors.marca,
              onChanged: noCash ? null : (v) => setState(() => _fromCash = v),
              title: Text('Sale del efectivo de la caja', style: GText.sans(size: 13.5)),
            ),
          const SizedBox(height: 6),
          GButton(label: 'Registrar pago', kind: GButtonKind.money, expand: true, onPressed: () => _pay(debt)),
        ],
        const SizedBox(height: 14),
        for (final h in history.take(30))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.linea)),
            ),
            child: Row(
              children: [
                Text(dayLabel(h.$1), style: GText.figures(size: 11, color: GColors.tintaSuave)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(h.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: GText.sans(size: 13)),
                ),
                Text(
                  '${h.$4 ? '+' : '−'}${money(h.$3)}',
                  style: GText.figures(size: 12, color: h.$4 ? GColors.rojo : GColors.cenote),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GButton(
                label: 'WhatsApp',
                icon: Icons.send_outlined,
                kind: GButtonKind.outline,
                onPressed: () => shareText(context, _statement(store, s)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GButton(
                label: 'Editar',
                icon: Icons.edit_outlined,
                kind: GButtonKind.outline,
                onPressed: () async {
                  final data = await _askSupplier(context, current: s);
                  if (data != null) {
                    ref
                        .read(storeProvider.notifier)
                        .updateSupplier(s.copyWith(name: data.name, phone: data.phone, clearPhone: data.phone == null));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pedido sugerido: lo que se está acabando, cuánto pedir para que alcance y a qué proveedor (el de la última
/// compra). Se manda por WhatsApp y, cuando llega, se registra la compra con lo pedido ya escrito.
class RestockScreen extends ConsumerStatefulWidget {
  const RestockScreen({super.key});

  @override
  ConsumerState<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen> {
  int _days = 7;

  /// Lo que se cambió a mano (producto → piezas) y lo que se quitó del pedido.
  final _qty = <String, double>{};
  final _skip = <String>{};

  double _qtyOf(RestockLine l) => _qty[l.product.id] ?? l.qty;

  Future<void> _edit(RestockLine l) async {
    final c = TextEditingController(text: qtyLabel(_qtyOf(l)));
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.product.name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [QtyInputFormatter()],
          decoration: InputDecoration(labelText: '¿Cuántos pides?', helperText: 'Hay ${qtyLabel(l.product.stock)}'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Listo'))],
      ),
    );
    c.dispose();
    final q = v == null ? null : parseQty(v);
    if (q != null && q > 0) setState(() => _qty[l.product.id] = q);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final suggestions = store.restockSuggestions(now: DateTime.now(), coverDays: _days);
    final groups = <String?, List<RestockLine>>{};
    for (final l in suggestions) {
      groups.putIfAbsent(l.supplierId, () => []).add(l);
    }
    final order = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return (store.supplierById(a)?.name ?? '').compareTo(store.supplierById(b)?.name ?? '');
      });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Armar pedido', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                'Con lo que vendiste en las últimas 4 semanas y tu aviso de mínimo: lo que hay que pedir para que '
                'alcance. Cambia las piezas o quita lo que no quieras.',
                style: GText.muted(size: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (final (i, (d, label)) in [(7, '1 semana'), (15, '2 semanas'), (30, '1 mes')].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: GChip(label: label, selected: _days == d, onTap: () => setState(() => _days = d)),
                    ),
                  ],
                ],
              ),
            ),
            if (suggestions.isEmpty)
              const EmptyInvite(
                title: 'No hace falta pedir nada',
                body: 'Con lo que hay alcanza para ese tiempo. Pon el aviso de mínimo en tus productos para que salgan aquí.',
              ),
            for (final sid in order) _group(store, sid, groups[sid]!),
          ],
        ),
      ),
    );
  }

  Widget _group(StoreState store, String? supplierId, List<RestockLine> lines) {
    final supplier = supplierId == null ? null : store.supplierById(supplierId);
    final picked = lines.where((l) => !_skip.contains(l.product.id)).toList();
    final cost = picked.fold(0, (a, l) => a + (l.product.costCents * _qtyOf(l)).round());
    return GCard(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  supplier?.name ?? 'Sin proveedor todavía',
                  style: GText.sans(size: 15, weight: FontWeight.w800),
                ),
              ),
              if (cost > 0) Text('≈ ${money(cost, hideZeroCents: true)}', style: GText.figures(size: 13)),
              const SizedBox(width: 6),
            ],
          ),
          if (supplier == null)
            Text('Nunca se les ha registrado compra: elige el proveedor al recibirlos.', style: GText.muted(size: 12)),
          const SizedBox(height: 4),
          for (final l in lines)
            Row(
              children: [
                Checkbox(
                  value: !_skip.contains(l.product.id),
                  onChanged: (v) => setState(() => v == true ? _skip.remove(l.product.id) : _skip.add(l.product.id)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.product.name, style: GText.sans(size: 13.5, weight: FontWeight.w700)),
                      Text(
                        [
                          'Hay ${qtyLabel(l.product.stock)}',
                          if (l.perDay > 0) 'se venden ~${qtyLabel((l.perDay * 7).ceilToDouble())} por semana',
                        ].join(' · '),
                        style: GText.sans(size: 11.5, color: l.product.stock <= 0 ? GColors.rojo : GColors.tintaSuave),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _edit(l),
                  borderRadius: BorderRadius.circular(GShape.radiusSmall),
                  child: Container(
                    width: 56,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: GColors.linea),
                      borderRadius: BorderRadius.circular(GShape.radiusSmall),
                    ),
                    child: Text(qtyLabel(_qtyOf(l)), style: GText.amount(size: 16)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: 'WhatsApp',
                  icon: Icons.send_outlined,
                  kind: GButtonKind.outline,
                  onPressed: picked.isEmpty
                      ? null
                      : () => shareText(
                          context,
                          restockMessage(
                            business: store.businessName,
                            supplier: supplier?.name,
                            lines: [for (final l in picked) (l.product.name, _qtyOf(l))],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GButton(
                  label: 'Ya llegó',
                  icon: Icons.local_shipping_outlined,
                  kind: GButtonKind.dark,
                  onPressed: picked.isEmpty
                      ? null
                      : () => showGSheet(
                          context,
                          (_) => _NewPurchaseSheet(
                            supplierId: supplierId,
                            lines: [for (final l in picked) (l.product, _qtyOf(l))],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}
