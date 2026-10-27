import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import 'buttons.dart';

/// Encabezado con el gavilán, nombre del negocio y estado de conexión.
class BusinessHeader extends ConsumerWidget {
  const BusinessHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final online = ref.watch(onlineProvider);
    final open = store.openSession != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          SvgPicture.asset('assets/hawk/gavilan.svg', width: 54, semanticsLabel: 'Gavilán'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.sans(size: 15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  open ? 'Caja abierta' : 'Caja cerrada',
                  style: GText.sans(size: 11, color: open ? GColors.tintaSuave : GColors.rojo),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: online ? 'En línea' : 'Sin internet',
            child: InkWell(
              onTap: () => ref.read(onlineProvider.notifier).toggle(),
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: GColors.papel2,
                  border: Border.all(color: GColors.linea),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: online ? GColors.monte : GColors.ocre),
                    ),
                    const SizedBox(width: 5),
                    Text(online ? 'En línea' : 'Sin internet', style: GText.sans(size: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso discreto cuando no hay internet: todo se guarda en el teléfono.
class OfflineNote extends ConsumerWidget {
  const OfflineNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(onlineProvider)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: GColors.ocre.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4)),
      child: Text(
        'Sin internet. Todo se guarda aquí y se sube solo al volver la señal.',
        style: GText.sans(size: 12, color: GColors.pardo),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: GText.title())),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: GText.muted())],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Encabezado de hoja inferior con botón de cerrar.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null) Text(caption!, style: GText.muted(size: 13)),
              Text(title, style: GText.sans(size: 20, weight: FontWeight.w800)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, color: GColors.tinta),
        ),
      ],
    );
  }
}

/// Abre una hoja inferior con el estilo Gavilán (borde superior de tinta, teclado considerado).
Future<T?> showGSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GColors.tinta, width: 3)),
        ),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: builder(ctx)),
      ),
    ),
  );
}

/// Hoja que explica qué plan desbloquea algo. No cobra nada: solo informa.
Future<void> showUpgradeSheet(BuildContext context, {required String reason, required Plan needed}) {
  return showGSheet(
    context,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeader('Disponible en plan ${needed.label}', caption: 'Tu plan actual tiene un límite'),
        const SizedBox(height: 6),
        Text(reason, style: GText.sans(size: 14, weight: FontWeight.w400)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GColors.papelClaro,
            border: Border.all(color: GColors.linea),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${needed.label} · ${needed.price}', style: GText.sans(size: 15, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final h in planHighlights(needed))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check, size: 16, color: GColors.monte),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(h, style: GText.sans(size: 13, weight: FontWeight.w400)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GButton(label: 'Entendido', expand: true, onPressed: () => Navigator.of(ctx).pop()),
      ],
    ),
  );
}

/// Etiqueta pequeña de plan.
class PlanBadge extends StatelessWidget {
  const PlanBadge(this.plan, {super.key});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final color = switch (plan) {
      Plan.semilla => GColors.pardo,
      Plan.emprendedor => GColors.oxido,
      Plan.negocio => GColors.monte,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        plan.label,
        style: GText.sans(size: 11, weight: FontWeight.w800, color: color),
      ),
    );
  }
}
