import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../state/sync.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../inventario/product_form.dart';
import '../widgets/buttons.dart';
import 'scan_session.dart';

enum ScanMode {
  /// Cada código suma el producto a la cuenta.
  cobrar,

  /// Solo muestra el precio, sin tocar la cuenta.
  precio,

  /// Lee un código y lo devuelve (para la ficha de producto).
  capturar,
}

/// Lee un solo código con la cámara. null si se canceló.
Future<String?> scanOneCode(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.capturar)));

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.mode = ScanMode.cobrar});

  final ScanMode mode;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  late ScanMode _mode = widget.mode;
  late final ScanSession _session = ScanSession(
    lookup: (code) => ref.read(storeProvider).productByBarcode(code),
    onFound: (p) {
      if (_mode == ScanMode.cobrar) ref.read(cartProvider.notifier).addProduct(p);
    },
  );
  ScanOutcome? _last;
  bool _busy = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || raw.trim().isEmpty) return;

    if (_mode == ScanMode.capturar) {
      _busy = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(raw.trim());
      return;
    }

    final outcome = _session.handle(raw, DateTime.now());
    if (outcome is ScanRepeated) return;
    if (outcome is ScanFound) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _last = outcome);
  }

  /// Código que no existe: darlo de alta ahí mismo y, en modo cobrar, sumarlo a la cuenta.
  Future<void> _register(String code) async {
    _busy = true;
    await _camera.stop();
    try {
      if (!mounted || !await ensureRoomForProduct(context, ref) || !mounted) return;
      final saved = await showProductForm(context, initialBarcode: code);
      if (saved == null || !mounted) return;
      _session.reset();
      if (_mode == ScanMode.cobrar) ref.read(cartProvider.notifier).addProduct(saved);
      setState(() => _last = ScanFound(code, saved, added: _mode == ScanMode.cobrar));
    } finally {
      _busy = false;
      if (mounted) await _camera.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final capturing = _mode == ScanMode.capturar;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MobileScanner(controller: _camera, onDetect: _onDetect, errorBuilder: _cameraError),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _FramePainter())),
          ),
          // Barra de arriba, sobre una franja oscura para que se lea con cualquier fondo.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: const Color(0x66000000),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Regresar',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      if (capturing)
                        Text(
                          'Leer código',
                          style: GText.sans(size: 17, weight: FontWeight.w800, color: Colors.white),
                        )
                      else
                        _ModeSwitch(
                          mode: _mode,
                          onChanged: (m) => setState(() {
                            _mode = m;
                            _last = null;
                            _session.reset();
                          }),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Linterna',
                        onPressed: () => _camera.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _bottomPanel()),
        ],
      ),
    );
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Gavilán necesita la cámara para leer códigos. Dale permiso en los ajustes del teléfono.',
      MobileScannerErrorCode.unsupported => 'Este dispositivo no tiene una cámara que pueda leer códigos.',
      _ => 'No se pudo abrir la cámara. Cierra y vuelve a intentar.',
    };
    return ColoredBox(
      color: GColors.tinta,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GText.sans(size: 15, weight: FontWeight.w400, color: GColors.fondo),
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final last = _last;

    Widget feedback;
    if (_mode == ScanMode.capturar) {
      feedback = Text('Apunta al código de barras del producto.', style: GText.sans(size: 15));
    } else if (last == null) {
      feedback = Text(
        _mode == ScanMode.cobrar
            ? 'Apunta a los códigos: cada producto se suma a la cuenta.'
            : 'Apunta a un código para ver su precio.',
        style: GText.sans(size: 15, weight: FontWeight.w400),
      );
    } else if (last is ScanFound) {
      feedback = _mode == ScanMode.precio
          ? _PriceCard(product: last.product)
          : Row(
              children: [
                const Icon(Icons.check_circle, color: GColors.cenote),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+1 ${last.product.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.sans(size: 16, weight: FontWeight.w800),
                  ),
                ),
                Text(money(last.product.priceCents), style: GText.amount(size: 18)),
              ],
            );
    } else {
      feedback = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No tengo el código ${last.code}',
            style: GText.sans(size: 15, weight: FontWeight.w800, color: GColors.rojo),
          ),
          const SizedBox(height: 8),
          if (ref.watch(permissionsProvider).editCatalog)
            GButton(
              label: 'Darlo de alta',
              kind: GButtonKind.dark,
              icon: Icons.add,
              onPressed: () => _register(last.code),
            )
          else
            Text('Pídele al dueño o a un administrador que lo dé de alta.', style: GText.muted(size: 13)),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: GColors.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GShape.radiusSheet)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          feedback,
          if (_mode == ScanMode.cobrar) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cart.length} ${cart.length == 1 ? 'producto' : 'productos'}', style: GText.label()),
                      Text(money(total), style: GText.amount(size: 26)),
                    ],
                  ),
                ),
                GButton(label: 'Listo', big: true, onPressed: () => Navigator.of(context).maybePop()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final ScanMode mode;
  final ValueChanged<ScanMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(ScanMode m, String label) => Semantics(
      button: true,
      selected: mode == m,
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: mode == m ? GColors.fondo : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: GText.sans(size: 13, weight: FontWeight.w800, color: mode == m ? GColors.tinta : Colors.white),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option(ScanMode.cobrar, 'Cobrar'), option(ScanMode.precio, '¿Cuánto cuesta?')],
      ),
    );
  }
}

/// Precio grande para el modo "¿Cuánto cuesta?".
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: GText.sans(size: 17, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(money(product.priceCents), style: GText.amount(size: 44, color: GColors.marca)),
        if (product.trackStock)
          Text(
            'Quedan ${qtyLabel(product.stock)}',
            style: GText.sans(size: 13, color: product.isLow ? GColors.rojo : GColors.tintaSuave),
          ),
      ],
    );
  }
}

/// Esquinas color ocre que marcan dónde poner el código.
class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .72;
    final h = w * .55;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * .4), width: w, height: h);
    final paint = Paint()
      ..color = GColors.izamal
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner + Offset(l * dx, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, l * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}
