import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Un negocio guardado en este teléfono. Cada uno vive en su propio archivo ([key]), así una persona
/// puede ser mesera en un restaurante y dueña de su propio negocio sin que se mezclen.
class DeviceProfile {
  const DeviceProfile({required this.key, required this.name, this.businessId, this.role});

  /// Nombre del archivo de su base local ("gavilan", "gavilan_k7m2q9xa").
  final String key;
  final String name;

  /// Id del negocio (en la nube, si está respaldado). null mientras no se crea.
  final String? businessId;

  /// Puesto en ese negocio ("owner", "waiter"...). null sin cuenta.
  final String? role;

  DeviceProfile copyWith({String? name, String? businessId, String? role}) => DeviceProfile(
    key: key,
    name: name ?? this.name,
    businessId: businessId ?? this.businessId,
    role: role ?? this.role,
  );

  Map<String, Object?> toJson() => {'key': key, 'name': name, 'businessId': businessId, 'role': role};

  static DeviceProfile fromJson(Map<String, Object?> j) => DeviceProfile(
    key: j['key']! as String,
    name: (j['name'] as String?) ?? 'Mi negocio',
    businessId: j['businessId'] as String?,
    role: j['role'] as String?,
  );
}

/// Lista de negocios de este teléfono y cuál está abierto. Se guarda aparte de las bases de cada negocio.
class ProfileRegistry {
  ProfileRegistry(this._prefs);

  static const firstKey = 'gavilan';
  static const _kProfiles = 'gavilan.profiles';
  static const _kActive = 'gavilan.active_profile';

  final SharedPreferences _prefs;

  static Future<ProfileRegistry> open() async => ProfileRegistry(await SharedPreferences.getInstance());

  List<DeviceProfile> get all {
    final raw = _prefs.getString(_kProfiles);
    if (raw == null) return const [];
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) DeviceProfile.fromJson(Map<String, Object?>.from(e)),
    ];
  }

  /// El negocio abierto. Al principio, el archivo de siempre ("gavilan").
  String get activeKey => _prefs.getString(_kActive) ?? firstKey;

  Future<void> setActive(String key) => _prefs.setString(_kActive, key);

  Future<void> _save(List<DeviceProfile> list) =>
      _prefs.setString(_kProfiles, jsonEncode([for (final p in list) p.toJson()]));

  /// Agrega o actualiza un negocio (por su archivo).
  Future<void> upsert(DeviceProfile p) {
    final list = all;
    final i = list.indexWhere((x) => x.key == p.key);
    return _save(i < 0 ? [...list, p] : [for (final x in list) x.key == p.key ? p : x]);
  }

  Future<void> remove(String key) => _save([
    for (final x in all)
      if (x.key != key) x,
  ]);

  DeviceProfile? byBusiness(String businessId) => all.where((p) => p.businessId == businessId).firstOrNull;

  /// Nombre de archivo nuevo, que no choque con los que ya hay.
  String newKey() {
    const letters = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    final taken = {firstKey, for (final p in all) p.key};
    while (true) {
      final key = 'gavilan_${List.generate(8, (_) => letters[rnd.nextInt(letters.length)]).join()}';
      if (!taken.contains(key)) return key;
    }
  }
}
