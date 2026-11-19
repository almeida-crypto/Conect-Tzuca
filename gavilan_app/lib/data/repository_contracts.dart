part of 'repository.dart';

/// En la tabla de fotos, el logo del negocio va con este id en lugar del de un producto.
const logoPhotoId = 'logo';

/// Lo que se recupera al abrir la app.
class LoadedData {
  const LoadedData({required this.store, required this.plan});

  final StoreState store;
  final Plan plan;
}

/// Dónde se guardan los datos. Las pantallas solo hablan con esta interfaz.
abstract class StoreRepository {
  /// Clave corta de este teléfono para los folios, por ejemplo "K7".
  String get deviceCode;

  /// null si todavía no hay negocio (primer arranque).
  Future<LoadedData?> load();

  /// Reemplaza todo (alta del negocio o datos de ejemplo). Quita el enlace con la nube.
  Future<void> replaceAll(StoreState state, Plan plan);
  Future<void> clear();

  Future<void> upsertProduct(Product product, {required bool isNew});

  /// Cambia la existencia. [adjustment]: corrección a mano (conteo), no mercancía que llegó.
  Future<void> addStock(Product updated, double delta, {bool adjustment = false});
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  });

  /// Guarda una venta cancelada: lo que regresó al inventario y, si fue fiada, lo que se le quita al cliente.
  Future<void> cancelSale({required Sale sale, required List<Product> restocked, CreditEntry? reversal});
  Future<void> upsertCustomer(Customer customer);

  /// Tope general de fiado; sube a la fila del negocio si está enlazado.
  Future<void> setDefaultCreditLimit(int? cents);

  /// Formas de pago que acepta; sube a la fila del negocio si está enlazado.
  Future<void> setPayMethods(Set<PayMethod> methods);

  /// Nombre de la caja de este celular (solo en este celular; cada turno lo lleva consigo a la nube).
  Future<void> setRegisterName(String? name);

  /// En la cocina de este aparato, imprimir sola cada comanda nueva.
  Future<void> setKitchenPrint(bool on);

  /// Imprimir solo el ticket al cobrar (en este aparato).
  Future<void> setTicketPrint(bool on);
  Future<void> insertCredit(CreditEntry entry);
  Future<void> upsertSession(CashSession session);
  Future<void> insertMovement(CashMovement movement);
  Future<void> setPlan(Plan plan);

  /// Personas del mostrador y minutos para bloquear. Solo en este aparato: nunca suben a la nube.
  Future<void> setClerks(List<Clerk> clerks, int? lockMinutes);

  /// Guarda la foto de un producto (y borra las anteriores de ese producto).
  Future<void> savePhoto(String productId, String path, Uint8List bytes, {bool uploaded = false});

  /// Devolución de una venta de otro día: el registro, lo que vuelve al inventario y lo que se quita de la deuda.
  Future<void> recordReturn({required SaleReturn ret, required List<Product> restocked, CreditEntry? reversal});

  /// Logo del negocio: se guarda con las fotos (con [logoPhotoId]) y su ruta sube a la fila del negocio.
  /// Con null se quita.
  Future<void> setLogo(String? path, Uint8List? bytes);

  /// Tipo de negocio y módulos prendidos; sube a Supabase si el teléfono está enlazado.
  Future<void> setBusinessSetup(BusinessType type, Set<Module> modules);

  Future<void> upsertLot(Lot lot);
  Future<void> insertLotSale(LotSale sale);
  Future<void> upsertLayaway(Layaway layaway);
  Future<void> insertLayawayPayment(LayawayPayment payment);
  Future<void> upsertBatch(Tanda batch);
  Future<void> upsertBatchOrder(BatchOrder order);

  Future<void> upsertTable(DiningTable table);
  Future<void> upsertFloorItem(FloorItem item);
  Future<void> upsertExtra(Extra extra);
  Future<void> upsertOrder(RestaurantOrder order);
  Future<void> upsertOrderItems(List<OrderItem> items);

  /// Operaciones de sincronización; null si este almacenamiento no sincroniza.
  SyncStore? get sync;
}

/// Lo que necesita el motor de sincronización del almacenamiento local.
abstract class SyncStore {
  /// Negocio de Supabase al que está enlazado este teléfono (null = solo local).
  String? get linkedBusinessId;

  /// Rol de la cuenta en ese negocio (null = teléfono sin cuenta: es del dueño).
  /// Se queda aunque se cierre la sesión, para que un cajero no gane permisos así.
  MemberRole? get role;
  Future<void> setRole(MemberRole? role);

  /// Cuenta que se confirmó como parte del negocio en este teléfono. Solo si es la misma que está
  /// abierta y el servidor dice que ya no pertenece, se borran los datos (ver SyncController).
  String? get linkedUser;
  Future<void> setLinkedUser(String? userId);

  /// Enlaza con la nube. Con [uploadAll] anota todo lo que hay para subirlo.
  Future<void> link(String businessId, {StoreState? uploadAll});

  /// Borra lo local y prepara el teléfono para bajar un negocio de la nube.
  Future<void> prepareDownload(String businessId, String businessName);

  /// Cambios por subir en orden, después de [afterId]. Incluye los que el servidor rechazó menos de
  /// [maxAutoRetries] veces: se vuelven a intentar solos por si fue algo pasajero.
  Future<List<OutboxRow>> pending({int limit = 50, int afterId = 0});

  /// Cambios que todavía no se intentan o que no han fallado ("Por subir").
  Future<int> pendingCount();
  Future<void> markSent(int outboxId);
  Future<void> markFailed(int outboxId, String error);

  /// Cambios que el servidor rechazó (apartados: no frenan a los demás).
  Future<List<OutboxRow>> failed();
  Future<int> failedCount();

  /// Vuelve a intentar todos los apartados.
  Future<void> retryFailed();

  /// Deja de intentar subir un cambio apartado y vuelve a bajar de la nube sus tablas,
  /// para que el teléfono quede igual que la nube.
  Future<void> discardFailed(int outboxId);

  Future<DateTime?> cursor(String table);
  Future<void> setCursor(String table, DateTime at);

  /// Fotos tomadas aquí que falta subir a la nube.
  Future<List<PhotoRow>> pendingPhotos();
  Future<void> markPhotoUploaded(String path);

  /// Qué fotos ya están en este celular.
  Future<Set<String>> photoPaths();

  /// Aplica filas que bajaron de Supabase. No las vuelve a anotar para subir.
  Future<void> applyRemote(String table, List<RemoteRow> rows);
}

/// Sin almacenamiento: para la vista previa en navegador y algunas pruebas.
class MemoryRepository implements StoreRepository {
  @override
  final String deviceCode = newDeviceCode();

  @override
  Future<LoadedData?> load() async => null;
  @override
  Future<void> replaceAll(StoreState state, Plan plan) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> upsertProduct(Product product, {required bool isNew}) async {}
  @override
  Future<void> addStock(Product updated, double delta, {bool adjustment = false}) async {}
  @override
  Future<void> recordSale({
    required Sale sale,
    required List<Product> changedProducts,
    CreditEntry? charge,
    required int nextFolio,
  }) async {}
  @override
  Future<void> cancelSale({required Sale sale, required List<Product> restocked, CreditEntry? reversal}) async {}
  @override
  Future<void> upsertCustomer(Customer customer) async {}
  @override
  Future<void> setDefaultCreditLimit(int? cents) async {}
  @override
  Future<void> setPayMethods(Set<PayMethod> methods) async {}
  @override
  Future<void> setRegisterName(String? name) async {}
  @override
  Future<void> setKitchenPrint(bool on) async {}
  @override
  Future<void> setTicketPrint(bool on) async {}
  @override
  Future<void> insertCredit(CreditEntry entry) async {}
  @override
  Future<void> upsertSession(CashSession session) async {}
  @override
  Future<void> insertMovement(CashMovement movement) async {}
  @override
  Future<void> setPlan(Plan plan) async {}
  @override
  Future<void> setBusinessSetup(BusinessType type, Set<Module> modules) async {}
  @override
  Future<void> savePhoto(String productId, String path, Uint8List bytes, {bool uploaded = false}) async {}
  @override
  Future<void> setLogo(String? path, Uint8List? bytes) async {}
  @override
  Future<void> recordReturn({required SaleReturn ret, required List<Product> restocked, CreditEntry? reversal}) async {}
  @override
  Future<void> setClerks(List<Clerk> clerks, int? lockMinutes) async {}
  @override
  Future<void> upsertLot(Lot lot) async {}
  @override
  Future<void> insertLotSale(LotSale sale) async {}
  @override
  Future<void> upsertLayaway(Layaway layaway) async {}
  @override
  Future<void> insertLayawayPayment(LayawayPayment payment) async {}
  @override
  Future<void> upsertBatch(Tanda batch) async {}
  @override
  Future<void> upsertBatchOrder(BatchOrder order) async {}
  @override
  Future<void> upsertTable(DiningTable table) async {}
  @override
  Future<void> upsertFloorItem(FloorItem item) async {}
  @override
  Future<void> upsertExtra(Extra extra) async {}
  @override
  Future<void> upsertOrder(RestaurantOrder order) async {}
  @override
  Future<void> upsertOrderItems(List<OrderItem> items) async {}
  @override
  SyncStore? get sync => null;
}
