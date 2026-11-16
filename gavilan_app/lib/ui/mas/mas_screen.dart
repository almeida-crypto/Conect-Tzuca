import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/business.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import '../fiados/fiados_screen.dart';
import '../modules/layaways_screen.dart';
import '../onboarding/business_type_screen.dart';
import '../modules/lots_screen.dart';
import '../modules/tandas_screen.dart';
import '../restaurant/restaurant_screen.dart';
import '../team/team_screen.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import 'plan_screen.dart';

/// Módulo adicional del documento maestro y qué plan lo incluye.
class _Module {
  const _Module(this.icon, this.title, this.subtitle, this.needed, this.unlocked, {this.screen, this.module});

  /// Si el negocio puede apagarlo en "Lo que uso" (null = siempre se ve).
  final Module? module;

  final IconData icon;
  final String title;
  final String subtitle;
  final Plan needed;
  final bool Function(PlanLimits) unlocked;

  /// Pantalla del módulo; null mientras no está construido.
  final Widget Function()? screen;
}

final _modules = [
  _Module(
    Icons.shopping_bag_outlined,
    'Apartados',
    'Anticipo, abonos y fecha límite',
    Plan.emprendedor,
    (l) => l.layaways,
    screen: () => const LayawaysScreen(),
    module: Module.apartados,
  ),
  _Module(
    Icons.checkroom_outlined,
    'Pacas y lotes',
    'Cuánto falta para recuperar lo invertido',
    Plan.semilla,
    (l) => true,
    screen: () => const LotsScreen(),
    module: Module.pacas,
  ),
  _Module(
    Icons.event_note_outlined,
    'Pedidos por tanda',
    'Cochinita del domingo, marquesitas, cenas',
    Plan.emprendedor,
    (l) => l.batches,
    screen: () => const TandasScreen(),
    module: Module.tandas,
  ),
  _Module(
    Icons.table_restaurant_outlined,
    'Mesas y cocina',
    'Meseros, comandas y pantalla de cocina',
    Plan.negocio,
    (l) => l.restaurant,
    screen: () => const RestaurantScreen(),
    module: Module.restaurante,
  ),
  _Module(
    Icons.groups_outlined,
    'Equipo y roles',
    'Dueño, cajeros, meseros y cocina',
    Plan.negocio,
    (l) => l.team,
    screen: () => const TeamScreen(),
  ),
  _Module(Icons.print_outlined, 'Impresora de tickets', 'Térmica por Bluetooth o USB', Plan.negocio, (l) => l.printer),
  _Module(
    Icons.computer_outlined,
    'Gavilán en la computadora',
    'Mostrador y reportes en el navegador',
    Plan.emprendedor,
    (l) => l.webPanel,
  ),
];

class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final store = ref.watch(storeProvider);
    final limits = plan.limits;
    final can = ref.watch(permissionsProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenTitle('Más'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Pressable(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanScreen())),
            scale: 0.98,
            // Tarjeta de la cuenta: degradado de achiote, como el plumaje del gavilán.
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GShape.radius),
                gradient: const LinearGradient(
                  colors: [GColors.marca, GColors.marcaOscura],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: GColors.marca.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.businessName,
                          style: GText.sans(size: 18, weight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'Plan ${plan.label}',
                                style: GText.sans(size: 12, weight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              plan.price,
                              style: GText.sans(size: 12.5, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Mi plan',
                    style: GText.sans(size: 13.5, weight: FontWeight.w800, color: Colors.white),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Módulos'),
        Builder(
          builder: (context) {
            // Solo lo que este negocio usa. Mesas ya es una pestaña cuando el restaurante está prendido.
            final visible = [
              for (final m in _modules)
                if (m.module == null ||
                    (store.uses(m.module!) && !(m.module == Module.restaurante && restaurantTab(store, plan))))
                  m,
            ];
            final fiadosHere = restaurantTab(store, plan);
            return GCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (fiadosHere) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(backgroundColor: GColors.fondo, surfaceTintColor: Colors.transparent),
                            body: const SafeArea(top: false, child: FiadosScreen()),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Row(
                          children: [
                            const _IconTile(icon: Icons.menu_book_rounded, color: GColors.marca),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fiados', style: GText.sans(size: 15, weight: FontWeight.w700)),
                                  Text('Quién te debe y sus abonos', style: GText.muted(size: 12.5)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
                          ],
                        ),
                      ),
                    ),
                    if (visible.isNotEmpty) const Divider(height: 1, indent: 68, color: GColors.linea),
                  ],
                  for (final (i, m) in visible.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 68, color: GColors.linea),
                    _ModuleRow(module: m, unlocked: m.unlocked(limits), plan: plan),
                  ],
                ],
              ),
            );
          },
        ),
        if (can.editCatalog) ...[const SectionTitle('Lo que uso'), const _ModulesCard()],
        const SectionTitle('Respaldo en la nube'),
        Builder(
          builder: (context) {
            final (label, dot) = syncLabel(ref.watch(syncProvider));
            final sync = ref.watch(syncProvider);
            return GCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
              child: Row(
                children: [
                  _IconTile(icon: Icons.cloud_rounded, color: dot),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sync.signedIn ? sync.email! : 'Entrar o crear cuenta',
                          style: GText.sans(size: 15, weight: FontWeight.w700),
                        ),
                        Text(label, style: GText.muted(size: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue),
                ],
              ),
            );
          },
        ),
        if (can.resetPhone) ...[
          const SectionTitle('Datos de este teléfono'),
          GCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            onTap: () => _confirmReset(context, ref),
            child: Row(
              children: [
                const _IconTile(icon: Icons.delete_outline_rounded, color: GColors.rojo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrar todo y empezar de nuevo',
                        style: GText.sans(size: 15, weight: FontWeight.w700, color: GColors.rojo),
                      ),
                      Text(
                        'Útil para quitar la tiendita de ejemplo. Lo que ya está en la nube no se borra.',
                        style: GText.muted(size: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo?'),
        content: Text(
          'Se borran de este teléfono los productos, ventas, fiados y cortes de "${store.businessName}". '
          'No se puede deshacer.',
          style: GText.sans(size: 14, weight: FontWeight.w400),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Borrar todo',
              style: GText.sans(size: 14, weight: FontWeight.w800, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(cartProvider.notifier).clear();
    ref.read(planProvider.notifier).set(Plan.semilla);
    ref.read(storeProvider.notifier).resetAll();
  }
}

/// Icono en un cuadro de color suave.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, size: 21, color: color),
  );
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module, required this.unlocked, required this.plan});

  final _Module module;
  final bool unlocked;
  final Plan plan;

  // Solo colores de la paleta: achiote, cenote, Izamal (oscuro, para que se lea) y café.
  static const _colors = [GColors.marca, GColors.cenote, Color(0xFFB27C00), GColors.cafe];

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? _colors[module.title.length % _colors.length] : GColors.tintaTenue;
    return InkWell(
      onTap: () {
        if (!unlocked) {
          showUpgradeSheet(
            context,
            reason: '${module.title}: ${module.subtitle.toLowerCase()}.',
            needed: module.needed,
          );
        } else if (module.screen != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => module.screen!()));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${module.title} viene incluido en tu plan y llega muy pronto.')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            _IconTile(icon: module.icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: GText.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: unlocked ? GColors.tinta : GColors.tintaSuave,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(module.subtitle, style: GText.muted(size: 12.5)),
                ],
              ),
            ),
            if (unlocked && module.screen != null)
              const Icon(Icons.chevron_right_rounded, color: GColors.tintaTenue)
            else if (unlocked)
              Text(
                'Pronto',
                style: GText.sans(size: 12, weight: FontWeight.w600, color: GColors.tintaTenue),
              )
            else ...[
              const Icon(Icons.lock_rounded, size: 15, color: GColors.tintaTenue),
              const SizedBox(width: 4),
              PlanBadge(module.needed),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mesas pasa a ser pestaña principal cuando el restaurante está prendido y el plan lo incluye.
bool restaurantTab(StoreState store, Plan plan) =>
    store.modules != null && store.uses(Module.restaurante) && plan.limits.restaurant;

/// Tipo de negocio y qué módulos se ven. Solo dueño y administradores lo cambian.
class _ModulesCard extends ConsumerWidget {
  const _ModulesCard();

  Future<void> _changeType(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final type = await Navigator.of(context)
        .push<BusinessType>(MaterialPageRoute(builder: (_) => BusinessTypeScreen(current: store.businessType)));
    if (type == null || type == store.businessType || !context.mounted) return;
    ref.read(storeProvider.notifier).setBusinessSetup(type: type, modules: type.defaultModules);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ahora es ${type.label.toLowerCase()}. Puedes prender o apagar módulos aquí mismo.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final type = store.businessType ?? BusinessType.otro;
    return GCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            InkWell(
              onTap: () => _changeType(context, ref),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    _IconTile(icon: businessTypeIcon(type), color: GColors.marca),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo de negocio', style: GText.muted(size: 12.5)),
                          Text(type.label, style: GText.sans(size: 15, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Text(
                      'Cambiar',
                      style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.marca),
                    ),
                  ],
                ),
              ),
            ),
            for (final m in Module.values) ...[
              const Divider(height: 1, indent: 14, color: GColors.linea),
              SwitchListTile(
                value: store.uses(m),
                onChanged: (on) => ref.read(storeProvider.notifier).toggleModule(m, on),
                activeThumbColor: Colors.white,
                activeTrackColor: GColors.cenote,
                inactiveThumbColor: GColors.tintaTenue,
                inactiveTrackColor: GColors.hundido,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                title: Text(m.label, style: GText.sans(size: 15, weight: FontWeight.w700)),
                subtitle: Text(m.description, style: GText.muted(size: 12.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
