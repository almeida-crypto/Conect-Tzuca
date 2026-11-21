import '../../core/limits.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/business.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../domain/profit.dart';
import '../../domain/variants.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../scan/scan_screen.dart';
import '../widgets/photo_picker.dart';
import '../widgets/product_icons.dart';
import 'status_card_screen.dart';

/// Abre la ficha de producto. Devuelve el producto guardado (null si se canceló).
Future<Product?> showProductForm(BuildContext context, {Product? product, String? initialBarcode}) async {
  // En la nube solo el dueño y los administradores cambian el catálogo; un cambio de un cajero se rechazaría.
  if (!ProviderScope.containerOf(context).read(permissionsProvider).editCatalog) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Solo el dueño o un administrador pueden cambiar los productos')));
    return null;
  }
  // Una talla se edita desde su modelo.
  final store = ProviderScope.containerOf(context).read(storeProvider);
  final shown = product?.parentId == null ? product : (store.productById(product!.parentId!) ?? product);
  return showGSheet<Product>(context, (_) => _ProductForm(product: shown, initialBarcode: initialBarcode));
}

/// Revisa el límite de productos del plan antes de dar de alta uno nuevo.
Future<bool> ensureRoomForProduct(BuildContext context, WidgetRef ref) async {
  final store = ref.read(storeProvider);
  final plan = ref.read(planProvider);
  final max = plan.limits.maxProducts;
  if (max == null || store.activeProducts.length < max) return true;
  await showUpgradeSheet(
    context,
    reason:
        'Tu plan ${plan.label} permite hasta $max productos. '
        'Puedes ocultar los que ya no vendes o cambiar de plan.',
    needed: plan == Plan.semilla ? Plan.emprendedor : Plan.negocio,
  );
  return false;
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product, this.initialBarcode});

  final Product? product;
  final String? initialBarcode;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(text: _cents(widget.product?.priceCents));
  late final _cost = TextEditingController(text: _cents(widget.product?.costCents));
  late final _barcode = TextEditingController(text: widget.product?.barcode ?? widget.initialBarcode ?? '');
  late final _stock = TextEditingController(text: widget.product == null ? '' : qtyLabel(widget.product!.stock));
  late final _min = TextEditingController(
    text: widget.product?.minStock == null ? '' : qtyLabel(widget.product!.minStock!),
  );
  final _restock = TextEditingController();
  late String _icon = widget.product?.iconId ?? 'otro';

  /// Foto nueva (ya chica) que se guarda al darle Guardar; o quitar la que tenía.
  Uint8List? _photo;
  bool _removePhoto = false;
  late bool _track = widget.product?.trackStock ?? true;

  /// En un restaurante: si sale en las mesas, en el mostrador o en los dos (lo de siempre).
  late ProductPlace _place = widget.product?.place ?? ProductPlace.todos;
  final _errors = <String, String>{};

  /// Tallas y colores: apagado de inicio; prendido si ya es un modelo con tallas.
  late bool _variants = widget.product != null && ref.read(storeProvider).isModel(widget.product!);
  late final List<Product> _existing = widget.product == null
      ? const []
      : ref.read(storeProvider).variantsOf(widget.product!.id);
  late final _sizes = TextEditingController(text: _unique(_existing.map((v) => v.size)).join(', '));
  late final _colors = TextEditingController(text: _unique(_existing.map((v) => v.color)).join(', '));
  late final _variantMin = TextEditingController(
    text: _existing.isEmpty || _existing.first.minStock == null ? '' : qtyLabel(_existing.first.minStock!),
  );

  /// Piezas de cada combinación: las que hay (nuevas) o las que llegaron (ya existían).
  final _qty = <String, TextEditingController>{};

  /// Precio propio de una talla (vacío = el del modelo). Viene lleno si ya tenía uno distinto.
  final _prices = <String, TextEditingController>{};

  TextEditingController _priceFor(String key) => _prices.putIfAbsent(key, () {
    final old = _existing.where((v) => variantKey(v.size, v.color) == key).firstOrNull;
    final own = old != null && widget.product != null && old.priceCents != widget.product!.priceCents;
    return TextEditingController(text: own ? centsInput(old.priceCents) : '');
  });

  static List<String> _unique(Iterable<String?> values) {
    final seen = <String>{};
    return [
      for (final v in values)
        if (v != null && seen.add(v.toLowerCase())) v,
    ];
  }

  TextEditingController _qtyFor(String key) => _qty.putIfAbsent(key, TextEditingController.new);

  List<({String? size, String? color})> get _combos =>
      variantCombos(splitVariantList(_sizes.text), splitVariantList(_colors.text));

  bool get _editing => widget.product != null;

  static String _cents(int? c) => centsInput(c);

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _cost,
      _barcode,
      _stock,
      _min,
      _restock,
      _sizes,
      _colors,
      _variantMin,
      ..._qty.values,
      ..._prices.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final price = parseMoney(_price.text);
    final cost = _cost.text.trim().isEmpty ? 0 : parseMoney(_cost.text);
    final stock = parseQty(_stock.text.trim().isEmpty ? '0' : _stock.text);
    final min = _min.text.trim().isEmpty ? null : parseQty(_min.text);
    final code = _barcode.text.trim();
    final store = ref.read(storeProvider);
    final clash = code.isEmpty ? null : store.productByBarcode(code);

    setState(() {
      _errors.clear();
      if (_name.text.trim().isEmpty) _errors['name'] = 'Escribe el nombre';
      if (price == null || price == 0) _errors['price'] = moneyTooBig(_price.text) ?? 'Escribe el precio';
      if (cost == null) _errors['cost'] = moneyTooBig(_cost.text) ?? 'Costo no válido';
      if (price != null && cost != null && cost > 0 && price > 0 && cost > price * 20) {
        _errors['cost'] = 'Revisa: el costo es mucho mayor que el precio';
      }
      if (_track && stock == null) _errors['stock'] = 'Entre 0 y 99,999';
      if (_min.text.trim().isNotEmpty && min == null) _errors['min'] = 'Entre 0 y 99,999';
      if (clash != null && clash.id != widget.product?.id) _errors['barcode'] = 'Ya lo usa "${clash.name}"';
    });
    if (_errors.isNotEmpty) return;
    if (_variants) return _saveModel(price!, cost!);

    // Partimos del producto como está ahora (pudo venderse mientras el formulario estaba abierto).
    final base =
        (widget.product == null ? null : store.productById(widget.product!.id)) ??
        Product(id: newId(), name: '', priceCents: 0);
    final saved = base.copyWith(
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
      place: _place,
    );
    final notifier = ref.read(storeProvider.notifier);
    notifier.saveProduct(saved);
    if (_photo != null) {
      notifier.setProductPhoto(saved.id, _photo);
    } else if (_removePhoto) {
      notifier.setProductPhoto(saved.id, null);
    }
    Navigator.of(context).pop(saved);
  }

  /// Con tallas: el modelo y una talla por cada combinación.
  void _saveModel(int price, int cost) {
    final combos = _combos;
    final min = _variantMin.text.trim().isEmpty ? null : parseQty(_variantMin.text);
    final drafts = [
      for (final c in combos)
        (size: c.size, color: c.color, qty: parseQty(_qtyFor(variantKey(c.size, c.color)).text) ?? 0.0),
    ];
    final prices = <String, int>{};
    var badPrice = false;
    for (final c in combos) {
      final key = variantKey(c.size, c.color);
      final text = _prices[key]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final cents = parseMoney(text);
      if (cents == null || cents == 0) {
        badPrice = true;
      } else if (cents != price) {
        prices[key] = cents;
      }
    }
    setState(() {
      if (badPrice) _errors['sizes'] = 'Revisa el precio de las tallas';
      if (combos.isEmpty) _errors['sizes'] = 'Escribe las tallas o los colores';
      if (combos.length > maxVariants) {
        _errors['sizes'] = 'Son ${combos.length} combinaciones; el máximo es $maxVariants';
      }
      if (_variantMin.text.trim().isNotEmpty && min == null) _errors['vmin'] = 'Entre 0 y 99,999';
    });
    if (_errors.isNotEmpty) return;
    final store = ref.read(storeProvider);
    final base =
        (widget.product == null ? null : store.productById(widget.product!.id)) ??
        Product(id: newId(), name: '', priceCents: 0);
    final model = base.copyWith(
      name: _name.text.trim(),
      priceCents: price,
      costCents: cost,
      iconId: _icon,
      place: _place,
    );
    final notifier = ref.read(storeProvider.notifier);
    notifier.saveModel(model, drafts, minStock: min, prices: prices);
    if (_photo != null) {
      notifier.setProductPhoto(model.id, _photo);
    } else if (_removePhoto) {
      notifier.setProductPhoto(model.id, null);
    }
    Navigator.of(context).pop(ref.read(storeProvider).productById(model.id));
  }

  /// Toma o elige la foto. Se reduce a 600×600 al tomarla: pesa unos 50 KB.
  Future<void> _pickPhoto(bool hasPhoto) async {
    final choice = await pickPhoto(context, hasPhoto: hasPhoto);
    if (choice == null || !mounted) return;
    setState(() {
      _photo = choice.bytes;
      _removePhoto = choice.bytes == null;
    });
  }

  void _addStock() {
    final qty = parseQty(_restock.text);
    final current = ref.read(storeProvider).productById(widget.product!.id);
    if (qty == null || qty <= 0 || (current != null && current.stock + qty > Limits.maxQty)) {
      setState(
        () => _errors['restock'] = qty != null && qty > 0
            ? 'La existencia no puede pasar de 99,999'
            : 'Escribe cuánto llegó',
      );
      return;
    }
    ref.read(storeProvider.notifier).addStock(widget.product!.id, qty);
    _restock.clear();
    setState(() => _errors.remove('restock'));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Se agregaron ${qtyLabel(qty)} a ${widget.product!.name}')));
  }

  void _deactivate() {
    ref.read(storeProvider.notifier).hideProduct(widget.product!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final current = _editing ? ref.watch(storeProvider).productById(widget.product!.id) : null;
    final shownPhoto = _removePhoto
        ? null
        : _photo ?? (current == null ? null : ref.watch(storeProvider).photoOf(current));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(_editing ? 'Editar producto' : 'Nuevo producto'),
        if (_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => StatusCardScreen(productId: widget.product!.id))),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text('Tarjeta para Estados de WhatsApp', style: GText.sans(size: 13, color: GColors.marca)),
            ),
          ),
        TextField(
          controller: _name,
          inputFormatters: [maxChars(Limits.maxNameLength)],
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Coca 600 ml', errorText: _errors['name']),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Precio de venta',
                  helperText: 'Lo que paga el cliente',
                  helperMaxLines: 2,
                  prefixText: '\$ ',
                  errorText: _errors['price'],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Costo de compra',
                  helperText: 'Lo que pagas al proveedor',
                  helperMaxLines: 2,
                  hintText: 'Opcional',
                  prefixText: '\$ ',
                  errorText: _errors['cost'],
                ),
              ),
            ),
          ],
        ),
        _MarginNote(price: parseMoney(_price.text), cost: parseMoney(_cost.text)),
        const SizedBox(height: 10),
        // Con tallas, cada talla lleva su código (en Etiquetas se les pone uno).
        if (!_variants)
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            inputFormatters: [maxChars(Limits.maxBarcodeLength)],
            decoration: InputDecoration(
              labelText: 'Código de barras (opcional)',
              prefixIcon: const Icon(Icons.qr_code_2, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Leer con la cámara',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final code = await scanOneCode(context);
                  if (code == null || !mounted) return;
                  setState(() {
                    _barcode.text = code;
                    _errors.remove('barcode');
                  });
                },
              ),
              errorText: _errors['barcode'],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(shownPhoto == null ? 'Icono' : 'Foto (si no carga, se ve el icono)', style: GText.sans(size: 13)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => plan.limits.photos
                  ? _pickPhoto(shownPhoto != null)
                  : showUpgradeSheet(
                      context,
                      reason:
                          'En el plan ${plan.label} los productos usan iconos. '
                          'Con fotos reales tus clientes reconocen mejor lo que venden.',
                      needed: Plan.emprendedor,
                    ),
              icon: Icon(plan.limits.photos ? Icons.photo_camera_outlined : Icons.lock_outline, size: 16),
              label: Text(
                shownPhoto == null ? 'Usar foto' : 'Cambiar foto',
                style: GText.sans(size: 12.5, color: GColors.marca),
              ),
            ),
          ],
        ),
        if (shownPhoto != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(shownPhoto, width: 72, height: 72, fit: BoxFit.cover, gaplessPlayback: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _photo != null
                        ? 'Foto nueva: se guarda al darle Guardar.'
                        : 'Sale en Cobrar, en el inventario y en las mesas.',
                    style: GText.muted(size: 12.5),
                  ),
                ),
              ],
            ),
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
                  borderRadius: BorderRadius.circular(GShape.radiusSmall),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _icon == e.key ? GColors.tinta : GColors.hundido,
                      borderRadius: BorderRadius.circular(GShape.radiusSmall),
                    ),
                    child: Icon(e.value, size: 20, color: _icon == e.key ? GColors.fondo : GColors.cafe),
                  ),
                ),
              ),
          ],
        ),
        // Solo si el negocio tiene mesas: si no, todo se vende en el mostrador y no hay nada que elegir.
        if (ref.watch(storeProvider.select((s) => s.uses(Module.restaurante)))) ...[
          const SizedBox(height: 14),
          Text('Dónde se vende', style: GText.label()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in ProductPlace.values)
                ChoiceChip(label: Text(p.label), selected: _place == p, onSelected: (_) => setState(() => _place = p)),
            ],
          ),
          const SizedBox(height: 4),
          Text(switch (_place) {
            ProductPlace.todos => 'Sale en el menú de las mesas y en Cobrar.',
            ProductPlace.mesas => 'Solo en el menú de las mesas; no sale en Cobrar.',
            ProductPlace.mostrador => 'Solo en Cobrar; no sale en el menú de las mesas.',
          }, style: GText.muted(size: 12.5)),
        ],
        const SizedBox(height: 10),
        // Para zapatos y ropa. En una fonda o en comida por encargo no hay tallas.
        if (!{BusinessType.restaurante, BusinessType.encargos}.contains(ref.watch(storeProvider).businessType))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _variants,
            activeThumbColor: GColors.marca,
            onChanged: (v) => setState(() {
              _variants = v;
              _errors.remove('sizes');
            }),
            title: Text('Tiene tallas o colores', style: GText.sans(size: 14)),
            subtitle: Text('Zapatos, ropa: cada talla lleva sus piezas', style: GText.muted()),
          ),
        if (_variants)
          ..._variantSection(current)
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _track,
            activeThumbColor: GColors.marca,
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
                      inputFormatters: const [QtyInputFormatter()],
                      decoration: InputDecoration(labelText: 'Tengo ahora', errorText: _errors['stock']),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [QtyInputFormatter()],
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
                color: GColors.superficie,
                border: Border.all(color: GColors.linea),
                borderRadius: BorderRadius.circular(GShape.radiusSmall),
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
                          inputFormatters: const [QtyInputFormatter()],
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

  /// Tallas, colores y cuántas piezas hay de cada combinación.
  List<Widget> _variantSection(Product? current) {
    final store = ref.watch(storeProvider);
    final byKey = {for (final v in _existing) variantKey(v.size, v.color): v};
    final combos = _combos;
    final hidden = [
      for (final v in _existing)
        if (!combos.any((c) => variantKey(c.size, c.color) == variantKey(v.size, v.color))) v.variantLabel,
    ];
    final hadStock = current != null && !store.isModel(current) && current.trackStock && current.stock > 0;
    return [
      TextField(
        controller: _sizes,
        onChanged: (_) => setState(() => _errors.remove('sizes')),
        decoration: InputDecoration(
          labelText: 'Tallas',
          hintText: '22, 23, 24 · CH, M, G',
          helperText: 'Sepáralas con comas',
          errorText: _errors['sizes'],
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final e in sizePresets.entries)
            ActionChip(
              label: Text(e.key, style: GText.sans(size: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _sizes.text = e.value.join(', ');
                _errors.remove('sizes');
              }),
            ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _colors,
        onChanged: (_) => setState(() => _errors.remove('sizes')),
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Colores (opcional)', hintText: 'Negro, Blanco, Café'),
      ),
      if (hadStock) ...[
        const SizedBox(height: 10),
        Text(
          'Tenía ${qtyLabel(current.stock)} piezas sin talla: escribe cuántas hay de cada una.',
          style: GText.sans(size: 13, color: GColors.marcaOscura),
        ),
      ],
      if (combos.isNotEmpty) ...[
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Precio (si cambia) y piezas de cada una', style: GText.label())),
            Text('${combos.length} ${combos.length == 1 ? 'talla' : 'tallas'}', style: GText.muted(size: 12)),
          ],
        ),
        const SizedBox(height: 4),
        for (final c in combos.take(maxVariants))
          Builder(
            builder: (context) {
              final key = variantKey(c.size, c.color);
              final old = byKey[key] == null ? null : store.productById(byKey[key]!.id);
              final reserved = old == null ? 0.0 : store.reservedOf(old.id);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GColors.linea)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([?c.size, ?c.color].join(' · '), style: GText.sans(size: 14, weight: FontWeight.w700)),
                          if (old != null)
                            Text(
                              'Hay ${qtyLabel(old.stock)}${reserved > 0 ? ' · ${qtyLabel(reserved)} apartada${reserved == 1 ? '' : 's'}' : ''}',
                              style: GText.muted(size: 12),
                            ),
                        ],
                      ),
                    ),
                    // Precio propio (las tallas grandes a veces cuestan más); vacío = el del modelo.
                    SizedBox(
                      width: 86,
                      child: TextField(
                        controller: _priceFor(key),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: const [MoneyInputFormatter()],
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixText: '\$',
                          hintText: centsInput(parseMoney(_price.text) ?? 0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 92,
                      child: TextField(
                        controller: _qtyFor(key),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: const [QtyInputFormatter()],
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(isDense: true, hintText: old == null ? 'Hay: 0' : 'Llegó'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
      if (hidden.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Se van a ocultar: ${hidden.join(', ')}', style: GText.sans(size: 12.5, color: GColors.rojo)),
      ],
      const SizedBox(height: 10),
      TextField(
        controller: _variantMin,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [QtyInputFormatter()],
        decoration: InputDecoration(
          labelText: 'Avisarme cuando a una talla le queden',
          hintText: 'Opcional: 1',
          errorText: _errors['vmin'],
        ),
      ),
    ];
  }
}

/// Debajo de precio y costo: cuánto se gana por pieza, para ver si conviene el precio.
class _MarginNote extends StatelessWidget {
  const _MarginNote({required this.price, required this.cost});

  final int? price;
  final int? cost;

  @override
  Widget build(BuildContext context) {
    final p = price, c = cost;
    final margin = (p == null || c == null) ? null : marginPct(priceCents: p, costCents: c);
    if (margin == null) return const SizedBox(height: 4);
    final profit = p! - c!;
    final color = marginColor(margin);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(GShape.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(profit > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              profit > 0
                  ? 'Ganas ${money(profit)} por pieza · margen ${(margin * 100).round()}%'
                  : profit == 0
                  ? 'No ganas nada: el precio es igual al costo'
                  : 'Pierdes ${money(-profit)} por pieza',
              style: GText.sans(size: 13.5, weight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
