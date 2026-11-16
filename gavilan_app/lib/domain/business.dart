/// Partes de la app que no todos los negocios usan. Lo demás (cobrar, fiados, inventario, caja) es para todos.
enum Module {
  restaurante('Mesas y cocina', 'Meseros, comandas, extras y pantalla de cocina'),
  apartados('Apartados', 'Anticipo, abonos y fecha límite'),
  pacas('Pacas y lotes', 'Cuánto falta para recuperar lo invertido'),
  tandas('Pedidos por tanda', 'Cochinita del domingo, marquesitas, cenas');

  const Module(this.label, this.description);
  final String label;
  final String description;
}

/// Qué tipo de negocio es: decide qué módulos se ven al empezar (después se pueden prender o apagar).
enum BusinessType {
  tienda('Tienda o abarrotes', 'Abarrotes, miscelánea, papelería, farmacia', {}),
  restaurante('Restaurante o fonda', 'Fonda, taquería, cocina económica, cafetería', {Module.restaurante}),
  ropa('Ropa, pacas o boutique', 'Ropa americana, boutique, zapatos, accesorios', {Module.pacas, Module.apartados}),
  encargos('Comida por encargo', 'Cochinita, postres, cenas por pedido', {Module.tandas, Module.apartados}),
  otro('Otro', 'Ves todo y apagas lo que no uses', {Module.restaurante, Module.apartados, Module.pacas, Module.tandas});

  const BusinessType(this.label, this.examples, this.defaultModules);
  final String label;
  final String examples;
  final Set<Module> defaultModules;

  static BusinessType? fromName(String? name) => BusinessType.values.where((t) => t.name == name).firstOrNull;
}

/// Módulos guardados como texto: "restaurante,apartados".
Set<Module>? modulesFromText(String? text) {
  if (text == null) return null;
  return {for (final part in text.split(',')) ...Module.values.where((m) => m.name == part.trim())};
}

String modulesToText(Set<Module> modules) => [
  for (final m in Module.values)
    if (modules.contains(m)) m.name,
].join(',');
