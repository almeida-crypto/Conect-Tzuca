import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/team.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../caja/caja_screen.dart';
import '../cobrar/cobrar_screen.dart';
import '../fiados/fiados_screen.dart';
import '../inventario/inventario_screen.dart';
import '../mas/mas_screen.dart';
import '../restaurant/restaurant_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.point_of_sale_rounded, 'Cobrar'),
    (Icons.menu_book_rounded, 'Fiados'),
    (Icons.inventory_2_rounded, 'Inventario'),
    (Icons.account_balance_wallet_rounded, 'Caja'),
    (Icons.grid_view_rounded, 'Más'),
  ];

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    // Meseros y cocina solo usan el restaurante.
    if (ref.watch(permissionsProvider).restaurantOnly) {
      return RestaurantScreen(embedded: true, kitchen: ref.watch(syncProvider).role == MemberRole.kitchen);
    }
    final wide = MediaQuery.sizeOf(context).width >= wideLayout;
    // En la computadora, las pestañas que son listas no se estiran de lado a lado.
    Widget narrow(Widget child) => wide
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: child),
          )
        : child;
    final pages = TweenAnimationBuilder<double>(
      key: ValueKey(_tab),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: 0.35 + 0.65 * t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: IndexedStack(
        index: _tab,
        children: [
          CobrarScreen(active: _tab == 0),
          narrow(const FiadosScreen()),
          narrow(const InventarioScreen()),
          narrow(CajaScreen(onGoToCobrar: () => _go(0))),
          narrow(const MasScreen()),
        ],
      ),
    );

    // Computadora: menú a la izquierda, como un punto de venta de mostrador.
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(tabs: _tabs, selected: _tab, onSelect: _go),
            Expanded(child: SafeArea(child: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: GColors.superficie,
          boxShadow: [BoxShadow(color: Color(0x141B1A19), blurRadius: 16, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _tab == i,
                      label: _tabs[i].$2,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_tab != i) HapticFeedback.selectionClick();
                          _go(i);
                        },
                        child: _NavItem(icon: _tabs[i].$1, label: _tabs[i].$2, selected: _tab == i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestaña: el icono se asienta en una pastilla de color al elegirla.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: selected ? 58 : 40,
          height: 32,
          decoration: BoxDecoration(
            // Cenote, como el botón de cobrar y las cifras de dinero: el achiote queda para la acción principal.
            color: selected ? GColors.cenoteSuave : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(icon, size: 23, color: selected ? GColors.cenote : GColors.tintaTenue),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GText.sans(
            size: 11.5,
            weight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? GColors.tinta : GColors.tintaTenue,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

/// Menú lateral de la computadora: el gavilán arriba y las pestañas en columna.
class _SideNav extends StatelessWidget {
  const _SideNav({required this.tabs, required this.selected, required this.onSelect});

  final List<(IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      decoration: const BoxDecoration(
        color: GColors.superficie,
        border: Border(right: BorderSide(color: GColors.linea)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Image.asset('assets/hawk/gavilan.png', width: 64, semanticLabel: 'Gavilán'),
            const SizedBox(height: 22),
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Semantics(
                  button: true,
                  selected: selected == i,
                  label: tabs[i].$2,
                  excludeSemantics: true,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: SizedBox(
                        width: 104,
                        height: 64,
                        child: _NavItem(icon: tabs[i].$1, label: tabs[i].$2, selected: selected == i),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
