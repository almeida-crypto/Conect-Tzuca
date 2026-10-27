import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'state/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En el teléfono todo se guarda en SQLite. En el navegador (solo vista previa)
  // se trabaja en memoria y se pierde al recargar.
  final StoreRepository repository = kIsWeb ? MemoryRepository() : DriftRepository(GavilanDb.onDevice());
  final loaded = await repository.load();

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository), initialDataProvider.overrideWithValue(loaded)],
      child: const GavilanApp(),
    ),
  );
}
