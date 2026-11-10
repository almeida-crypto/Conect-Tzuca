/// Equipo del negocio: roles, miembros e invitaciones.
library;

enum MemberRole {
  owner('Dueño'),
  admin('Administrador'),
  cashier('Cajero'),
  waiter('Mesero'),
  kitchen('Cocina');

  const MemberRole(this.label);

  final String label;

  static MemberRole? fromRemote(String? value) => values.where((r) => r.name == value).firstOrNull;
}

/// Qué puede hacer quien usa este teléfono. Sin cuenta, el teléfono es del dueño.
class Permissions {
  const Permissions(this.role);

  final MemberRole? role;

  bool get _boss => role == null || role == MemberRole.owner || role == MemberRole.admin;

  /// Dar de alta, editar y quitar productos (en la nube solo dueño y administrador).
  bool get editCatalog => _boss;

  bool get manageTeam => role == MemberRole.owner || role == MemberRole.admin;

  /// Solo el dueño invita administradores.
  bool get inviteAdmins => role == MemberRole.owner;

  /// Borrar todo lo del teléfono.
  bool get resetPhone => _boss;

  /// Agregar, renombrar o quitar mesas.
  bool get manageTables => _boss;

  /// Cobrar ventas y cuentas de mesa (en la nube, meseros y cocina no registran ventas).
  bool get charge => _boss || role == MemberRole.cashier;

  /// Meseros y cocina solo usan el restaurante: la app abre directo en mesas o cocina.
  bool get restaurantOnly => role == MemberRole.waiter || role == MemberRole.kitchen;
}

class TeamMember {
  const TeamMember({required this.id, required this.userId, required this.role, this.name});

  final String id;
  final String userId;
  final MemberRole role;
  final String? name;
}

class TeamInvite {
  const TeamInvite({required this.id, required this.code, required this.role, required this.expiresAt, this.name});

  final String id;
  final String code;
  final MemberRole role;
  final DateTime expiresAt;
  final String? name;

  /// "ABCD-EFGH", más fácil de dictar.
  String get prettyCode => formatInviteCode(code);
}

String formatInviteCode(String code) => code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
