part of 'repository.dart';

// Conversión entre los objetos de la app y los renglones de la base local (Drift).

/// Al leer, cualquier cifra irreal guardada antes de los límites se regresa al rango permitido,
/// para que la pantalla no se rompa y el respaldo no la rechace.
Product _product(ProductRow p) => Product(
  id: p.id,
  name: p.name.length > Limits.maxNameLength ? p.name.substring(0, Limits.maxNameLength) : p.name,
  priceCents: p.priceCents.clamp(0, Limits.maxMoneyCents),
  costCents: p.costCents.clamp(0, Limits.maxMoneyCents),
  barcode: p.barcode,
  iconId: p.iconId,
  trackStock: p.trackStock,
  stock: p.stock.isFinite ? p.stock.clamp(-Limits.maxQty, Limits.maxQty) : 0,
  minStock: p.minStock == null || !p.minStock!.isFinite ? null : p.minStock!.clamp(0, Limits.maxQty),
  active: p.active,
  photoPath: p.photoPath,
);

CashSession _session(SessionRow s) => CashSession(
  id: s.id,
  openedAt: s.openedAt,
  openingCents: s.openingCents,
  closedAt: s.closedAt,
  expectedCents: s.expectedCents,
  countedCents: s.countedCents,
  device: s.device,
  name: s.name,
);

Lot _lot(LotRow r) =>
    Lot(id: r.id, name: r.name, investmentCents: r.investmentCents, startedAt: r.startedAt, closedAt: r.closedAt);

LotRow _lotRow(Lot l) =>
    LotRow(id: l.id, name: l.name, investmentCents: l.investmentCents, startedAt: l.startedAt, closedAt: l.closedAt);

LotSale _lotSale(LotSaleRow r) => LotSale(
  id: r.id,
  lotId: r.lotId,
  amountCents: r.amountCents,
  createdAt: r.createdAt,
  note: r.note,
  sessionId: r.sessionId,
);

LotSaleRow _lotSaleRow(LotSale s) => LotSaleRow(
  id: s.id,
  lotId: s.lotId,
  amountCents: s.amountCents,
  createdAt: s.createdAt,
  note: s.note,
  sessionId: s.sessionId,
);

SaleReturn _saleReturn(SaleReturnRow r) => SaleReturn(
  id: r.id,
  saleId: r.saleId,
  sessionId: r.sessionId,
  lines: [for (final l in (jsonDecode(r.lines) as List).cast<Map<String, dynamic>>()) ReturnedLine.fromJson(l)],
  amountCents: r.amountCents,
  cashCents: r.cashCents,
  reason: r.reason,
  clerk: r.clerk,
  createdAt: r.createdAt,
);

SaleReturnRow _saleReturnRow(SaleReturn r) => SaleReturnRow(
  id: r.id,
  saleId: r.saleId,
  sessionId: r.sessionId,
  lines: jsonEncode([for (final l in r.lines) l.toJson()]),
  amountCents: r.amountCents,
  cashCents: r.cashCents,
  reason: r.reason,
  clerk: r.clerk,
  createdAt: r.createdAt,
);

Layaway _layaway(LayawayRow r) => Layaway(
  id: r.id,
  customerId: r.customerId,
  description: r.description,
  totalCents: r.totalCents,
  createdAt: r.createdAt,
  dueDate: r.dueDate,
  status: r.status,
  photoPath: r.photoPath,
);

LayawayRow _layawayRow(Layaway l) => LayawayRow(
  id: l.id,
  customerId: l.customerId,
  description: l.description,
  totalCents: l.totalCents,
  createdAt: l.createdAt,
  dueDate: l.dueDate,
  status: l.status,
  photoPath: l.photoPath,
);

LayawayPayment _layawayPayment(LayawayPaymentRow r) => LayawayPayment(
  id: r.id,
  layawayId: r.layawayId,
  amountCents: r.amountCents,
  method: r.method,
  createdAt: r.createdAt,
  sessionId: r.sessionId,
);

LayawayPaymentRow _layawayPaymentRow(LayawayPayment p) => LayawayPaymentRow(
  id: p.id,
  layawayId: p.layawayId,
  amountCents: p.amountCents,
  method: p.method,
  createdAt: p.createdAt,
  sessionId: p.sessionId,
);

Tanda _batch(BatchRow r) =>
    Tanda(id: r.id, name: r.name, date: r.date, createdAt: r.createdAt, suppliesCents: r.suppliesCents);

BatchRow _batchRow(Tanda b) =>
    BatchRow(id: b.id, name: b.name, date: b.date, createdAt: b.createdAt, suppliesCents: b.suppliesCents);

BatchOrder _batchOrder(BatchOrderRow r) => BatchOrder(
  id: r.id,
  batchId: r.batchId,
  customerName: r.customerName,
  phone: r.phone,
  detail: r.detail,
  totalCents: r.totalCents,
  createdAt: r.createdAt,
  delivery: r.delivery,
  paid: r.paid,
);

BatchOrderRow _batchOrderRow(BatchOrder o) => BatchOrderRow(
  id: o.id,
  batchId: o.batchId,
  customerName: o.customerName,
  phone: o.phone,
  detail: o.detail,
  totalCents: o.totalCents,
  createdAt: o.createdAt,
  delivery: o.delivery,
  paid: o.paid,
);

DiningTable _table(DiningTableRow r) => DiningTable(
  id: r.id,
  name: r.name,
  position: r.position,
  active: r.active,
  zone: r.zone,
  x: r.posX,
  y: r.posY,
  shape: r.shape == 'round' ? TableShape.redonda : TableShape.cuadrada,
  seats: r.seats ?? 4,
);

DiningTableRow _tableRow(DiningTable t) => DiningTableRow(
  id: t.id,
  name: t.name,
  position: t.position,
  active: t.active,
  zone: t.zone,
  posX: t.x,
  posY: t.y,
  shape: t.shape == TableShape.redonda ? 'round' : 'square',
  seats: t.seats,
);

FloorItem _floorItem(FloorItemRow r) => FloorItem(
  id: r.id,
  zone: r.zone,
  kind: FloorItemKind.fromRemote(r.kind),
  label: r.label,
  x: r.posX,
  y: r.posY,
  width: r.width,
  height: r.height,
  active: r.active,
);

FloorItemRow _floorItemRow(FloorItem f) => FloorItemRow(
  id: f.id,
  zone: f.zone,
  kind: f.kind.remote,
  label: f.label,
  posX: f.x,
  posY: f.y,
  width: f.width,
  height: f.height,
  active: f.active,
);

RestaurantOrder _order(OrderRow r) => RestaurantOrder(
  id: r.id,
  tableId: r.tableId,
  label: r.label,
  status: r.status,
  createdAt: r.createdAt,
  closedAt: r.closedAt,
);

OrderRow _orderRow(RestaurantOrder o) => OrderRow(
  id: o.id,
  tableId: o.tableId,
  label: o.label,
  status: o.status,
  createdAt: o.createdAt,
  closedAt: o.closedAt,
);

OrderItem _orderItem(OrderItemRow r) => OrderItem(
  id: r.id,
  orderId: r.orderId,
  productId: r.productId,
  name: r.name,
  qty: r.qty,
  unitCents: r.unitCents,
  extras: extrasFromJson(r.extras),
  notes: r.notes,
  status: r.status,
  createdAt: r.createdAt,
  sentAt: r.sentAt,
  readyAt: r.readyAt,
  servedAt: r.servedAt,
  paidQty: r.paidQty,
);

OrderItemRow _orderItemRow(OrderItem i) => OrderItemRow(
  id: i.id,
  orderId: i.orderId,
  productId: i.productId,
  name: i.name,
  qty: i.qty,
  unitCents: i.unitCents,
  extras: extrasToJson(i.extras),
  notes: i.notes,
  status: i.status,
  createdAt: i.createdAt,
  sentAt: i.sentAt,
  readyAt: i.readyAt,
  servedAt: i.servedAt,
  paidQty: i.paidQty,
);

ProductRow _productRow(Product p) => ProductRow(
  id: p.id,
  name: p.name,
  priceCents: p.priceCents,
  costCents: p.costCents,
  barcode: p.barcode,
  iconId: p.iconId,
  trackStock: p.trackStock,
  stock: p.stock,
  minStock: p.minStock,
  active: p.active,
  photoPath: p.photoPath,
);

CreditRow _creditRow(CreditEntry e) => CreditRow(
  id: e.id,
  customerId: e.customerId,
  type: e.type,
  amountCents: e.amountCents,
  createdAt: e.createdAt,
  saleId: e.saleId,
  method: e.method,
  sessionId: e.sessionId,
  clerkName: e.clerk,
);

SessionRow _sessionRow(CashSession s) => SessionRow(
  id: s.id,
  openedAt: s.openedAt,
  openingCents: s.openingCents,
  closedAt: s.closedAt,
  expectedCents: s.expectedCents,
  countedCents: s.countedCents,
  device: s.device,
  name: s.name,
);

MovementRow _movementRow(CashMovement m) => MovementRow(
  id: m.id,
  sessionId: m.sessionId,
  kind: m.kind,
  amountCents: m.amountCents,
  concept: m.concept,
  createdAt: m.createdAt,
  clerkName: m.clerk,
);

ExtraRow _extraRow(Extra e) =>
    ExtraRow(id: e.id, name: e.name, priceCents: e.priceCents, active: e.active, position: e.position);
