import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Medidas que se repiten: esquinas y sombras de tarjetas.
abstract final class GShape {
  static const radius = 14.0;
  static const radiusSmall = 10.0;
  static const radiusSheet = 24.0;

  /// Sombra suave de tarjeta: se nota sin ensuciar.
  static const shadow = [
    BoxShadow(color: Color(0x0F1B1A19), blurRadius: 12, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x0A1B1A19), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Tarjeta blanca estándar.
  static BoxDecoration card({Color color = GColors.superficie, double radius = GShape.radius}) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: shadow);
}

/// Estilos de texto propios. Archivo para todo; Space Mono solo para el ticket impreso.
abstract final class GText {
  static TextStyle sans({double size = 14, FontWeight weight = FontWeight.w500, Color color = GColors.tinta}) =>
      GoogleFonts.archivo(fontSize: size, fontWeight: weight, color: color, height: 1.2);

  /// Letra de ticket. Solo para el ticket, que imita uno impreso.
  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w400, Color color = GColors.tinta}) =>
      GoogleFonts.spaceMono(fontSize: size, fontWeight: weight, color: color, height: 1.5);

  /// Cifras en listas y cuentas: números del mismo ancho para que las columnas cuadren.
  static TextStyle figures({double size = 13, FontWeight weight = FontWeight.w600, Color color = GColors.tinta}) =>
      GoogleFonts.archivo(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Montos: peso fuerte y números tabulares para que no "bailen".
  static TextStyle amount({double size = 18, Color color = GColors.tinta}) => GoogleFonts.archivo(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.05,
    letterSpacing: -0.3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle title() => sans(size: 26, weight: FontWeight.w800).copyWith(letterSpacing: -0.4);
  static TextStyle muted({double size = 12}) => sans(size: size, color: GColors.tintaSuave);
  static TextStyle label() =>
      sans(size: 11.5, weight: FontWeight.w700, color: GColors.tintaTenue).copyWith(letterSpacing: 0.6);
}

ThemeData buildGavilanTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GColors.marca,
      primary: GColors.marca,
      onPrimary: Colors.white,
      secondary: GColors.cenote,
      surface: GColors.superficie,
      onSurface: GColors.tinta,
      error: GColors.rojo,
    ),
    scaffoldBackgroundColor: GColors.fondo,
    fontFamily: GoogleFonts.archivo().fontFamily,
  );
  const field = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GShape.radiusSmall)),
    borderSide: BorderSide(color: GColors.linea),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: GColors.tinta, displayColor: GColors.tinta),
    dividerColor: GColors.linea,
    splashFactory: InkSparkle.splashFactory,
    // Pantallas que entran deslizándose con un desvanecido, como Android moderno.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: GColors.fondo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GText.sans(size: 18, weight: FontWeight.w800),
      iconTheme: const IconThemeData(color: GColors.tinta),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GColors.superficie,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: GText.sans(size: 14, color: GColors.tintaTenue),
      labelStyle: GText.muted(size: 14),
      floatingLabelStyle: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.marca),
      prefixIconColor: GColors.tintaTenue,
      enabledBorder: field,
      border: field,
      focusedBorder: field.copyWith(borderSide: const BorderSide(color: GColors.marca, width: 2)),
      errorBorder: field.copyWith(borderSide: const BorderSide(color: GColors.rojo)),
      focusedErrorBorder: field.copyWith(borderSide: const BorderSide(color: GColors.rojo, width: 2)),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: GColors.marca,
      selectionColor: GColors.marcaSuave,
      selectionHandleColor: GColors.marca,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: GColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GShape.radiusSheet))),
      showDragHandle: true,
      dragHandleColor: GColors.linea,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GColors.tinta,
      contentTextStyle: GText.sans(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(GShape.radiusSmall))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      titleTextStyle: GText.sans(size: 19, weight: FontWeight.w800),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GColors.marca,
        textStyle: GText.sans(size: 14, weight: FontWeight.w700),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: GColors.tintaSuave),
    chipTheme: ChipThemeData(
      backgroundColor: GColors.superficie,
      selectedColor: GColors.marcaSuave,
      checkmarkColor: GColors.marca,
      side: const BorderSide(color: GColors.linea),
      shape: const StadiumBorder(),
      labelStyle: GText.sans(size: 13.5, weight: FontWeight.w600),
      iconTheme: const IconThemeData(color: GColors.marca),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: GColors.marca),
    popupMenuTheme: PopupMenuThemeData(
      color: GColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(GShape.radiusSmall))),
      textStyle: GText.sans(size: 14),
    ),
  );
}
