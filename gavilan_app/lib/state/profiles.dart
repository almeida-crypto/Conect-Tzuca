import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profiles.dart';

/// Cambiar entre los negocios guardados en este teléfono. Lo pone la raíz de la app (main.dart);
/// en las pruebas no hay (null) y la app se comporta como antes, con un solo negocio.
abstract class BusinessSwitcher {
  List<DeviceProfile> get profiles;
  String get activeKey;

  /// Abre otro negocio de este teléfono.
  Future<void> switchTo(String key);

  /// Abre un archivo nuevo y vacío: la app pide el nombre y el tipo del negocio nuevo.
  Future<void> createNew();

  /// Abre un negocio de la cuenta: el que ya está en este teléfono, o uno nuevo que se baja de la nube.
  Future<void> openCloudBusiness({required String id, required String name, String? role});

  /// Quita un negocio de este teléfono (no del de abierto). Lo respaldado en la nube no se borra.
  Future<void> remove(String key);

  /// Mantiene al día el nombre, el id y el puesto del negocio abierto en la lista.
  Future<void> updateActive({String? businessId, String? name, String? role});
}

final businessSwitcherProvider = Provider<BusinessSwitcher?>((ref) => null);

/// Negocio de la cuenta que hay que bajar al abrir un archivo nuevo (al unirse con un código o al
/// abrir uno que todavía no está en este teléfono).
final pendingDownloadProvider = Provider<({String id, String name})?>((ref) => null);
