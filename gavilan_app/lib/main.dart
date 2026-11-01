import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'data/sync_remote.dart';
import 'state/store.dart';
import 'state/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Las fuentes van dentro de la app (assets/google_fonts/): no hace falta internet para verlas.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Archivo', 'SpaceMono']) {
      final text = await rootBundle.loadString('assets/google_fonts/OFL-$family.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts'], text);
    }
  });

  // En el teléfono todo se guarda en SQLite y se respalda en Supabase si hay cuenta.
  // En el navegador (solo vista previa) se trabaja en memoria, sin respaldo.
  final StoreRepository repository = kIsWeb ? MemoryRepository() : DriftRepository(GavilanDb.onDevice());
  final loaded = await repository.load();

  SyncRemote? remote;
  if (!kIsWeb) {
    // No necesita internet: recupera la sesión guardada y la renueva cuando hay señal.
    // Los enlaces de los correos los abre AuthLinkListener, que sabe a qué pantalla llevar.
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    remote = SupabaseRemote(Supabase.instance.client);
  }

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        initialDataProvider.overrideWithValue(loaded),
        syncRemoteProvider.overrideWithValue(remote),
      ],
      child: const GavilanApp(),
    ),
  );
}
