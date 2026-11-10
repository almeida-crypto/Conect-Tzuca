import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Iconos predeterminados. En el plan gratis los productos usan estos en vez de fotos,
/// y en la base de datos solo se guarda el identificador (products.icon).
const productIcons = <String, IconData>{
  'refresco': Icons.local_drink_outlined,
  'agua': Icons.water_drop_outlined,
  'botana': Icons.cookie_outlined,
  'dulce': Icons.cake_outlined,
  'pan': Icons.breakfast_dining_outlined,
  'tortilla': Icons.bakery_dining_outlined,
  'huevo': Icons.egg_outlined,
  'carne': Icons.set_meal_outlined,
  'fruta': Icons.eco_outlined,
  'cafe': Icons.coffee_outlined,
  'helado': Icons.icecream_outlined,
  'taco': Icons.lunch_dining_outlined,
  'limpieza': Icons.cleaning_services_outlined,
  'farmacia': Icons.medication_outlined,
  'ropa': Icons.checkroom_outlined,
  'herramienta': Icons.build_outlined,
  'papeleria': Icons.edit_outlined,
  'otro': Icons.inventory_2_outlined,
};

IconData productIcon(String id) => productIcons[id] ?? Icons.inventory_2_outlined;

/// Color de fondo y de icono según el tipo de producto, para que el catálogo se lea de un vistazo.
(Color, Color) productTint(String iconId) {
  const pairs = [
    (GColors.marcaSuave, GColors.marca),
    (GColors.cenoteSuave, GColors.cenote),
    (GColors.izamalSuave, Color(0xFFB27C00)),
    (Color(0xFFEDE6F6), Color(0xFF6B4FA0)),
    (Color(0xFFE4EEF9), Color(0xFF2F6DB5)),
  ];
  return pairs[iconId.codeUnits.fold(0, (a, c) => a + c) % pairs.length];
}

/// Icono del producto en un cuadro de su color.
class ProductBadge extends StatelessWidget {
  const ProductBadge(this.iconId, {super.key, this.size = 44});

  final String iconId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = productTint(iconId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(productIcon(iconId), size: size * 0.52, color: fg),
    );
  }
}
