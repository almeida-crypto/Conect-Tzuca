import 'dart:math' as math;

import 'models.dart';

/// Qué pasa con lo abonado si el cliente cancela. Lo decide el dueño en "Reglas del apartado".
enum CancelRule {
  preguntar('Decidirlo cada vez', 'ask'),
  devolverTodo('Se le devuelve todo lo abonado', 'refund_all'),
  quedarsePorcentaje('Se le devuelve, menos un porcentaje', 'keep_percent'),
  quedarseAnticipo('Se queda el anticipo; se le devuelven los abonos', 'keep_deposit'),
  noDevolver('No se devuelve nada', 'keep_all'),
  saldoAFavor('Queda como saldo a favor para otra compra', 'store_credit');

  const CancelRule(this.label, this.remote);

  final String label;
  final String remote;

  static CancelRule fromRemote(Object? v) =>
      CancelRule.values.firstWhere((r) => r.remote == v, orElse: () => CancelRule.preguntar);
}

/// Las reglas del apartado de este negocio. Sin configurar = como siempre: 30 días, sin anticipo mínimo y al
/// cancelar se decide cada vez.
class LayawayRules {
  const LayawayRules({
    this.cancel = CancelRule.preguntar,
    this.keepPct = 10,
    this.days = 30,
    this.minDepositPct,
    this.note,
  });

  final CancelRule cancel;

  /// Con [CancelRule.quedarsePorcentaje]: qué parte de lo abonado se queda el negocio.
  final int keepPct;

  /// Plazo para liquidar (la fecha límite que sale al apartar). null = sin fecha.
  final int? days;

  /// Anticipo mínimo, en porcentaje del precio. null = el que quiera dejar.
  final int? minDepositPct;

  /// Condiciones que salen en el comprobante ("No hay cambios en ropa interior").
  final String? note;

  static const standard = LayawayRules();

  bool get isStandard => cancel == CancelRule.preguntar && days == 30 && minDepositPct == null && (note ?? '').isEmpty;

  int minDepositFor(int totalCents) => minDepositPct == null ? 0 : (totalCents * minDepositPct! / 100).ceil();

  /// El texto de la regla de cancelación, para el comprobante y la pantalla.
  String get cancelText => switch (cancel) {
    CancelRule.preguntar => '',
    CancelRule.devolverTodo => 'Si cancelas, se te devuelve todo lo abonado.',
    CancelRule.quedarsePorcentaje => 'Si cancelas, se te devuelve lo abonado menos el $keepPct%.',
    CancelRule.quedarseAnticipo => 'Si cancelas, el anticipo no se devuelve; los abonos sí.',
    CancelRule.noDevolver => 'Si cancelas, lo abonado no se devuelve.',
    CancelRule.saldoAFavor => 'Si cancelas, lo abonado queda como saldo a favor para otra compra.',
  };

  Map<String, Object?> toJson() => {
    'cancel': cancel.remote,
    if (cancel == CancelRule.quedarsePorcentaje) 'keep_pct': keepPct,
    'days': days,
    'min_deposit_pct': minDepositPct,
    if ((note ?? '').isNotEmpty) 'note': note,
  };

  static LayawayRules fromJson(Object? json) {
    if (json is! Map) return standard;
    int? pct(Object? v, {int max = 100}) => v is num ? v.round().clamp(0, max) : null;
    final note = json['note'];
    return LayawayRules(
      cancel: CancelRule.fromRemote(json['cancel']),
      keepPct: pct(json['keep_pct']) ?? 10,
      days: json.containsKey('days') ? pct(json['days'], max: 365) : 30,
      minDepositPct: pct(json['min_deposit_pct']),
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }

  LayawayRules copyWith({
    CancelRule? cancel,
    int? keepPct,
    int? days,
    bool noDays = false,
    int? minDepositPct,
    bool noMinDeposit = false,
    String? note,
  }) => LayawayRules(
    cancel: cancel ?? this.cancel,
    keepPct: keepPct ?? this.keepPct,
    days: noDays ? null : (days ?? this.days),
    minDepositPct: noMinDeposit ? null : (minDepositPct ?? this.minDepositPct),
    note: note ?? this.note,
  );
}

/// Cómo queda el dinero al cancelar: lo que se le devuelve, lo que queda como saldo a favor y lo que se
/// queda el negocio. [paid] es todo lo abonado; [deposit], el anticipo.
({int refund, int credit, int kept}) cancelSplit(
  CancelRule rule, {
  required int paid,
  required int deposit,
  int keepPct = 10,
}) {
  final (refund, credit) = switch (rule) {
    CancelRule.preguntar || CancelRule.devolverTodo => (paid, 0),
    CancelRule.quedarsePorcentaje => (paid - (paid * keepPct / 100).round(), 0),
    CancelRule.quedarseAnticipo => (math.max(0, paid - deposit), 0),
    CancelRule.noDevolver => (0, 0),
    CancelRule.saldoAFavor => (0, paid),
  };
  return (refund: refund, credit: credit, kept: paid - refund - credit);
}

// ---------- Recordatorios ----------

enum ReminderReason { vence, vencido, abono, recoger }

/// A quién hay que avisarle hoy y por qué. null = nada que avisar (o ya se le avisó hace poco).
ReminderReason? reminderFor(
  Layaway l, {
  required int pendingCents,
  required DateTime? lastPaymentAt,
  required DateTime now,
}) {
  // Un aviso cada 2 días como mucho: que no se sienta acoso.
  if (l.remindedAt != null && now.difference(l.remindedAt!) < const Duration(hours: 44)) return null;
  final today = DateTime(now.year, now.month, now.day);
  if (l.status == LayawayStatus.liquidado && !l.delivered) return ReminderReason.recoger;
  if (l.status != LayawayStatus.activo || pendingCents <= 0) return null;
  if (l.dueDate != null) {
    final due = DateTime(l.dueDate!.year, l.dueDate!.month, l.dueDate!.day);
    if (due.isBefore(today)) return ReminderReason.vencido;
    if (due.difference(today).inDays <= 3) return ReminderReason.vence;
  }
  if (l.payEveryDays != null) {
    final from = lastPaymentAt ?? l.createdAt;
    final next = DateTime(from.year, from.month, from.day).add(Duration(days: l.payEveryDays!));
    if (!next.isAfter(today)) return ReminderReason.abono;
  }
  return null;
}

String reminderTitle(ReminderReason r) => switch (r) {
  ReminderReason.vence => 'Se acerca la fecha',
  ReminderReason.vencido => 'Ya pasó la fecha',
  ReminderReason.abono => 'Le toca abonar',
  ReminderReason.recoger => 'Ya puede recogerlo',
};

/// El mensaje para mandarle por WhatsApp.
String reminderMessage(
  ReminderReason r, {
  required String business,
  required String customer,
  required String what,
  required String pending,
  required String paid,
  required String total,
  String? due,
}) {
  final hello = customer.trim().isEmpty ? 'Hola' : 'Hola ${customer.trim().split(' ').first}';
  return switch (r) {
    ReminderReason.vence =>
      '$hello, te recordamos que tu apartado de $what en $business vence el $due. '
          'Te faltan $pending. ¡Te esperamos!',
    ReminderReason.vencido =>
      '$hello, tu apartado de $what en $business venció el $due y te faltan $pending. '
          'Pasa a liquidarlo o escríbenos para ponernos de acuerdo.',
    ReminderReason.abono =>
      '$hello, te recordamos tu abono del apartado de $what en $business. '
          'Llevas $paid de $total; te faltan $pending.',
    ReminderReason.recoger => '$hello, tu apartado de $what en $business ya está liquidado. ¡Ya puedes pasar por él!',
  };
}
