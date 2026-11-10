import 'package:flutter/material.dart';
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
    (Icons.receipt_long_outlined, 'Cobrar'),
    (Icons.menu_book_outlined, 'Fiados'),
    (Icons.inventory_2_outlined, 'Inventario'),
    (Icons.calculate_outlined, 'Caja'),
    (Icons.apps_outlined, 'Más'),
  ];

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    // Meseros y cocina solo usan el restaurante.
    if (ref.watch(permissionsProvider).restaurantOnly) {
      return RestaurantScreen(embedded: true, kitchen: ref.watch(syncProvider).role == MemberRole.kitchen);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            const CobrarScreen(),
            const FiadosScreen(),
            const InventarioScreen(),
            CajaScreen(onGoToCobrar: () => _go(0)),
            const MasScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: GColors.papel,
            border: Border(top: BorderSide(color: GColors.linea)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: _tab == i,
                    label: _tabs[i].$2,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _go(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_tabs[i].$1, size: 22, color: _tab == i ? GColors.oxido : GColors.tintaTenue),
                          const SizedBox(height: 2),
                          Text(
                            _tabs[i].$2,
                            style: GText.sans(size: 11, color: _tab == i ? GColors.oxido : GColors.tintaTenue),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _tab == i ? 18 : 0,
                            height: 3,
                            color: GColors.oxido,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
