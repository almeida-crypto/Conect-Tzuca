/// Equipo del negocio: roles, miembros e invitaciones.
library;

import 'clerk.dart';

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
  const Permissions(this.role, {this.clerk});

  final MemberRole? role;

  /// Quien atiende en un aparato compartido (cambio de cajero con PIN). null si no se usan PIN.
  final ClerkRole? clerk;

  bool get _boss => role == null || role == MemberRole.owner || role == MemberRole.admin;

  /// La persona del mostrador puede lo de un encargado (o es el dueño).
  bool get _clerkManager => clerk == null || clerk != ClerkRole.cajero;

  /// La persona del mostrador es el dueño (o no se usan PIN).
  bool get _clerkOwner => clerk == null || clerk == ClerkRole.dueno;

  /// Dar de alta, editar y quitar productos (en la nube solo dueño y administrador).
  bool get editCatalog => _boss && _clerkManager;

  bool get manageTeam => (role == MemberRole.owner || role == MemberRole.admin) && _clerkOwner;

  /// Solo el dueño invita administradores.
  bool get inviteAdmins => role == MemberRole.owner && _clerkOwner;

  /// Borrar todo lo del teléfono.
  bool get resetPhone => _boss && _clerkOwner;

  /// Dar de alta a las personas del mostrador y sus PIN.
  bool get manageClerks => _boss && _clerkOwner;

  /// Agregar, renombrar o quitar mesas.
  bool get manageTables => _boss && _clerkManager;

  /// Cobrar ventas y cuentas de mesa (en la nube, meseros y cocina no registran ventas).
  bool get charge => _boss || role == MemberRole.cashier;

  /// Cancelar ventas: regresa dinero y mercancía, así que lo decide el dueño o un administrador.
  bool get cancelSales => _boss && _clerkManager;

  /// Poner topes de fiado y fiarle a alguien más de su tope.
  bool get manageCredit => _boss && _clerkManager;

  /// Ver costos y ganancia (en el corte): es información del dueño.
  bool get seeProfit => _boss && _clerkManager;

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
