/// Productos comunes de una tiendita, para empezar rápido: el dueño marca los que vende y les pone su precio.
/// El precio de ejemplo solo se muestra como pista; nunca se guarda solo, porque cada tienda tiene el suyo.
class StarterItem {
  const StarterItem(this.name, this.iconId, this.hintPesos);

  final String name;
  final String iconId;

  /// Precio aproximado, solo para orientar ("ej. 18").
  final int hintPesos;
}

class StarterGroup {
  const StarterGroup(this.title, this.items);

  final String title;
  final List<StarterItem> items;
}

const starterCatalog = [
  StarterGroup('Refrescos y aguas', [
    StarterItem('Coca-Cola 600 ml', 'refresco', 20),
    StarterItem('Coca-Cola 2.5 L', 'refresco', 45),
    StarterItem('Coca-Cola 3 L', 'refresco', 52),
    StarterItem('Refresco de sabor 600 ml', 'refresco', 18),
    StarterItem('Refresco de sabor 2 L', 'refresco', 35),
    StarterItem('Agua 600 ml', 'agua', 12),
    StarterItem('Agua 1.5 L', 'agua', 18),
    StarterItem('Garrafón de agua', 'agua', 40),
    StarterItem('Jugo 1 L', 'refresco', 30),
    StarterItem('Bebida energética', 'refresco', 35),
  ]),
  StarterGroup('Botanas y dulces', [
    StarterItem('Papas chicas', 'botana', 20),
    StarterItem('Papas grandes', 'botana', 45),
    StarterItem('Chicharrones de harina', 'botana', 10),
    StarterItem('Cacahuates', 'botana', 15),
    StarterItem('Galletas', 'botana', 18),
    StarterItem('Pastelito', 'dulce', 18),
    StarterItem('Chocolate', 'dulce', 15),
    StarterItem('Paleta de dulce', 'dulce', 5),
    StarterItem('Chicle', 'dulce', 2),
    StarterItem('Helado', 'helado', 20),
  ]),
  StarterGroup('Abarrotes', [
    StarterItem('Arroz 1 kg', 'otro', 32),
    StarterItem('Frijol 1 kg', 'otro', 40),
    StarterItem('Azúcar 1 kg', 'otro', 32),
    StarterItem('Aceite 1 L', 'otro', 45),
    StarterItem('Sopa de pasta', 'otro', 12),
    StarterItem('Atún en lata', 'otro', 25),
    StarterItem('Café soluble chico', 'cafe', 35),
    StarterItem('Sal 1 kg', 'otro', 15),
    StarterItem('Harina de maíz 1 kg', 'tortilla', 22),
    StarterItem('Chiles en lata', 'otro', 20),
    StarterItem('Mayonesa chica', 'otro', 28),
    StarterItem('Sardina en lata', 'otro', 28),
  ]),
  StarterGroup('Lácteos, huevo y carnes frías', [
    StarterItem('Leche 1 L', 'otro', 28),
    StarterItem('Huevo por kilo', 'huevo', 42),
    StarterItem('Huevo por pieza', 'huevo', 3),
    StarterItem('Queso por kilo', 'otro', 160),
    StarterItem('Jamón por kilo', 'carne', 140),
    StarterItem('Salchicha por kilo', 'carne', 90),
    StarterItem('Yogurt bebible', 'otro', 15),
    StarterItem('Crema chica', 'otro', 25),
  ]),
  StarterGroup('Pan y tortilla', [
    StarterItem('Tortilla por kilo', 'tortilla', 24),
    StarterItem('Pan dulce', 'pan', 8),
    StarterItem('Pan francés', 'pan', 3),
    StarterItem('Pan de caja', 'pan', 50),
    StarterItem('Tostadas', 'tortilla', 25),
  ]),
  StarterGroup('Frutas y verduras', [
    StarterItem('Tomate por kilo', 'fruta', 30),
    StarterItem('Cebolla por kilo', 'fruta', 30),
    StarterItem('Limón por kilo', 'fruta', 35),
    StarterItem('Chile habanero por kilo', 'fruta', 60),
    StarterItem('Plátano por kilo', 'fruta', 25),
    StarterItem('Papa por kilo', 'fruta', 30),
  ]),
  StarterGroup('Limpieza y cuidado personal', [
    StarterItem('Jabón de barra', 'limpieza', 18),
    StarterItem('Detergente 1 kg', 'limpieza', 40),
    StarterItem('Cloro 1 L', 'limpieza', 20),
    StarterItem('Papel higiénico (rollo)', 'limpieza', 8),
    StarterItem('Pasta de dientes', 'farmacia', 30),
    StarterItem('Shampoo chico', 'farmacia', 10),
    StarterItem('Toallas femeninas', 'farmacia', 35),
    StarterItem('Pañales (pieza)', 'farmacia', 7),
  ]),
  StarterGroup('Otros', [
    StarterItem('Hielo (bolsa)', 'agua', 25),
    StarterItem('Cigarros (pieza)', 'otro', 6),
    StarterItem('Recarga de celular', 'otro', 50),
    StarterItem('Pilas AA (par)', 'herramienta', 30),
    StarterItem('Encendedor', 'otro', 15),
    StarterItem('Gas para encendedor', 'otro', 40),
  ]),
];
