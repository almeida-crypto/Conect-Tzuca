import 'package:flutter/painting.dart';

/// Paleta Gavilán: neutros limpios y tres colores de Yucatán con un trabajo cada uno.
/// - Achiote (la cochinita, el plumaje del gavilán): acciones y la marca.
/// - Cenote (el agua turquesa): dinero, cobrar, pagado, todo bien.
/// - Izamal (la ciudad amarilla): avisos y lo que pide atención sin ser error.
/// El inicio animado tiene sus propios colores (IntroColors) y no cambia con esta paleta.
abstract final class GColors {
  // Neutros
  static const fondo = Color(0xFFF5F4F1);
  static const superficie = Color(0xFFFFFFFF);
  static const hundido = Color(0xFFEDEBE7);
  static const linea = Color(0xFFE3E0DA);
  static const tinta = Color(0xFF1B1A19);
  static const tintaSuave = Color(0xFF66625D);
  static const tintaTenue = Color(0xFF9C978F);

  // Achiote: botones principales, selección, la marca.
  static const marca = Color(0xFFE2582B);
  static const marcaOscura = Color(0xFFB8431B);
  static const marcaSuave = Color(0xFFFCE9E1);

  // Cenote: cobrar, dinero, pagado, respaldado.
  static const cenote = Color(0xFF0E7A70);
  static const cenoteOscuro = Color(0xFF095A53);
  static const cenoteSuave = Color(0xFFDDF1EE);

  // Izamal: avisos, por acabarse, sin internet.
  static const izamal = Color(0xFFF2AE1C);
  static const izamalSuave = Color(0xFFFDF1D4);

  /// Café del plumaje: iconos de producto y detalles.
  static const cafe = Color(0xFF7A5236);

  /// Errores, deudas vencidas, borrar.
  static const rojo = Color(0xFFCC2F2F);
  static const rojoSuave = Color(0xFFFBE5E3);
}
