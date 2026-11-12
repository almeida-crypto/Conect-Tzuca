import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../scan/scan_screen.dart';
import '../widgets/product_icons.dart';
import 'cart_sheet.dart';
import 'pay_sheet.dart';
import 'quick_sale_sheet.dart';
import 'shortcuts_help.dart';

/// Ancho desde el que la app se acomoda como punto de venta de computadora.
const wideLayout = 900.0;

class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({super.key, this.active = true});

  /// Es la pestaña a la vista: solo entonces escucha al lector de códigos.
  final bool active;

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Teclado de la computadora (y lectores de códigos, que "escriben" el código y dan Enter).
  ///
  /// - F2 cobra, F3 abre la venta rápida y F1 muestra los atajos, aunque se esté en el buscador.
  /// - Esc borra la búsqueda o, si no hay, vacía la cuenta (con "Deshacer").
  /// - Sin ningún campo seleccionado, lo que se teclea va al buscador; Enter agrega el producto.
  /// - Con el buscador vacío, + y − cambian la cantidad del último producto de la cuenta.
  bool _onKey(KeyEvent e) {
    if (e is KeyUpEvent || !mounted || !widget.active || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final key = e.logicalKey;
    final repeat = e is KeyRepeatEvent;
    if (!repeat) {
      if (key == LogicalKeyboardKey.f2) {
        _startPayment();
        return true;
      }
      if (key == LogicalKeyboardKey.f3) {
        showQuickSaleSheet(context);
        return true;
      }
      if (key == LogicalKeyboardKey.f1) {
        showShortcutsHelp(context);
        return true;
      }
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    final typing = focus != null && focus.findAncestorWidgetOfExactType<EditableText>() != null;
    if (key == LogicalKeyboardKey.escape && !repeat) {
      if (_query.isNotEmpty || typing) {
        _setQuery('');
        _searchFocus.unfocus();
        return true;
      }
      if (ref.read(cartProvider).isNotEmpty) {
        _clearCart();
        return true;
      }
      return false;
    }
    if (typing) return false;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_query.trim().isEmpty) return false;
      _submitSearch(_query);
      return true;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (_query.isEmpty) return false;
      _setQuery(_query.substring(0, _query.length - 1));
      return true;
    }
    final ch = e.character;
    if (_query.isEmpty && (key == LogicalKeyboardKey.numpadAdd || ch == '+')) {
      _bumpLast(1);
      return true;
    }
    if (_query.isEmpty && (key == LogicalKeyboardKey.numpadSubtract || ch == '-')) {
      _bumpLast(-1);
      return true;
    }
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 32 && ch.codeUnitAt(0) != 127) {
      if (_query.isEmpty && ch == ' ') return false;
      _setQuery(_query + ch);
      return true;
    }
    return false;
  }

  void _setQuery(String value) {
    _search.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    setState(() => _query = value);
  }

  void _bumpLast(double delta) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final last = cart.last;
    ref.read(cartProvider.notifier).setQty(last.key, last.qty + delta);
  }

  void _clearCart() {
    final before = ref.read(cartProvider);
    ref.read(cartProvider.notifier).clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Se vació la cuenta'),
          action: SnackBarAction(label: 'Deshacer', onPressed: () => ref.read(cartProvider.notifier).replace(before)),
        ),
      );
  }

  /// Productos que coinciden con lo escrito, por nombre o código.
  List<Product> _matching(StoreState store, String text) {
    final q = text.trim().toLowerCase();
    return store.activeProducts
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
        .toList();
  }

  /// Enter en el buscador: un código de barras o un nombre con un solo resultado se agrega a la cuenta.
  /// Con varios resultados se quedan a la vista para escoger.
  void _submitSearch(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final store = ref.read(storeProvider);
    final byCode = store.productByBarcode(text);
    final matches = byCode != null ? [byCode] : _matching(store, text);
    if (matches.length == 1) {
      ref.read(cartProvider.notifier).addProduct(matches.single);
      _setQuery('');
    } else if (matches.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('No hay producto con "$text"')));
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
    final products = _matching(store, q);

    final wide = MediaQuery.sizeOf(context).width >= wideLayout;
    final catalog = Column(
      children: [
        const BusinessHeader(),
        const OfflineNote(),
        if (store.openSession == null) _ClosedCashBanner(onOpen: () => showOpenCashDialog(context, ref)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: _submitSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar o escribir código',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _setQuery(''),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SquareButton(
                icon: Icons.qr_code_scanner,
                tooltip: 'Escanear con la cámara',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
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
                    final cols = (box.maxWidth / 180).floor().clamp(2, 6);
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(16, 2, 16, wide ? 24 : 200),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 80,
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
    );

    // Computadora: catálogo a la izquierda y la cuenta siempre a la vista a la derecha.
    if (wide) {
      return Row(
        children: [
          Expanded(child: catalog),
          SizedBox(width: 380, child: CartPanel(onPay: _startPayment)),
        ],
      );
    }
    return Stack(
      children: [
        catalog,
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
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: light ? GColors.superficie : GColors.tinta,
            borderRadius: BorderRadius.circular(GShape.radius),
            border: light ? Border.all(color: GColors.linea, width: 1.5) : null,
          ),
          child: Icon(icon, size: 22, color: light ? GColors.tinta : Colors.white, semanticLabel: tooltip),
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
    final picked = qty > 0;
    return Semantics(
      button: true,
      label: '${product.name}, ${money(product.priceCents)}${picked ? ', ${qtyLabel(qty)} en la cuenta' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: GColors.superficie,
            borderRadius: BorderRadius.circular(GShape.radius),
            border: Border.all(color: picked ? GColors.marca : Colors.transparent, width: 2),
            boxShadow: GShape.shadow,
          ),
          child: Row(
            children: [
              ProductBadge(product.iconId),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 13, weight: FontWeight.w600).copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      out ? 'Agotado' : money(product.priceCents, hideZeroCents: true),
                      style: out
                          ? GText.sans(size: 13, weight: FontWeight.w700, color: GColors.rojo)
                          : GText.amount(size: 17),
                    ),
                  ],
                ),
              ),
              // Cuántos van en la cuenta: aparece con un pequeño salto.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: child,
                ),
                child: picked
                    ? Container(
                        key: ValueKey(qty),
                        constraints: const BoxConstraints(minWidth: 26),
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: GColors.marca, borderRadius: BorderRadius.circular(13)),
                        child: Text(
                          qtyLabel(qty),
                          style: GText.sans(size: 12.5, weight: FontWeight.w800, color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('vacío')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La cuenta en curso: panel blanco que sube desde abajo con el total animado.
class _CartStrip extends ConsumerWidget {
  const _CartStrip({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final count = cart.fold(0.0, (a, l) => a + l.qty);
    return Container(
      decoration: const BoxDecoration(
        color: GColors.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GShape.radiusSheet)),
        boxShadow: [BoxShadow(color: Color(0x1A1B1A19), blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: GColors.linea, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 18, color: GColors.tintaTenue),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Toca un producto para empezar la cuenta.', style: GText.muted(size: 13))),
                      ],
                    ),
                  )
                : InkWell(
                    onTap: () => showCartSheet(context),
                    borderRadius: BorderRadius.circular(GShape.radiusSmall),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          for (final l in cart.reversed.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${qtyLabel(l.qty)} × ${l.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GText.sans(size: 13, color: GColors.tintaSuave),
                                    ),
                                  ),
                                  Text(money(l.totalCents), style: GText.figures(size: 13)),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Text(cart.length > 2 ? '+ ${cart.length - 2} más' : '', style: GText.muted(size: 12.5)),
                              const Spacer(),
                              Text(
                                'Ver cuenta',
                                style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.marca),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: GColors.marca),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0 ? 'TOTAL' : 'TOTAL · ${qtyLabel(count)} ${count == 1 ? 'artículo' : 'artículos'}',
                      style: GText.label(),
                    ),
                    const SizedBox(height: 2),
                    // El total sube o baja deslizándose cuando cambia.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                      child: FittedBox(
                        key: ValueKey(total),
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(money(total), style: GText.amount(size: 32)),
                      ),
                    ),
                  ],
                ),
              ),
              GButton(
                label: 'Cobrar',
                icon: Icons.arrow_forward_rounded,
                kind: GButtonKind.money,
                big: true,
                onPressed: onPay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClosedCashBanner extends StatelessWidget {
  const _ClosedCashBanner({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: GColors.rojoSuave, borderRadius: BorderRadius.circular(GShape.radiusSmall)),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: GColors.rojo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'La caja está cerrada. Ábrela para cobrar.',
              style: GText.sans(size: 13, weight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            child: Text(
              'Abrir caja',
              style: GText.sans(size: 13, weight: FontWeight.w800, color: GColors.marca),
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
