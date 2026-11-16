import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Qué puede hacer cada persona en el aparato compartido del mostrador.
enum ClerkRole {
  /// Todo lo de la cuenta del negocio (cancelar, ganancias, catálogo, personas).
  dueno('Dueño'),

  /// Cancela ventas, ve ganancias y cambia productos; no maneja a las personas ni el equipo.
  encargado('Encargado'),

  /// Cobra, fía, abona y registra gastos.
  cajero('Cajero');

  const ClerkRole(this.label);
  final String label;

  static ClerkRole fromName(String? name) => values.where((r) => r.name == name).firstOrNull ?? cajero;
}

/// Una persona del mostrador: nombre, permisos y su PIN de 4 cifras. Vive solo en este aparato (el PIN nunca
/// sube a la nube) y se guarda como huella con sal, no el número.
class Clerk {
  const Clerk({required this.id, required this.name, required this.role, required this.salt, required this.pinHash});

  /// Crea a la persona con un PIN nuevo.
  factory Clerk.create({required String name, required ClerkRole role, required String pin, String? id}) {
    final salt = _randomSalt();
    return Clerk(id: id ?? _randomSalt(), name: name.trim(), role: role, salt: salt, pinHash: hashPin(salt, pin));
  }

  final String id;
  final String name;
  final ClerkRole role;
  final String salt;
  final String pinHash;

  bool checkPin(String pin) => hashPin(salt, pin) == pinHash;

  Clerk withPin(String pin) {
    final s = _randomSalt();
    return Clerk(id: id, name: name, role: role, salt: s, pinHash: hashPin(s, pin));
  }

  Clerk copyWith({String? name, ClerkRole? role}) =>
      Clerk(id: id, name: name ?? this.name, role: role ?? this.role, salt: salt, pinHash: pinHash);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'role': role.name, 'salt': salt, 'pin': pinHash};

  static Clerk fromJson(Map<String, Object?> j) => Clerk(
    id: j['id']! as String,
    name: j['name']! as String,
    role: ClerkRole.fromName(j['role'] as String?),
    salt: j['salt']! as String,
    pinHash: j['pin']! as String,
  );
}

/// PIN válido: exactamente 4 cifras.
bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

String hashPin(String salt, String pin) => sha256.convert(utf8.encode('gavilan:$salt:$pin')).toString();

String _randomSalt() {
  final rnd = Random.secure();
  return base64UrlEncode(List.generate(12, (_) => rnd.nextInt(256)));
}

String clerksToJson(List<Clerk> clerks) => jsonEncode([for (final c in clerks) c.toJson()]);

List<Clerk> clerksFromJson(String? json) {
  if (json == null || json.isEmpty) return const [];
  final list = jsonDecode(json);
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map) Clerk.fromJson(Map<String, Object?>.from(e)),
  ];
}
