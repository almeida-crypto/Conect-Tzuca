import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/database.dart';
import 'data/profiles.dart';
import 'data/repository.dart';
import 'data/sync_remote.dart';
import 'state/profiles.dart';
import 'state/store.dart';
import 'state/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Las fuentes van dentro de la app (assets/google_fonts/): no hace falta internet para verlas.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope', 'SpaceMono']) {
      final text = await rootBundle.loadString('assets/google_fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts'], text);
    }
  });

  // Todo se guarda en SQLite (en el teléfono, o en el navegador con sqlite3.wasm) y se respalda
  // en Supabase si hay cuenta. Cada negocio de este teléfono tiene su propio archivo.
  final registry = await ProfileRegistry.open();

  // No necesita internet: recupera la sesión guardada y la renueva cuando hay señal.
  // Los enlaces de los correos los abre AuthLinkListener, que sabe a qué pantalla llevar.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  final SyncRemote remote = SupabaseRemote(Supabase.instance.client);

  runApp(ProfileHost(registry: registry, remote: remote));
}

/// Abre el negocio activo de este teléfono y permite cambiar a otro: cierra el archivo de uno, abre el
/// del otro y arranca la app de nuevo con sus datos (cada negocio con su respaldo, su puesto y su caja).
class ProfileHost extends StatefulWidget {
  const ProfileHost({super.key, required this.registry, required this.remote});

  final ProfileRegistry registry;
  final SyncRemote remote;

  @override
  State<ProfileHost> createState() => _ProfileHostState();
}

class _ProfileHostState extends State<ProfileHost> implements BusinessSwitcher {
  GavilanDb? _db;
  StoreRepository? _repo;
  LoadedData? _loaded;
  ({String id, String name})? _pending;
  int _generation = 0;
  bool _splash = true;
  String? _notice;

  ProfileRegistry get _registry => widget.registry;

  @override
  void initState() {
    super.initState();
    _open(_registry.activeKey);
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  Future<void> _open(String key, {({String id, String name})? pending}) async {
    final old = _db;
    final db = GavilanDb.onDevice(name: key);
    final repo = DriftRepository(db);
    final loaded = await repo.load();
    await _registry.setActive(key);
    // El primero (el de siempre) también queda en la lista.
    if (_registry.all.every((p) => p.key != key)) {
      await _registry.upsert(
        DeviceProfile(
          key: key,
          name: loaded?.store.businessName ?? pending?.name ?? 'Negocio nuevo',
          businessId: pending?.id,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _db = db;
      _repo = repo;
      _loaded = loaded;
      _pending = pending;
      _generation++;
      if (_generation > 1) _splash = false; // la animación del inicio solo al abrir la app
    });
    // El archivo anterior se cierra cuando la app ya usa el nuevo.
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.close());
  }

  @override
  List<DeviceProfile> get profiles => _registry.all;

  @override
  String get activeKey => _registry.activeKey;

  @override
  Future<void> switchTo(String key) async {
    if (key == activeKey) return;
    final leaving = _registry.all.where((p) => p.key == activeKey).firstOrNull;
    await _open(key);
    // Un negocio nuevo que se dejó sin crear no se queda en la lista como "Negocio nuevo".
    if (leaving != null && leaving.businessId == null) await remove(leaving.key);
  }

  @override
  Future<void> createNew() async {
    final key = _registry.newKey();
    await _registry.upsert(DeviceProfile(key: key, name: 'Negocio nuevo'));
    await _open(key);
  }

  @override
  Future<void> openCloudBusiness({required String id, required String name, String? role}) async {
    final existing = _registry.byBusiness(id);
    if (existing != null) return switchTo(existing.key);
    final key = _registry.newKey();
    await _registry.upsert(DeviceProfile(key: key, name: name, businessId: id, role: role));
    await _open(key, pending: (id: id, name: name));
  }

  @override
  Future<void> remove(String key) async {
    if (key == activeKey) return;
    final db = GavilanDb.onDevice(name: key);
    await DriftRepository(db).clear();
    await db.close();
    await _registry.remove(key);
    if (mounted) setState(() {});
  }

  @override
  Future<void> forgetActive({required String notice}) async {
    final leaving = activeKey;
    final other = _registry.all.where((p) => p.key != leaving && p.businessId != null).firstOrNull;
    final next = other?.key ?? _registry.newKey();
    if (other == null) await _registry.upsert(DeviceProfile(key: next, name: 'Negocio nuevo'));
    _notice = notice;
    await _open(next);
    await remove(leaving);
  }

  @override
  void clearNotice() => _notice = null;

  @override
  Future<void> updateActive({String? businessId, String? name, String? role}) async {
    final current = _registry.all.where((p) => p.key == activeKey).firstOrNull;
    if (current == null) return;
    final next = current.copyWith(businessId: businessId, name: name, role: role);
    if (next.toJson().toString() != current.toJson().toString()) await _registry.upsert(next);
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) return const ColoredBox(color: Color(0xFFF5F4F1));
    return ProviderScope(
      key: ValueKey(_generation),
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        initialDataProvider.overrideWithValue(_loaded),
        syncRemoteProvider.overrideWithValue(widget.remote),
        businessSwitcherProvider.overrideWithValue(this),
        pendingDownloadProvider.overrideWithValue(_pending),
        hostNoticeProvider.overrideWithValue(_notice),
      ],
      child: GavilanApp(showSplash: _splash),
    );
  }
}
