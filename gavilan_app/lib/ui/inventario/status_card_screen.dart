import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/share.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/product_icons.dart';

/// Sello de la tarjeta.
const statusStamps = ['Disponible', 'Recién llegado', 'Últimas piezas', 'Oferta'];

/// Fondo de la tarjeta: los colores de Gavilán.
enum StatusCardColor {
  achiote(GColors.marca, Colors.white),
  cenote(GColors.cenote, Colors.white),
  crema(GColors.fondo, GColors.tinta);

  const StatusCardColor(this.background, this.ink);
  final Color background;
  final Color ink;
}

/// Tarjeta para Estados de WhatsApp: la foto del producto, su nombre, el precio y un sello. Se arma en el
/// celular como imagen vertical (1080×1920) y se comparte; no pasa por ningún servidor.
class StatusCardScreen extends ConsumerStatefulWidget {
  const StatusCardScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<StatusCardScreen> createState() => _StatusCardScreenState();
}

class _StatusCardScreenState extends ConsumerState<StatusCardScreen> {
  final _cardKey = GlobalKey();
  String _stamp = statusStamps.first;
  StatusCardColor _color = StatusCardColor.achiote;
  bool _price = true;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(planProvider);
    final product = store.productById(widget.productId)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Tarjeta para Estados', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AspectRatio(
                  aspectRatio: StatusCard.size.aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 18)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: StatusCard(
                            product: product,
                            photo: store.photoOf(product),
                            businessName: store.businessName,
                            logo: plan.limits.logo ? store.logo : null,
                            stamp: _stamp,
                            color: _color,
                            showPrice: _price,
                            watermark: plan.limits.watermark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Sello', style: GText.sans(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in statusStamps)
                  ChoiceChip(
                    label: Text(s),
                    selected: _stamp == s,
                    onSelected: (_) => setState(() => _stamp = s),
                    selectedColor: GColors.marcaSuave,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Color', style: GText.sans(size: 13, weight: FontWeight.w700)),
                const SizedBox(width: 12),
                for (final c in StatusCardColor.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Semantics(
                      button: true,
                      selected: _color == c,
                      label: c.name,
                      child: GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? GColors.tinta : GColors.linea,
                              width: _color == c ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Text('Precio', style: GText.sans(size: 13, weight: FontWeight.w700)),
                Switch(
                  value: _price,
                  onChanged: (v) => setState(() => _price = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: GColors.cenote,
                ),
              ],
            ),
            const SizedBox(height: 14),
            GButton(
              label: 'Compartir',
              icon: Icons.send_outlined,
              kind: GButtonKind.money,
              expand: true,
              big: true,
              onPressed: () => shareAsImage(
                context,
                _cardKey,
                fileName: 'estado-${product.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase()}.png',
                fallbackText: '${product.name}${_price ? ' · ${money(product.priceCents)}' : ''} · ¡$_stamp!',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'En WhatsApp elige "Mi estado". La imagen se arma en tu celular.',
              textAlign: TextAlign.center,
              style: GText.muted(size: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta en sí, de 360×640 (al compartirla sale a 1080×1920).
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.product,
    required this.businessName,
    required this.stamp,
    required this.color,
    this.photo,
    this.logo,
    this.showPrice = true,
    this.watermark = false,
  });

  static const size = Size(360, 640);

  final Product product;
  final Uint8List? photo;
  final String businessName;
  final Uint8List? logo;
  final String stamp;
  final StatusCardColor color;
  final bool showPrice;
  final bool watermark;

  @override
  Widget build(BuildContext context) {
    final ink = color.ink;
    final colored = color != StatusCardColor.crema;
    // En fondo de color el sello va blanco; en crema, del color del dinero.
    final stampColor = colored ? Colors.white : GColors.cenote;
    return SizedBox.fromSize(
      size: size,
      child: ColoredBox(
        color: color.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (logo != null) ...[
                    Container(
                      height: 40,
                      constraints: const BoxConstraints(maxWidth: 110),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Image.memory(logo!, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      businessName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GText.sans(size: 13, weight: FontWeight.w800, color: ink).copyWith(letterSpacing: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 16)],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: photo != null
                              ? Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true)
                              : ColoredBox(
                                  color: GColors.hundido,
                                  child: Center(child: ProductBadge(product.iconId, size: 150)),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      bottom: 18,
                      child: Transform.rotate(
                        angle: -8 * math.pi / 180,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: colored ? color.background : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: stampColor, width: 3),
                          ),
                          child: Text(
                            stamp.toUpperCase(),
                            style: GText.sans(
                              size: 17,
                              weight: FontWeight.w800,
                              color: stampColor,
                            ).copyWith(letterSpacing: 1.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                product.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GText.sans(size: 27, weight: FontWeight.w800, color: ink).copyWith(height: 1.1),
              ),
              if (showPrice) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: colored ? Colors.white : GColors.tinta,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      money(product.priceCents, hideZeroCents: true),
                      style: GText.amount(size: 34, color: colored ? color.background : Colors.white),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Pídelo por mensaje',
                style: GText.sans(size: 14, weight: FontWeight.w700, color: ink.withValues(alpha: 0.85)),
              ),
              if (watermark)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Hecho con Gavilán', style: GText.sans(size: 10.5, color: ink.withValues(alpha: 0.6))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
