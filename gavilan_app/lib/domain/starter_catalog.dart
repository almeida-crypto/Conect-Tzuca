import 'business.dart';

/// Productos comunes de cada giro, para empezar rápido: el dueño marca los que vende y les pone su precio.
/// El precio de ejemplo solo se muestra como pista; nunca se guarda solo, porque cada negocio tiene el suyo.
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

/// Tiendita o abarrotes.
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

/// De qué giro es la lista de inicio.
enum StarterKind {
  tiendita('Tiendita', starterCatalog),
  fonda('Fonda', _fonda),
  papeleria('Papelería', _papeleria),
  ferreteria('Ferretería', _ferreteria),
  farmacia('Farmacia', _farmacia);

  const StarterKind(this.label, this.groups);

  final String label;
  final List<StarterGroup> groups;

  /// La lista que se abre primero según el tipo de negocio (después se puede cambiar).
  static StarterKind of(BusinessType? type) => switch (type) {
    BusinessType.restaurante || BusinessType.encargos => StarterKind.fonda,
    _ => StarterKind.tiendita,
  };
}

const _fonda = [
  StarterGroup('Comida', [
    StarterItem('Comida corrida', 'taco', 90),
    StarterItem('Cochinita pibil (orden)', 'taco', 95),
    StarterItem('Torta de cochinita', 'taco', 40),
    StarterItem('Taco de cochinita', 'taco', 20),
    StarterItem('Panucho', 'taco', 20),
    StarterItem('Salbut', 'taco', 18),
    StarterItem('Empanada', 'taco', 15),
    StarterItem('Poc chuc', 'carne', 120),
    StarterItem('Pollo asado (orden)', 'carne', 110),
    StarterItem('Frijol con puerco', 'carne', 100),
    StarterItem('Relleno negro', 'carne', 100),
    StarterItem('Sopa de lima', 'taco', 70),
    StarterItem('Huevos al gusto', 'huevo', 70),
    StarterItem('Quesadilla', 'taco', 30),
  ]),
  StarterGroup('Bebidas', [
    StarterItem('Agua fresca (vaso)', 'refresco', 20),
    StarterItem('Agua fresca 1 L', 'refresco', 35),
    StarterItem('Refresco 600 ml', 'refresco', 22),
    StarterItem('Refresco de vidrio', 'refresco', 20),
    StarterItem('Agua 600 ml', 'agua', 15),
    StarterItem('Café de olla', 'cafe', 20),
    StarterItem('Café americano', 'cafe', 25),
  ]),
  StarterGroup('Extras y postres', [
    StarterItem('Tortillas (orden)', 'tortilla', 10),
    StarterItem('Arroz (orden)', 'otro', 25),
    StarterItem('Frijol (orden)', 'otro', 25),
    StarterItem('Postre del día', 'dulce', 30),
    StarterItem('Flan', 'dulce', 30),
    StarterItem('Para llevar (envase)', 'otro', 5),
  ]),
];

const _papeleria = [
  StarterGroup('Útiles escolares', [
    StarterItem('Cuaderno profesional', 'papeleria', 45),
    StarterItem('Cuaderno forma francesa', 'papeleria', 25),
    StarterItem('Lápiz', 'papeleria', 6),
    StarterItem('Pluma', 'papeleria', 8),
    StarterItem('Borrador', 'papeleria', 6),
    StarterItem('Sacapuntas', 'papeleria', 8),
    StarterItem('Regla 30 cm', 'papeleria', 12),
    StarterItem('Colores (caja de 12)', 'papeleria', 45),
    StarterItem('Tijeras escolares', 'papeleria', 25),
    StarterItem('Lápiz adhesivo', 'papeleria', 15),
    StarterItem('Pegamento blanco', 'papeleria', 15),
    StarterItem('Juego de geometría', 'papeleria', 35),
    StarterItem('Marcatextos', 'papeleria', 15),
    StarterItem('Plastilina', 'papeleria', 15),
  ]),
  StarterGroup('Papel', [
    StarterItem('Hoja blanca', 'papeleria', 1),
    StarterItem('Paquete de hojas (100)', 'papeleria', 45),
    StarterItem('Cartulina', 'papeleria', 8),
    StarterItem('Papel china', 'papeleria', 3),
    StarterItem('Papel crepé', 'papeleria', 6),
    StarterItem('Foami', 'papeleria', 10),
    StarterItem('Folder', 'papeleria', 4),
    StarterItem('Sobre manila', 'papeleria', 4),
    StarterItem('Monografía', 'papeleria', 5),
    StarterItem('Mapa', 'papeleria', 4),
  ]),
  StarterGroup('Servicios', [
    StarterItem('Copia blanco y negro', 'papeleria', 1),
    StarterItem('Impresión blanco y negro', 'papeleria', 3),
    StarterItem('Impresión a color', 'papeleria', 8),
    StarterItem('Enmicado', 'papeleria', 15),
    StarterItem('Engargolado', 'papeleria', 35),
    StarterItem('Escaneo', 'papeleria', 10),
  ]),
  StarterGroup('Oficina', [
    StarterItem('Cinta adhesiva', 'papeleria', 15),
    StarterItem('Grapas (caja)', 'papeleria', 20),
    StarterItem('Clips (caja)', 'papeleria', 15),
    StarterItem('Plumón para pizarrón', 'papeleria', 20),
    StarterItem('Pilas AA (par)', 'herramienta', 30),
  ]),
];

const _ferreteria = [
  StarterGroup('Tornillería', [
    StarterItem('Clavo por kilo', 'herramienta', 45),
    StarterItem('Tornillo (pieza)', 'herramienta', 2),
    StarterItem('Pija (pieza)', 'herramienta', 1),
    StarterItem('Taquete (pieza)', 'herramienta', 1),
    StarterItem('Alambre recocido por kilo', 'herramienta', 45),
  ]),
  StarterGroup('Construcción', [
    StarterItem('Cemento (bulto)', 'herramienta', 260),
    StarterItem('Cal (bulto)', 'herramienta', 110),
    StarterItem('Mortero (bulto)', 'herramienta', 180),
    StarterItem('Varilla 3/8', 'herramienta', 150),
    StarterItem('Block', 'herramienta', 14),
  ]),
  StarterGroup('Electricidad', [
    StarterItem('Foco LED', 'herramienta', 35),
    StarterItem('Cable por metro', 'herramienta', 12),
    StarterItem('Contacto', 'herramienta', 35),
    StarterItem('Apagador', 'herramienta', 35),
    StarterItem('Cinta de aislar', 'herramienta', 15),
    StarterItem('Extensión', 'herramienta', 70),
  ]),
  StarterGroup('Plomería', [
    StarterItem('Tubo PVC (tramo)', 'herramienta', 90),
    StarterItem('Codo PVC', 'herramienta', 10),
    StarterItem('Pegamento PVC', 'herramienta', 45),
    StarterItem('Cinta teflón', 'herramienta', 10),
    StarterItem('Llave de paso', 'herramienta', 90),
    StarterItem('Manguera por metro', 'herramienta', 15),
  ]),
  StarterGroup('Pintura y herramienta', [
    StarterItem('Pintura vinílica 1 L', 'herramienta', 120),
    StarterItem('Thinner 1 L', 'herramienta', 50),
    StarterItem('Brocha', 'herramienta', 35),
    StarterItem('Rodillo', 'herramienta', 60),
    StarterItem('Lija', 'herramienta', 8),
    StarterItem('Silicón', 'herramienta', 70),
    StarterItem('Martillo', 'herramienta', 150),
    StarterItem('Desarmador', 'herramienta', 50),
    StarterItem('Machete', 'herramienta', 160),
    StarterItem('Candado', 'herramienta', 80),
  ]),
];

const _farmacia = [
  StarterGroup('Dolor y fiebre', [
    StarterItem('Paracetamol (caja)', 'farmacia', 35),
    StarterItem('Ibuprofeno (caja)', 'farmacia', 45),
    StarterItem('Naproxeno (caja)', 'farmacia', 50),
    StarterItem('Jarabe para la tos', 'farmacia', 90),
    StarterItem('Antigripal (caja)', 'farmacia', 70),
  ]),
  StarterGroup('Estómago y alergias', [
    StarterItem('Suero oral', 'farmacia', 25),
    StarterItem('Omeprazol (caja)', 'farmacia', 45),
    StarterItem('Antiácido', 'farmacia', 40),
    StarterItem('Loratadina (caja)', 'farmacia', 40),
  ]),
  StarterGroup('Curación', [
    StarterItem('Alcohol 250 ml', 'farmacia', 30),
    StarterItem('Agua oxigenada', 'farmacia', 25),
    StarterItem('Algodón', 'farmacia', 25),
    StarterItem('Gasas', 'farmacia', 20),
    StarterItem('Curitas (caja)', 'farmacia', 30),
    StarterItem('Venda', 'farmacia', 25),
    StarterItem('Termómetro', 'farmacia', 90),
    StarterItem('Cubrebocas', 'farmacia', 5),
  ]),
  StarterGroup('Cuidado personal', [
    StarterItem('Repelente de mosquitos', 'farmacia', 90),
    StarterItem('Bloqueador solar', 'farmacia', 150),
    StarterItem('Vitamina C', 'farmacia', 60),
    StarterItem('Pañales (pieza)', 'farmacia', 7),
    StarterItem('Toallas femeninas', 'farmacia', 35),
    StarterItem('Preservativos', 'farmacia', 45),
    StarterItem('Prueba de embarazo', 'farmacia', 60),
    StarterItem('Pasta de dientes', 'farmacia', 30),
  ]),
];
