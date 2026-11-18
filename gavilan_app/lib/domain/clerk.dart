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

/// Vueltas de PBKDF2 para la huella del PIN: con 4 cifras solo hay 10,000 PIN posibles, así que cada prueba
/// tiene que costar. 20,000 tarda una fracción de segundo al entrar, pero hace lento probarlos todos.
const pinIterations = 20000;

/// Una persona del mostrador: nombre, permisos y su PIN de 4 cifras. Vive solo en este aparato (el PIN nunca
/// sube a la nube) y se guarda como huella con sal (PBKDF2), no el número.
class Clerk {
  const Clerk({
    required this.id,
    required this.name,
    required this.role,
    required this.salt,
    required this.pinHash,
    this.iterations = pinIterations,
  });

  /// Crea a la persona con un PIN nuevo.
  factory Clerk.create({required String name, required ClerkRole role, required String pin, String? id}) {
    final salt = _randomSalt();
    return Clerk(id: id ?? _randomSalt(), name: name.trim(), role: role, salt: salt, pinHash: hashPin(salt, pin));
  }

  /// Vueltas con que se hizo la huella. 0 = forma de antes (un solo SHA-256), se cambia sola al entrar.
  final int iterations;

  /// La huella es de la forma de antes y conviene rehacerla.
  bool get legacyHash => iterations < pinIterations;

  final String id;
  final String name;
  final ClerkRole role;
  final String salt;
  final String pinHash;

  bool checkPin(String pin) => _constantTimeEquals(hashPin(salt, pin, iterations: iterations), pinHash);

  Clerk withPin(String pin) {
    final s = _randomSalt();
    return Clerk(id: id, name: name, role: role, salt: s, pinHash: hashPin(s, pin));
  }

  Clerk copyWith({String? name, ClerkRole? role}) => Clerk(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    salt: salt,
    pinHash: pinHash,
    iterations: iterations,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'salt': salt,
    'pin': pinHash,
    'it': iterations,
  };

  static Clerk fromJson(Map<String, Object?> j) => Clerk(
    id: j['id']! as String,
    name: j['name']! as String,
    role: ClerkRole.fromName(j['role'] as String?),
    salt: j['salt']! as String,
    pinHash: j['pin']! as String,
    // Las de antes no traen vueltas: eran un solo SHA-256.
    iterations: (j['it'] as num?)?.toInt() ?? 0,
  );
}

/// PIN válido: exactamente 4 cifras.
bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

/// Huella del PIN. Con [iterations] 0 es la forma de antes (un solo SHA-256), solo para revisar PIN viejos.
String hashPin(String salt, String pin, {int iterations = pinIterations}) {
  if (iterations <= 0) return sha256.convert(utf8.encode('gavilan:$salt:$pin')).toString();
  return _hex(pbkdf2Sha256(utf8.encode(pin), utf8.encode('gavilan:$salt'), iterations));
}

/// PBKDF2 con HMAC-SHA256, un bloque de 32 bytes (RFC 8018).
List<int> pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final mac = Hmac(sha256, password);
  var u = mac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = List<int>.of(u);
  for (var i = 1; i < iterations; i++) {
    u = mac.convert(u).bytes;
    for (var k = 0; k < out.length; k++) {
      out[k] ^= u[k];
    }
  }
  return out;
}

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

/// Compara sin cortar en la primera diferencia (no da pistas por el tiempo que tarda).
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

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
