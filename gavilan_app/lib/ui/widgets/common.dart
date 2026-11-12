import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/plan.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../account/account_screen.dart';
import 'buttons.dart';

/// Texto y color del estado de respaldo para la pastilla del encabezado.
(String, Color) syncLabel(SyncStatus s) {
  if (!s.online) return ('Sin internet', GColors.izamal);
  if (!s.configured || !s.signedIn || !s.linked) return ('Sin respaldo', GColors.tintaTenue);
  if (s.problem != null) return ('Revisar respaldo', GColors.rojo);
  if (s.pending > 0) return ('Por subir: ${s.pending}', GColors.izamal);
  if (s.busy) return ('Respaldando…', GColors.izamal);
  return ('Respaldado', GColors.cenote);
}

IconData _syncIcon(String label) => switch (label) {
  'Respaldado' => Icons.cloud_done_rounded,
  'Sin internet' => Icons.cloud_off_rounded,
  'Sin respaldo' => Icons.cloud_outlined,
  'Revisar respaldo' => Icons.error_outline_rounded,
  _ => Icons.cloud_upload_rounded,
};

/// Encabezado con el gavilán, nombre del negocio y estado del respaldo.
class BusinessHeader extends ConsumerWidget {
  const BusinessHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final (label, dot) = syncLabel(ref.watch(syncProvider));
    final open = store.openSession != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          // En la computadora el gavilán ya va en el menú de la izquierda.
          if (MediaQuery.sizeOf(context).width < 900) ...[
            Image.asset('assets/hawk/gavilan.png', width: 54, semanticLabel: 'Gavilán'),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.sans(size: 17, weight: FontWeight.w800).copyWith(letterSpacing: -0.2),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      open ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 13,
                      color: open ? GColors.cenote : GColors.rojo,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${open ? 'Caja abierta' : 'Caja cerrada'} · $label',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GText.sans(
                          size: 12,
                          weight: FontWeight.w600,
                          color: open ? GColors.tintaSuave : GColors.rojo,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Respaldo: $label',
            child: Tooltip(
              message: label,
              child: Pressable(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
                scale: 0.9,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: dot.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(_syncIcon(label), size: 21, color: dot),
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
    final sync = ref.watch(syncProvider);
    if (sync.online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: GColors.izamalSuave, borderRadius: BorderRadius.circular(GShape.radiusSmall)),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: GColors.cafe),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sync.linked
                  ? 'Sin internet. Todo se guarda aquí y se sube solo al volver la señal.'
                  : 'Sin internet. Todo se guarda en este teléfono.',
              style: GText.sans(size: 12.5, weight: FontWeight.w600, color: GColors.cafe),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: GText.title())),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: GText.muted(size: 13))],
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
              Text(title, style: GText.sans(size: 21, weight: FontWeight.w800).copyWith(letterSpacing: -0.3)),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Cerrar',
          style: IconButton.styleFrom(backgroundColor: GColors.hundido, foregroundColor: GColors.tinta),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }
}

/// Abre una hoja inferior con el estilo Gavilán (esquinas redondas, asa para arrastrar, teclado considerado).
Future<T?> showGSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: builder(ctx)),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: GColors.fondo, borderRadius: BorderRadius.circular(GShape.radius)),
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
                        child: Icon(Icons.check, size: 16, color: GColors.cenote),
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
      Plan.semilla => GColors.cafe,
      Plan.emprendedor => GColors.marca,
      Plan.negocio => GColors.cenote,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(
        plan.label,
        style: GText.sans(size: 11.5, weight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ---------- Piezas del diseño 2 (tarjetas, cifras, listas animadas) ----------

/// Tarjeta blanca con sombra suave.
class GCard extends StatelessWidget {
  const GCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: GShape.card(),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Cifra grande para el encabezado de una pantalla ("En la calle", "Debe haber en caja").
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.cents,
    this.color = GColors.tinta,
    this.icon,
    this.caption,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final String label;
  final int cents;
  final Color color;
  final IconData? icon;
  final String? caption;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return GCard(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: GText.label()),
                const SizedBox(height: 6),
                // El monto cuenta hacia arriba al aparecer.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: cents.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(v.round()), style: GText.amount(size: 34, color: color)),
                  ),
                ),
                if (caption != null) ...[const SizedBox(height: 4), Text(caption!, style: GText.muted(size: 13))],
              ],
            ),
          ),
          if (icon != null)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
        ],
      ),
    );
  }
}

/// Inicial del cliente en un círculo de color (siempre el mismo color para el mismo nombre).
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  static const _colors = [GColors.marca, GColors.cenote, Color(0xFF6B4FA0), Color(0xFF2F6DB5), Color(0xFFB27C00)];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.codeUnits.fold(0, (a, c) => a + c) % _colors.length];
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(
        letter,
        style: GText.sans(size: size * 0.42, weight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// Botón pequeño de color suave, para acciones dentro de una fila ("Abonar").
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onTap, this.color = GColors.cenote, this.icon});

  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 5)],
            Text(
              label,
              style: GText.sans(size: 13, weight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aparece deslizándose desde abajo, un poco después que el anterior: las listas se sienten vivas.
class EnterAnimation extends StatelessWidget {
  const EnterAnimation({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10)) * 35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Interval(delay / (320 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Título de sección dentro de una pantalla.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: GText.sans(size: 16, weight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Color de un margen de ganancia: rojo si se pierde, ámbar si es muy poco (menos de 15%), cenote si va bien.
Color marginColor(double margin) => margin <= 0
    ? GColors.rojo
    : margin < 0.15
    ? const Color(0xFFB27C00)
    : GColors.cenote;
