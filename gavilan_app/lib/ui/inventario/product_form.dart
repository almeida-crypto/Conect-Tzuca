import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';

Future<void> showProductForm(BuildContext context, {Product? product}) =>
    showGSheet(context, (_) => _ProductForm(product: product));

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product});

  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(text: _cents(widget.product?.priceCents));
  late final _cost = TextEditingController(text: _cents(widget.product?.costCents));
  late final _barcode = TextEditingController(text: widget.product?.barcode ?? '');
  late final _stock = TextEditingController(text: widget.product == null ? '' : qtyLabel(widget.product!.stock));
  late final _min = TextEditingController(
    text: widget.product?.minStock == null ? '' : qtyLabel(widget.product!.minStock!),
  );
  final _restock = TextEditingController();
  late String _icon = widget.product?.iconId ?? 'otro';
  late bool _track = widget.product?.trackStock ?? true;
  final _errors = <String, String>{};

  bool get _editing => widget.product != null;

  static String _cents(int? c) => (c == null || c == 0) ? '' : (c / 100).toStringAsFixed(c % 100 == 0 ? 0 : 2);

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _barcode, _stock, _min, _restock]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final price = parseMoney(_price.text);
    final cost = _cost.text.trim().isEmpty ? 0 : parseMoney(_cost.text);
    final stock = double.tryParse(_stock.text.trim().isEmpty ? '0' : _stock.text.trim());
    final min = _min.text.trim().isEmpty ? null : double.tryParse(_min.text.trim());
    final code = _barcode.text.trim();
    final store = ref.read(storeProvider);
    final clash = code.isEmpty ? null : store.productByBarcode(code);

    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Escribe el nombre';
      if (price == null || price == 0) _errors['price'] = 'Escribe el precio';
      if (cost == null) _errors['cost'] = 'Costo no válido';
      if (_track && stock == null) _errors['stock'] = 'Cantidad no válida';
      if (_min.text.trim().isNotEmpty && min == null) _errors['min'] = 'Cantidad no válida';
      if (clash != null && clash.id != widget.product?.id) _errors['barcode'] = 'Ya lo usa "${clash.name}"';
    });
    if (_errors.isNotEmpty) return;

    final base = widget.product ?? Product(id: newId(), name: '', priceCents: 0);
    ref
        .read(storeProvider.notifier)
        .saveProduct(
          base.copyWith(
            name: _name.text.trim(),
            priceCents: price,
            costCents: cost,
            barcode: code.isEmpty ? null : code,
            clearBarcode: code.isEmpty,
            iconId: _icon,
            trackStock: _track,
            stock: _editing ? null : (stock ?? 0),
            minStock: min,
            clearMinStock: min == null,
          ),
        );
    Navigator.of(context).pop();
  }

  void _addStock() {
    final qty = double.tryParse(_restock.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _errors['restock'] = 'Escribe cuánto llegó');
      return;
    }
    ref.read(storeProvider.notifier).addStock(widget.product!.id, qty);
    _restock.clear();
    setState(() => _errors.remove('restock'));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Se agregaron ${qtyLabel(qty)} a ${widget.product!.name}')));
  }

  void _deactivate() {
    ref.read(storeProvider.notifier).saveProduct(widget.product!.copyWith(active: false));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final current = _editing ? ref.watch(storeProvider).productById(widget.product!.id) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(_editing ? 'Editar producto' : 'Nuevo producto'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Coca 600 ml', errorText: _errors['name']),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Precio', prefixText: '\$ ', errorText: _errors['price']),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Costo (opcional)',
                  prefixText: '\$ ',
                  errorText: _errors['cost'],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _barcode,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Código de barras (opcional)',
            prefixIcon: const Icon(Icons.qr_code_2, size: 20),
            errorText: _errors['barcode'],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Icono', style: GText.sans(size: 13)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => plan.limits.photos
                  ? ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Las fotos de producto llegan con la cámara, en el siguiente paso.'),
                      ),
                    )
                  : showUpgradeSheet(
                      context,
                      reason:
                          'En el plan ${plan.label} los productos usan iconos. '
                          'Con fotos reales tus clientes reconocen mejor lo que venden.',
                      needed: Plan.emprendedor,
                    ),
              icon: Icon(plan.limits.photos ? Icons.photo_camera_outlined : Icons.lock_outline, size: 16),
              label: Text('Usar foto', style: GText.sans(size: 12.5, color: GColors.oxido)),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in productIcons.entries)
              Semantics(
                button: true,
                selected: _icon == e.key,
                label: e.key,
                child: InkWell(
                  onTap: () => setState(() => _icon = e.key),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _icon == e.key ? GColors.tinta : GColors.papel2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(e.value, size: 20, color: _icon == e.key ? GColors.papel : GColors.pardo),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _track,
          activeThumbColor: GColors.oxido,
          onChanged: (v) => setState(() => _track = v),
          title: Text('Controlar existencia', style: GText.sans(size: 14)),
          subtitle: Text('Se descuenta sola con cada venta', style: GText.muted()),
        ),
        if (_track)
          Row(
            children: [
              if (!_editing) ...[
                Expanded(
                  child: TextField(
                    controller: _stock,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Tengo ahora', errorText: _errors['stock']),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Avisarme al llegar a', errorText: _errors['min']),
                ),
              ),
            ],
          ),
        if (_editing && _track && current != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GColors.papelClaro,
              border: Border.all(color: GColors.linea),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Existencia: ${qtyLabel(current.stock)}', style: GText.sans(size: 14, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _restock,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(hintText: 'Llegó mercancía: 12', errorText: _errors['restock']),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GButton(label: 'Sumar', kind: GButtonKind.dark, onPressed: _addStock),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        GButton(label: _editing ? 'Guardar cambios' : 'Guardar producto', expand: true, big: true, onPressed: _save),
        if (_editing) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _deactivate,
            child: Text('Ya no lo vendo (ocultar)', style: GText.sans(size: 13, color: GColors.rojo)),
          ),
        ],
      ],
    );
  }
}
