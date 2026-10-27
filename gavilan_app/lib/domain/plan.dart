/// Planes de suscripción. El diseño es el mismo en todos; el plan decide límites y módulos.
enum Plan { semilla, emprendedor, negocio }

extension PlanInfo on Plan {
  String get label => switch (this) {
    Plan.semilla => 'Semilla',
    Plan.emprendedor => 'Emprendedor',
    Plan.negocio => 'Negocio',
  };

  String get price => switch (this) {
    Plan.semilla => 'Gratis',
    Plan.emprendedor => '\$49 a \$69 al mes',
    Plan.negocio => '\$129 a \$149 al mes',
  };

  String get profile => switch (this) {
    Plan.semilla => 'Para quien empieza: dulces, postres, ventas de vez en cuando.',
    Plan.emprendedor => 'Paca, tianguis, comida por Facebook, catálogo y tienditas.',
    Plan.negocio => 'Abarrotes grandes, boutiques, papelerías, restaurantes y taquerías.',
  };

  PlanLimits get limits => PlanLimits.of(this);
}

/// Límites por plan. null significa "sin límite".
class PlanLimits {
  const PlanLimits({
    required this.maxProducts,
    required this.maxDebtors,
    required this.maxLots,
    required this.photos,
    required this.watermark,
    required this.layaways,
    required this.batches,
    required this.restaurant,
    required this.team,
    required this.printer,
    required this.webPanel,
    required this.devices,
  });

  final int? maxProducts;
  final int? maxDebtors;
  final int? maxLots;
  final bool photos;
  final bool watermark;
  final bool layaways;
  final bool batches;
  final bool restaurant;
  final bool team;
  final bool printer;
  final bool webPanel;
  final int? devices;

  static PlanLimits of(Plan plan) => switch (plan) {
    Plan.semilla => const PlanLimits(
      maxProducts: 30,
      maxDebtors: 20,
      maxLots: 1,
      photos: false,
      watermark: true,
      layaways: false,
      batches: false,
      restaurant: false,
      team: false,
      printer: false,
      webPanel: false,
      devices: 1,
    ),
    Plan.emprendedor => const PlanLimits(
      maxProducts: 300,
      maxDebtors: null,
      maxLots: null,
      photos: true,
      watermark: false,
      layaways: true,
      batches: true,
      restaurant: false,
      team: false,
      printer: false,
      webPanel: true,
      devices: 2,
    ),
    Plan.negocio => const PlanLimits(
      maxProducts: null,
      maxDebtors: null,
      maxLots: null,
      photos: true,
      watermark: false,
      layaways: true,
      batches: true,
      restaurant: true,
      team: true,
      printer: true,
      webPanel: true,
      devices: null,
    ),
  };
}

/// Lo que incluye cada plan, en palabras para la pantalla "Mi plan".
List<String> planHighlights(Plan plan) => switch (plan) {
  Plan.semilla => const [
    'App en 1 celular',
    'Hasta 30 productos con iconos',
    'Hasta 20 clientes fiados',
    'Corte de caja diario',
    'Ticket con marca de agua',
  ],
  Plan.emprendedor => const [
    'App en 2 dispositivos y panel web básico',
    'Hasta 300 productos con foto',
    'Fiados sin límite y apartados con foto',
    'Pacas y lotes con barra de recuperación',
    'Pedidos por tanda',
    'Ticket con tu logo, sin marca de agua',
  ],
  Plan.negocio => const [
    'Productos sin límite y edición tipo Excel en PC',
    'Mesas, meseros y pantalla de cocina',
    'Equipo con roles: dueño, cajeros, meseros',
    'Lector láser USB y celular como escáner',
    'Impresora térmica Bluetooth o USB',
    'Límite de crédito y alertas de vencimiento',
  ],
};
