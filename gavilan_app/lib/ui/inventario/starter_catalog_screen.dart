import '../../core/limits.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../domain/starter_catalog.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';

/// Lista de productos comunes de tiendita: se marcan los que se venden, se escribe su precio de venta y se
/// dan de alta todos juntos. Regresa cuántos se agregaron.
class StarterCatalogScreen extends ConsumerStatefulWidget {
  const StarterCatalogScreen({super.key});

  @override
  ConsumerState<StarterCatalogScreen> createState() => _StarterCatalogScreenState();
}

class _StarterCatalogScreenState extends ConsumerState<StarterCatalogScreen> {
  final _prices = <StarterItem, TextEditingController>{};
  final _picked = <StarterItem>{};
  bool _showErrors = false;

  @override
  void dispose() {
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _price(StarterItem item) => _prices.putIfAbsent(item, TextEditingController.new);

  int? _priceOf(StarterItem item) {
    final v = parseMoney(_prices[item]?.text ?? '');
    return (v == null || v == 0) ? null : v;
  }

  List<StarterItem> get _missingPrice => [
    for (final i in _picked)
      if (_priceOf(i) == null) i,
  ];

  void _toggle(StarterItem item) => setState(() => _picked.contains(item) ? _picked.remove(item) : _picked.add(item));

  Future<void> _save() async {
    if (_missingPrice.isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    final store = ref.read(storeProvider);
    final plan = ref.read(planProvider);
    final max = plan.limits.maxProducts;
    if (max != null && store.activeProducts.length + _picked.length > max) {
      final room = (max - store.activeProducts.length).clamp(0, max);
      await showUpgradeSheet(
        context,
        reason:
            'Tu plan ${plan.label} permite hasta $max productos. '
            '${room == 0 ? 'Ya no te quedan lugares.' : 'Te quedan $room; marcaste ${_picked.length}.'}',
        needed: plan == Plan.semilla ? Plan.emprendedor : Plan.negocio,
      );
      return;
    }
    final notifier = ref.read(storeProvider.notifier);
    // En el orden de la lista, para que el catálogo quede acomodado igual.
    final ordered = [
      for (final g in starterCatalog)
        for (final i in g.items)
          if (_picked.contains(i)) i,
    ];
    for (final i in ordered) {
      notifier.saveProduct(Product(id: newId(), name: i.name, priceCents: _priceOf(i)!, iconId: i.iconId));
    }
    if (mounted) Navigator.of(context).pop(ordered.length);
  }

  @override
  Widget build(BuildContext context) {
    final existing = {for (final p in ref.watch(storeProvider).activeProducts) p.name.trim().toLowerCase()};
    final missing = _showErrors ? _missingPrice.toSet() : const <StarterItem>{};
    final count = _picked.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elige tus productos', style: GText.sans(size: 17, weight: FontWeight.w800)),
            Text('Marca los que vendes y escribe su precio', style: GText.muted(size: 12)),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'El número gris es solo un ejemplo: escribe el precio de venta de tu tienda. '
                  'Después puedes cambiar nombres y precios, y agregar el costo de compra en Inventario.',
                  style: GText.sans(size: 13.5, weight: FontWeight.w400, color: GColors.tintaSuave),
                ),
              ),
              for (final g in starterCatalog) ...[
                SectionTitle(g.title),
                GCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, item) in g.items.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 64, color: GColors.linea),
                        _ItemRow(
                          item: item,
                          picked: _picked.contains(item),
                          already: existing.contains(item.name.toLowerCase()),
                          missingPrice: missing.contains(item),
                          price: _price(item),
                          onToggle: () => _toggle(item),
                          onPriceChanged: (v) => setState(() {
                            if (v.trim().isNotEmpty) _picked.add(item);
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: GColors.superficie,
          border: Border(top: BorderSide(color: GColors.linea)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    missing.isNotEmpty
                        ? (missing.length == 1
                              ? 'Falta el precio del producto en rojo'
                              : 'Falta el precio de los ${missing.length} productos en rojo')
                        : count == 0
                        ? 'Toca los productos que vendes'
                        : '$count ${count == 1 ? 'producto marcado' : 'productos marcados'}',
                    style: GText.sans(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: missing.isNotEmpty ? GColors.rojo : GColors.tintaSuave,
                    ),
                  ),
                ),
                GButton(
                  label: count == 0 ? 'Agregar' : 'Agregar $count',
                  icon: Icons.check_rounded,
                  onPressed: count == 0 ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.picked,
    required this.already,
    required this.missingPrice,
    required this.price,
    required this.onToggle,
    required this.onPriceChanged,
  });

  final StarterItem item;
  final bool picked;
  final bool already;
  final bool missingPrice;
  final TextEditingController price;
  final VoidCallback onToggle;
  final ValueChanged<String> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: already ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: picked ? GColors.marca : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: picked ? GColors.marca : GColors.linea, width: 2),
              ),
              child: picked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            ProductBadge(item.iconId, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                style: GText.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: already ? GColors.tintaTenue : GColors.tinta,
                ),
              ),
            ),
            if (already)
              Text('Ya lo tienes', style: GText.muted(size: 12.5))
            else
              SizedBox(
                width: 104,
                child: TextField(
                  controller: price,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  onChanged: onPriceChanged,
                  style: GText.figures(size: 14.5, weight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '\$ ',
                    hintText: 'ej. ${item.hintPesos}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    enabledBorder: missingPrice
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GShape.radiusSmall),
                            borderSide: const BorderSide(color: GColors.rojo, width: 1.5),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
