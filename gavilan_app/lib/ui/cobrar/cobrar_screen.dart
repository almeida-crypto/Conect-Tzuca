import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../caja/cash_dialogs.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';
import 'cart_sheet.dart';
import 'pay_sheet.dart';
import 'quick_sale_sheet.dart';

class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({super.key});

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Un lector de códigos USB "escribe" el código y da Enter: aquí lo buscamos.
  void _submitCode(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    final product = ref.read(storeProvider).productByBarcode(code);
    if (product != null) {
      ref.read(cartProvider.notifier).addProduct(product);
      _search.clear();
      setState(() => _query = '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay producto con el código $code')));
    }
  }

  Future<void> _startPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Toca un producto para empezar la cuenta')));
      return;
    }
    if (ref.read(storeProvider).openSession == null) {
      final opened = await showOpenCashDialog(context, ref);
      if (!opened || !mounted) return;
    }
    await showPaySheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final cart = ref.watch(cartProvider);
    final q = _query.trim().toLowerCase();
    final products = store.activeProducts
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            const BusinessHeader(),
            const OfflineNote(),
            if (store.openSession == null) _ClosedCashBanner(onOpen: () => showOpenCashDialog(context, ref)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      onSubmitted: _submitCode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar o escribir código',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SquareButton(
                    icon: Icons.qr_code_scanner,
                    tooltip: 'Escanear con la cámara',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La cámara como escáner llega en el siguiente paso. Mientras, escribe el código y da Enter.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SquareButton(
                    icon: Icons.dialpad,
                    tooltip: 'Venta rápida por monto',
                    light: true,
                    onTap: () => showQuickSaleSheet(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? _EmptyCatalog(searching: q.isNotEmpty)
                  : LayoutBuilder(
                      builder: (context, box) {
                        final cols = (box.maxWidth / 170).floor().clamp(2, 6);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 190),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            mainAxisExtent: 78,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, i) {
                            final p = products[i];
                            final inCart = cart.where((l) => l.productId == p.id).fold(0.0, (a, l) => a + l.qty);
                            return _ProductTile(
                              product: p,
                              qty: inCart,
                              onTap: () => ref.read(cartProvider.notifier).addProduct(p),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _CartStrip(onPay: _startPayment)),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.tooltip, required this.onTap, this.light = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: light ? GColors.papel2 : GColors.tinta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: light ? const BorderSide(color: GColors.linea) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 21, color: light ? GColors.tinta : GColors.papel, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.qty, required this.onTap});

  final Product product;
  final double qty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = product.trackStock && product.stock <= 0;
    return Semantics(
      button: true,
      label: '${product.name}, ${money(product.priceCents)}${qty > 0 ? ', ${qtyLabel(qty)} en la cuenta' : ''}',
      excludeSemantics: true,
      // Capa de abajo = borde grueso de "tecla"; encima, la ficha.
      child: Container(
        padding: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(color: const Color(0xFFB9AE99), borderRadius: BorderRadius.circular(4)),
        child: Material(
          color: GColors.papel2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: GColors.linea),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(productIcon(product.iconId), size: 18, color: GColors.pardo),
                      const Spacer(),
                      Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GText.sans(size: 12.5)),
                      const SizedBox(height: 2),
                      Text(money(product.priceCents, hideZeroCents: true), style: GText.amount(size: 18)),
                    ],
                  ),
                  if (qty > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: GColors.oxido, borderRadius: BorderRadius.circular(2)),
                        child: Text(
                          qtyLabel(qty),
                          style: GText.sans(size: 12, weight: FontWeight.w800, color: GColors.papel),
                        ),
                      ),
                    )
                  else if (out)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Text('Agotado', style: GText.sans(size: 11, color: GColors.rojo)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La cuenta en curso, como talonario con línea de corte.
class _CartStrip extends ConsumerWidget {
  const _CartStrip({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    return Container(
      decoration: const BoxDecoration(color: GColors.papelClaro),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CutLine(),
          InkWell(
            onTap: cart.isEmpty ? null : () => showCartSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: cart.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('Toca un producto para empezar la cuenta.', style: GText.muted()),
                      ),
                    )
                  : Column(
                      children: [
                        for (final l in cart.take(2))
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${qtyLabel(l.qty)} x ${l.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GText.mono(size: 11.5),
                                ),
                              ),
                              Text(money(l.totalCents), style: GText.mono(size: 11.5)),
                            ],
                          ),
                        Row(
                          children: [
                            Text(cart.length > 2 ? '+ ${cart.length - 2} más' : '', style: GText.mono(size: 11.5)),
                            const Spacer(),
                            Text('Editar cuenta', style: GText.sans(size: 11.5, color: GColors.oxido)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL', style: GText.label()),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(money(total), style: GText.amount(size: 30)),
                      ),
                    ],
                  ),
                ),
                GButton(label: 'Cobrar', big: true, onPressed: onPay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CutLine extends StatelessWidget {
  const _CutLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          CustomPaint(size: const Size(double.infinity, 2), painter: _DashPainter()),
          Container(
            margin: const EdgeInsets.only(left: 12),
            color: GColors.papelClaro,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Icon(Icons.content_cut, size: 14, color: GColors.tintaSuave),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x73221C17)
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 5, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _ClosedCashBanner extends StatelessWidget {
  const _ClosedCashBanner({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: GColors.rojo),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(child: Text('La caja está cerrada. Ábrela para cobrar.', style: GText.sans(size: 13))),
          TextButton(
            onPressed: onOpen,
            child: Text(
              'Abrir caja',
              style: GText.sans(size: 13, weight: FontWeight.w800, color: GColors.oxido),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 190),
      child: Text(
        searching
            ? 'Nada coincide con tu búsqueda. Prueba otro nombre o usa la venta rápida.'
            : 'Agrega tus productos en Inventario, o cobra por monto con la venta rápida.',
        textAlign: TextAlign.center,
        style: GText.muted(size: 14),
      ),
    );
  }
}
