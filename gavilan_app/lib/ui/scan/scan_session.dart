import '../../domain/models.dart';

/// Qué pasó al leer un código.
sealed class ScanOutcome {
  const ScanOutcome(this.code);

  final String code;
}

/// Se encontró el producto (y en modo cobrar ya se agregó a la cuenta).
class ScanFound extends ScanOutcome {
  const ScanFound(super.code, this.product, {required this.added});

  final Product product;
  final bool added;
}

/// Ningún producto tiene ese código.
class ScanUnknown extends ScanOutcome {
  const ScanUnknown(super.code);
}

/// El mismo código siguió frente a la cámara: no se vuelve a contar.
class ScanRepeated extends ScanOutcome {
  const ScanRepeated(super.code);
}

/// Lógica del escáner, sin cámara (para poder probarla).
///
/// La cámara lee el mismo código muchas veces por segundo mientras está enfrente.
/// Se cuenta una vez, y otra vez solo si se retira y se vuelve a acercar
/// (pasan [repeatGap] sin verlo) o si se lee otro código entre tanto.
class ScanSession {
  ScanSession({required this.lookup, this.onFound, this.repeatGap = const Duration(milliseconds: 1200)});

  final Product? Function(String code) lookup;

  /// Se llama al encontrar un producto (modo cobrar: agregarlo a la cuenta).
  final void Function(Product product)? onFound;
  final Duration repeatGap;

  String? _lastCode;
  DateTime? _lastSeen;

  ScanOutcome handle(String rawCode, DateTime now) {
    final code = rawCode.trim();
    final repeated = code == _lastCode && _lastSeen != null && now.difference(_lastSeen!) < repeatGap;
    _lastCode = code;
    _lastSeen = now;
    if (repeated) return ScanRepeated(code);

    final product = lookup(code);
    if (product == null) return ScanUnknown(code);
    onFound?.call(product);
    return ScanFound(code, product, added: onFound != null);
  }

  /// Olvida el último código (por ejemplo, después de dar de alta un producto nuevo).
  void reset() {
    _lastCode = null;
    _lastSeen = null;
  }
}
