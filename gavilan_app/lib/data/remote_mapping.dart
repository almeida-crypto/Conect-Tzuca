import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/restaurant.dart';
import 'database.dart';

// Traducción entre los modelos de la app y las filas de Supabase (proyecto-Gavilan).
// La app usa centavos y nombres en español; Supabase usa pesos (numeric) y enums en inglés.
// Las filas que se suben no llevan business_id: lo agrega el motor de sincronización.

typedef RemoteRow = Map<String, Object?>;

/// Un cambio por subir: tabla de Supabase y sus filas.
typedef RemoteChange = ({String table, List<RemoteRow> rows});

const _uuid = Uuid();

/// Id estable para filas que en el teléfono no tienen uno propio (renglones, movimientos).
String stableId(String name) => _uuid.v5(Namespace.url.value, 'gavilan:$name');

num _pesos(int cents) => cents / 100;

int _cents(Object? value) => switch (value) {
  null => 0,
  num n => (n * 100).round(),
  String s => ((num.tryParse(s) ?? 0) * 100).round(),
  _ => 0,
};

int? _centsOrNull(Object? value) => value == null ? null : _cents(value);

double _double(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? 0,
  _ => 0,
};

String _iso(DateTime d) => d.toUtc().toIso8601String();
DateTime _date(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

const _methodOut = {PayMethod.efectivo: 'cash', PayMethod.tarjeta: 'card', PayMethod.transferencia: 'transfer'};
final _methodIn = {for (final e in _methodOut.entries) e.value: e.key};
PayMethod? _method(Object? v) => _methodIn[v];

// ---------- Hacia Supabase ----------

/// Producto. [withStock] solo en el alta: después la existencia la lleva el servidor
/// con inventory_movements, para que dos teléfonos no se pisen.
RemoteRow productToRemote(Product p, {required bool withStock}) => {
  'id': p.id,
  'name': p.name,
  'barcode': p.barcode,
  'price': _pesos(p.priceCents),
  'cost': _pesos(p.costCents),
  'icon': p.iconId,
  'track_stock': p.trackStock,
  'min_stock': p.minStock,
  'is_active': p.active,
  if (withStock) 'stock_qty': p.stock,
};

RemoteRow customerToRemote(Customer c) => {'id': c.id, 'name': c.name, 'phone': c.phone};

RemoteRow sessionToRemote(CashSession s) => {
  'id': s.id,
  'opened_at': _iso(s.openedAt),
  'opening_amount': _pesos(s.openingCents),
  'closed_at': s.closedAt == null ? null : _iso(s.closedAt!),
  'expected_amount': s.expectedCents == null ? null : _pesos(s.expectedCents!),
  'counted_amount': s.countedCents == null ? null : _pesos(s.countedCents!),
};

RemoteRow creditToRemote(CreditEntry e) => {
  'id': e.id,
  'customer_id': e.customerId,
  'sale_id': e.saleId,
  'type': e.type == CreditType.cargo ? 'charge' : 'payment',
  'amount': _pesos(e.amountCents),
  'method': _methodOut[e.method],
  'cash_session_id': e.sessionId,
  'created_at': _iso(e.createdAt),
};

RemoteRow movementToRemote(CashMovement m) => {
  'id': m.id,
  'cash_session_id': m.sessionId,
  'kind': m.kind == CashKind.entrada ? 'in' : 'out',
  'amount': _pesos(m.amountCents),
  'concept': m.concept,
  'created_at': _iso(m.createdAt),
};

RemoteRow stockToRemote({
  required String id,
  required String productId,
  required double change,
  required String reason,
  required DateTime at,
  String? refId,
}) => {
  'id': id,
  'product_id': productId,
  'qty_change': change,
  'reason': reason,
  'ref_id': refId,
  'created_at': _iso(at),
};

/// Una venta completa: la venta, sus renglones y, si se pide, lo que descuenta del inventario.
List<RemoteChange> saleToRemote(Sale s, {Set<String> stockTracked = const {}}) {
  final sale = <String, Object?>{
    'id': s.id,
    'cash_session_id': s.sessionId,
    'customer_id': s.customerId,
    'folio': '${s.folio}',
    'device_id': s.device,
    'order_id': s.orderId,
    'status': s.kind == SaleKind.fiada ? 'credit' : 'paid',
    'subtotal': _pesos(s.totalCents),
    'discount': 0,
    'total': _pesos(s.totalCents),
    'pay_method': _methodOut[s.method],
    'received_amount': s.receivedCents == null ? null : _pesos(s.receivedCents!),
    'created_at': _iso(s.createdAt),
  };
  final items = [
    for (var i = 0; i < s.lines.length; i++)
      {
        'id': stableId('${s.id}/item/$i'),
        'sale_id': s.id,
        'product_id': s.lines[i].productId,
        'name_snapshot': s.lines[i].name,
        'qty': s.lines[i].qty,
        'unit_price': _pesos(s.lines[i].unitCents),
        'unit_cost': _pesos(s.lines[i].unitCostCents),
        'total': _pesos(s.lines[i].totalCents),
        'position': i,
      },
  ];
  final sold = <String, double>{};
  for (final l in s.lines) {
    if (l.productId != null && stockTracked.contains(l.productId)) {
      sold[l.productId!] = (sold[l.productId!] ?? 0) + l.qty;
    }
  }
  return [
    (table: 'sales', rows: [sale]),
    if (items.isNotEmpty) (table: 'sale_items', rows: items),
    if (sold.isNotEmpty)
      (
        table: 'inventory_movements',
        rows: [
          for (final e in sold.entries)
            stockToRemote(
              id: stableId('${s.id}/stock/${e.key}'),
              productId: e.key,
              change: -e.value,
              reason: 'sale',
              at: s.createdAt,
              refId: s.id,
            ),
        ],
      ),
  ];
}

// ---------- Desde Supabase (filas para la base del teléfono) ----------

ProductRow productFromRemote(RemoteRow r) => ProductRow(
  id: r['id']! as String,
  name: r['name']! as String,
  priceCents: _cents(r['price']),
  costCents: _cents(r['cost']),
  barcode: r['barcode'] as String?,
  iconId: (r['icon'] as String?) ?? 'otro',
  trackStock: (r['track_stock'] as bool?) ?? false,
  stock: _double(r['stock_qty']),
  minStock: r['min_stock'] == null ? null : _double(r['min_stock']),
  // Borrado lógico en el servidor = oculto en el teléfono.
  active: ((r['is_active'] as bool?) ?? true) && r['deleted_at'] == null,
);

CustomerRow customerFromRemote(RemoteRow r) =>
    CustomerRow(id: r['id']! as String, name: r['name']! as String, phone: r['phone'] as String?);

SessionRow sessionFromRemote(RemoteRow r) => SessionRow(
  id: r['id']! as String,
  openedAt: _date(r['opened_at']),
  openingCents: _cents(r['opening_amount']),
  closedAt: _dateOrNull(r['closed_at']),
  expectedCents: _centsOrNull(r['expected_amount']),
  countedCents: _centsOrNull(r['counted_amount']),
);

SaleRow saleFromRemote(RemoteRow r) => SaleRow(
  id: r['id']! as String,
  folio: int.tryParse('${r['folio']}') ?? 0,
  createdAt: _date(r['created_at']),
  kind: r['status'] == 'credit' ? SaleKind.fiada : SaleKind.pagada,
  sessionId: r['cash_session_id'] as String?,
  method: _method(r['pay_method']),
  receivedCents: _centsOrNull(r['received_amount']),
  customerId: r['customer_id'] as String?,
  device: r['device_id'] as String?,
  orderId: r['order_id'] as String?,
);

SaleLineRow saleLineFromRemote(RemoteRow r) => SaleLineRow(
  saleId: r['sale_id']! as String,
  position: (r['position'] as num?)?.toInt() ?? 0,
  lineKey: (r['product_id'] as String?) ?? r['id']! as String,
  productId: r['product_id'] as String?,
  name: r['name_snapshot']! as String,
  unitCents: _cents(r['unit_price']),
  unitCostCents: _cents(r['unit_cost']),
  qty: _double(r['qty']),
);

CreditRow creditFromRemote(RemoteRow r) => CreditRow(
  id: r['id']! as String,
  customerId: r['customer_id']! as String,
  type: r['type'] == 'charge' ? CreditType.cargo : CreditType.abono,
  amountCents: _cents(r['amount']),
  createdAt: _date(r['created_at']),
  saleId: r['sale_id'] as String?,
  method: _method(r['method']),
  sessionId: r['cash_session_id'] as String?,
);

MovementRow movementFromRemote(RemoteRow r) => MovementRow(
  id: r['id']! as String,
  sessionId: r['cash_session_id']! as String,
  kind: r['kind'] == 'in' ? CashKind.entrada : CashKind.gasto,
  amountCents: _cents(r['amount']),
  concept: r['concept']! as String,
  createdAt: _date(r['created_at']),
);

// ---------- Pacas y lotes, apartados y tandas ----------

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String? _dayOrNull(DateTime? d) => d == null ? null : _day(d);

const _layawayOut = {
  LayawayStatus.activo: 'active',
  LayawayStatus.liquidado: 'completed',
  LayawayStatus.cancelado: 'cancelled',
};
final _layawayIn = {for (final e in _layawayOut.entries) e.value: e.key};

const _deliveryOut = {
  DeliveryStatus.pendiente: 'pending',
  DeliveryStatus.listo: 'ready',
  DeliveryStatus.entregado: 'delivered',
};
final _deliveryIn = {for (final e in _deliveryOut.entries) e.value: e.key};

RemoteRow lotToRemote(Lot l) => {
  'id': l.id,
  'name': l.name,
  'investment': _pesos(l.investmentCents),
  'started_at': _day(l.startedAt),
  'closed_at': _dayOrNull(l.closedAt),
};

RemoteRow lotSaleToRemote(LotSale s) => {
  'id': s.id,
  'lot_id': s.lotId,
  'amount': _pesos(s.amountCents),
  'note': s.note,
  'cash_session_id': s.sessionId,
  'created_at': _iso(s.createdAt),
};

RemoteRow layawayToRemote(Layaway l) => {
  'id': l.id,
  'customer_id': l.customerId,
  'description': l.description,
  'total': _pesos(l.totalCents),
  'due_date': _dayOrNull(l.dueDate),
  'status': _layawayOut[l.status],
  'created_at': _iso(l.createdAt),
};

RemoteRow layawayPaymentToRemote(LayawayPayment p) => {
  'id': p.id,
  'layaway_id': p.layawayId,
  'amount': _pesos(p.amountCents),
  'method': _methodOut[p.method],
  'cash_session_id': p.sessionId,
  'created_at': _iso(p.createdAt),
};

RemoteRow batchToRemote(Tanda b) => {
  'id': b.id,
  'name': b.name,
  'batch_date': _day(b.date),
  'supplies_cost': _pesos(b.suppliesCents),
  'created_at': _iso(b.createdAt),
};

RemoteRow batchOrderToRemote(BatchOrder o) => {
  'id': o.id,
  'batch_id': o.batchId,
  'customer_name': o.customerName,
  'phone': o.phone,
  'detail': o.detail,
  'total': _pesos(o.totalCents),
  'delivery_status': _deliveryOut[o.delivery],
  'pay_status': o.paid ? 'paid' : 'unpaid',
  'created_at': _iso(o.createdAt),
};

LotRow lotFromRemote(RemoteRow r) => LotRow(
  id: r['id']! as String,
  name: r['name']! as String,
  investmentCents: _cents(r['investment']),
  startedAt: _date(r['started_at']),
  closedAt: _dateOrNull(r['closed_at']),
);

LotSaleRow lotSaleFromRemote(RemoteRow r) => LotSaleRow(
  id: r['id']! as String,
  lotId: r['lot_id']! as String,
  amountCents: _cents(r['amount']),
  createdAt: _date(r['created_at']),
  note: r['note'] as String?,
  sessionId: r['cash_session_id'] as String?,
);

LayawayRow layawayFromRemote(RemoteRow r) => LayawayRow(
  id: r['id']! as String,
  customerId: r['customer_id']! as String,
  description: r['description']! as String,
  totalCents: _cents(r['total']),
  createdAt: _date(r['created_at']),
  dueDate: _dateOrNull(r['due_date']),
  status: _layawayIn[r['status']] ?? LayawayStatus.activo,
);

LayawayPaymentRow layawayPaymentFromRemote(RemoteRow r) => LayawayPaymentRow(
  id: r['id']! as String,
  layawayId: r['layaway_id']! as String,
  amountCents: _cents(r['amount']),
  method: _method(r['method']) ?? PayMethod.efectivo,
  createdAt: _date(r['created_at']),
  sessionId: r['cash_session_id'] as String?,
);

BatchRow batchFromRemote(RemoteRow r) => BatchRow(
  id: r['id']! as String,
  name: r['name']! as String,
  date: _date(r['batch_date']),
  createdAt: _date(r['created_at']),
  suppliesCents: _cents(r['supplies_cost']),
);

BatchOrderRow batchOrderFromRemote(RemoteRow r) => BatchOrderRow(
  id: r['id']! as String,
  batchId: r['batch_id']! as String,
  customerName: r['customer_name']! as String,
  phone: r['phone'] as String?,
  detail: r['detail'] as String?,
  totalCents: _cents(r['total']),
  createdAt: _date(r['created_at']),
  delivery: _deliveryIn[r['delivery_status']] ?? DeliveryStatus.pendiente,
  paid: r['pay_status'] == 'paid',
);

// ---------- Restaurante ----------

const _orderStatusOut = {
  OrderStatus.abierta: 'open',
  OrderStatus.cerrada: 'closed',
  OrderStatus.cancelada: 'cancelled',
};
final _orderStatusIn = {for (final e in _orderStatusOut.entries) e.value: e.key};

const _kitchenOut = {
  KitchenStatus.pendiente: 'pending',
  KitchenStatus.preparando: 'preparing',
  KitchenStatus.listo: 'ready',
  KitchenStatus.servido: 'served',
  KitchenStatus.cancelado: 'cancelled',
};
final _kitchenIn = {for (final e in _kitchenOut.entries) e.value: e.key};

RemoteRow tableToRemote(DiningTable t) => {
  'id': t.id,
  'name': t.name,
  'position': t.position,
  'is_active': t.active,
  'zone': t.zone,
};

RemoteRow orderToRemote(RestaurantOrder o) => {
  'id': o.id,
  'table_id': o.tableId,
  'order_type': o.takeout ? 'takeout' : 'dine_in',
  'status': _orderStatusOut[o.status],
  'label': o.label,
  'created_at': _iso(o.createdAt),
  'closed_at': o.closedAt == null ? null : _iso(o.closedAt!),
};

RemoteRow orderItemToRemote(OrderItem i) => {
  'id': i.id,
  'order_id': i.orderId,
  'product_id': i.productId,
  'name_snapshot': i.name,
  'qty': i.qty,
  'unit_price': _pesos(i.unitCents),
  'notes': i.notes,
  'status': _kitchenOut[i.status],
  'created_at': _iso(i.createdAt),
  'sent_at': i.sentAt == null ? null : _iso(i.sentAt!),
  'ready_at': i.readyAt == null ? null : _iso(i.readyAt!),
  'served_at': i.servedAt == null ? null : _iso(i.servedAt!),
};

DiningTableRow tableFromRemote(RemoteRow r) => DiningTableRow(
  id: r['id']! as String,
  name: r['name']! as String,
  position: (r['position'] as num?)?.toInt() ?? 0,
  active: (r['is_active'] as bool?) ?? true,
  zone: r['zone'] as String?,
);

OrderRow orderFromRemote(RemoteRow r) => OrderRow(
  id: r['id']! as String,
  tableId: r['table_id'] as String?,
  label: r['label'] as String?,
  status: _orderStatusIn[r['status']] ?? OrderStatus.abierta,
  createdAt: _date(r['created_at']),
  closedAt: _dateOrNull(r['closed_at']),
);

OrderItemRow orderItemFromRemote(RemoteRow r) => OrderItemRow(
  id: r['id']! as String,
  orderId: r['order_id']! as String,
  productId: r['product_id'] as String?,
  name: r['name_snapshot']! as String,
  qty: _double(r['qty']),
  unitCents: _cents(r['unit_price']),
  notes: r['notes'] as String?,
  status: _kitchenIn[r['status']] ?? KitchenStatus.pendiente,
  createdAt: _date(r['created_at']),
  sentAt: _dateOrNull(r['sent_at']),
  readyAt: _dateOrNull(r['ready_at']),
  servedAt: _dateOrNull(r['served_at']),
);
