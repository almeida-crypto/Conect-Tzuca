import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Estilos de texto propios. Archivo para la interfaz, Space Mono para tickets y cuentas.
abstract final class GText {
  static TextStyle sans({double size = 14, FontWeight weight = FontWeight.w500, Color color = GColors.tinta}) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, color: color, height: 1.2);

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w400, Color color = GColors.tinta}) =>
      GoogleFonts.spaceMono(fontSize: size, fontWeight: weight, color: color, height: 1.5);

  /// Montos: peso fuerte y números tabulares para que no "bailen".
  static TextStyle amount({double size = 18, Color color = GColors.tinta}) => GoogleFonts.archivo(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.05,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle title() => sans(size: 22, weight: FontWeight.w800);
  static TextStyle muted({double size = 12}) => sans(size: size, color: GColors.tintaSuave);
  static TextStyle label() => sans(size: 11, color: GColors.tintaSuave).copyWith(letterSpacing: 0.9);
}

ThemeData buildGavilanTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GColors.oxido,
      primary: GColors.oxido,
      onPrimary: GColors.papel,
      secondary: GColors.monte,
      surface: GColors.papel,
      onSurface: GColors.tinta,
      error: GColors.rojo,
    ),
    scaffoldBackgroundColor: GColors.papel,
    fontFamily: GoogleFonts.archivo().fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: GColors.tinta, displayColor: GColors.tinta),
    dividerColor: GColors.linea,
    splashFactory: InkRipple.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GColors.papelClaro,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: GText.muted(size: 14),
      labelStyle: GText.muted(size: 14),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: GColors.linea),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: GColors.tinta, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: GColors.rojo),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: GColors.rojo, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: GColors.papel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      showDragHandle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GColors.tinta,
      contentTextStyle: GText.sans(color: GColors.papel),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GColors.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
      titleTextStyle: GText.sans(size: 18, weight: FontWeight.w800),
    ),
  );
}
