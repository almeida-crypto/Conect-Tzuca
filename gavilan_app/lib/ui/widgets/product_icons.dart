import 'package:flutter/material.dart';

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
