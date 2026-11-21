import '../core/limits.dart';
import 'models.dart';

// Tallas y colores. Cada combinación es un producto con su existencia (ver [Product.parentId]).

/// Tallas de siempre para escoger con un toque. El dueño puede escribir las suyas.
const sizePresets = <String, List<String>>{
  'Zapato dama': ['22', '22.5', '23', '23.5', '24', '24.5', '25', '25.5', '26'],
  'Zapato caballero': ['25', '25.5', '26', '26.5', '27', '27.5', '28', '28.5', '29'],
  'Zapato niño': ['12', '13', '14', '15', '16', '17', '18', '19', '20', '21'],
  'Ropa': ['CH', 'M', 'G', 'XG'],
  'Ropa niño': ['2', '4', '6', '8', '10', '12', '14', '16'],
  'Pantalón': ['28', '30', '32', '34', '36', '38'],
};

/// Cuántas tallas/colores puede tener un modelo (las combinaciones).
const maxVariants = 80;

/// Lo más largo que puede ser una talla o un color.
const maxVariantText = 20;

/// "22, 23 ,24,,23" → ["22", "23", "24"]. También separa por "/" o ";".
List<String> splitVariantList(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in text.split(RegExp(r'[,;/]'))) {
    var v = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isEmpty) continue;
    if (v.length > maxVariantText) v = v.substring(0, maxVariantText);
    if (seen.add(v.toLowerCase())) out.add(v);
  }
  return out;
}

/// Nombre de una talla para la cuenta y el ticket: "Tenis Runner · 26 · Negro".
/// Si no cabe, se recorta el modelo y nunca la talla.
String variantName(String model, String? size, String? color) {
  final tail = [?size, ?color].join(' · ');
  if (tail.isEmpty) return model;
  final room = Limits.maxNameLength - tail.length - 3;
  final head = model.length <= room ? model : '${model.substring(0, room.clamp(1, model.length) - 1).trimRight()}…';
  return '$head · $tail';
}

/// Orden natural de las tallas: números de menor a mayor, luego CH-M-G-XG, luego lo demás.
int compareSizes(String? a, String? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  final na = double.tryParse(a), nb = double.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  if (na != null) return -1;
  if (nb != null) return 1;
  final ia = _letterOrder.indexOf(a.toUpperCase()), ib = _letterOrder.indexOf(b.toUpperCase());
  if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
  if (ia >= 0) return -1;
  if (ib >= 0) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

const _letterOrder = ['XXCH', 'XCH', 'XS', 'CH', 'S', 'M', 'G', 'L', 'XG', 'XL', 'XXG', 'XXL', 'XXXG', 'XXXL'];

/// Ordena las tallas de un modelo: por talla y luego por color.
int compareVariants(Product a, Product b) {
  final bySize = compareSizes(a.size, b.size);
  if (bySize != 0) return bySize;
  return (a.color ?? '').toLowerCase().compareTo((b.color ?? '').toLowerCase());
}

/// Las combinaciones de tallas y colores, en orden. Sin tallas, solo colores (y al revés).
List<({String? size, String? color})> variantCombos(List<String> sizes, List<String> colors) => [
  for (final s in sizes.isEmpty ? <String?>[null] : sizes)
    for (final c in colors.isEmpty ? <String?>[null] : colors)
      if (s != null || c != null) (size: s, color: c),
];

/// Llave para encontrar la talla ya guardada de una combinación (sin importar mayúsculas).
String variantKey(String? size, String? color) => '${(size ?? '').toLowerCase()}|${(color ?? '').toLowerCase()}';
