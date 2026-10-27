// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OutboxTableTable extends OutboxTable with TableInfo<$OutboxTableTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload, createdAt, attempts, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta, attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta, lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      payload: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attempts: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $OutboxTableTable createAlias(String alias) {
    return $OutboxTableTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const OutboxRow({
    required this.id,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxTableCompanion toCompanion(bool nullToAbsent) {
    return OutboxTableCompanion(
      id: Value(id),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent ? const Value.absent() : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(OutboxTableCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxTableCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxTableCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxTableCompanion.insert({
    this.id = const Value.absent(),
    required String payload,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxTableCompanion copyWith({
    Value<int>? id,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxTableCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxTableCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $ProductsTableTable extends ProductsTable with TableInfo<$ProductsTableTable, ProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceCentsMeta = const VerificationMeta('priceCents');
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
    'price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costCentsMeta = const VerificationMeta('costCents');
  @override
  late final GeneratedColumn<int> costCents = GeneratedColumn<int>(
    'cost_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconIdMeta = const VerificationMeta('iconId');
  @override
  late final GeneratedColumn<String> iconId = GeneratedColumn<String>(
    'icon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('otro'),
  );
  static const VerificationMeta _trackStockMeta = const VerificationMeta('trackStock');
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
    'track_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("track_stock" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<double> stock = GeneratedColumn<double>(
    'stock',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minStockMeta = const VerificationMeta('minStock');
  @override
  late final GeneratedColumn<double> minStock = GeneratedColumn<double>(
    'min_stock',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    priceCents,
    costCents,
    barcode,
    iconId,
    trackStock,
    stock,
    minStock,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<ProductRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(_priceCentsMeta, priceCents.isAcceptableOrUnknown(data['price_cents']!, _priceCentsMeta));
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('cost_cents')) {
      context.handle(_costCentsMeta, costCents.isAcceptableOrUnknown(data['cost_cents']!, _costCentsMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta, barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('icon_id')) {
      context.handle(_iconIdMeta, iconId.isAcceptableOrUnknown(data['icon_id']!, _iconIdMeta));
    }
    if (data.containsKey('track_stock')) {
      context.handle(_trackStockMeta, trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta));
    }
    if (data.containsKey('stock')) {
      context.handle(_stockMeta, stock.isAcceptableOrUnknown(data['stock']!, _stockMeta));
    }
    if (data.containsKey('min_stock')) {
      context.handle(_minStockMeta, minStock.isAcceptableOrUnknown(data['min_stock']!, _minStockMeta));
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta, active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      priceCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}price_cents'])!,
      costCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}cost_cents'])!,
      barcode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      iconId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}icon_id'])!,
      trackStock: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}track_stock'])!,
      stock: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}stock'])!,
      minStock: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}min_stock']),
      active: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
    );
  }

  @override
  $ProductsTableTable createAlias(String alias) {
    return $ProductsTableTable(attachedDatabase, alias);
  }
}

class ProductRow extends DataClass implements Insertable<ProductRow> {
  final String id;
  final String name;
  final int priceCents;
  final int costCents;
  final String? barcode;
  final String iconId;
  final bool trackStock;
  final double stock;
  final double? minStock;
  final bool active;
  const ProductRow({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.costCents,
    this.barcode,
    required this.iconId,
    required this.trackStock,
    required this.stock,
    this.minStock,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['price_cents'] = Variable<int>(priceCents);
    map['cost_cents'] = Variable<int>(costCents);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['icon_id'] = Variable<String>(iconId);
    map['track_stock'] = Variable<bool>(trackStock);
    map['stock'] = Variable<double>(stock);
    if (!nullToAbsent || minStock != null) {
      map['min_stock'] = Variable<double>(minStock);
    }
    map['active'] = Variable<bool>(active);
    return map;
  }

  ProductsTableCompanion toCompanion(bool nullToAbsent) {
    return ProductsTableCompanion(
      id: Value(id),
      name: Value(name),
      priceCents: Value(priceCents),
      costCents: Value(costCents),
      barcode: barcode == null && nullToAbsent ? const Value.absent() : Value(barcode),
      iconId: Value(iconId),
      trackStock: Value(trackStock),
      stock: Value(stock),
      minStock: minStock == null && nullToAbsent ? const Value.absent() : Value(minStock),
      active: Value(active),
    );
  }

  factory ProductRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      costCents: serializer.fromJson<int>(json['costCents']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      iconId: serializer.fromJson<String>(json['iconId']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      stock: serializer.fromJson<double>(json['stock']),
      minStock: serializer.fromJson<double?>(json['minStock']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'priceCents': serializer.toJson<int>(priceCents),
      'costCents': serializer.toJson<int>(costCents),
      'barcode': serializer.toJson<String?>(barcode),
      'iconId': serializer.toJson<String>(iconId),
      'trackStock': serializer.toJson<bool>(trackStock),
      'stock': serializer.toJson<double>(stock),
      'minStock': serializer.toJson<double?>(minStock),
      'active': serializer.toJson<bool>(active),
    };
  }

  ProductRow copyWith({
    String? id,
    String? name,
    int? priceCents,
    int? costCents,
    Value<String?> barcode = const Value.absent(),
    String? iconId,
    bool? trackStock,
    double? stock,
    Value<double?> minStock = const Value.absent(),
    bool? active,
  }) => ProductRow(
    id: id ?? this.id,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    costCents: costCents ?? this.costCents,
    barcode: barcode.present ? barcode.value : this.barcode,
    iconId: iconId ?? this.iconId,
    trackStock: trackStock ?? this.trackStock,
    stock: stock ?? this.stock,
    minStock: minStock.present ? minStock.value : this.minStock,
    active: active ?? this.active,
  );
  ProductRow copyWithCompanion(ProductsTableCompanion data) {
    return ProductRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      priceCents: data.priceCents.present ? data.priceCents.value : this.priceCents,
      costCents: data.costCents.present ? data.costCents.value : this.costCents,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      iconId: data.iconId.present ? data.iconId.value : this.iconId,
      trackStock: data.trackStock.present ? data.trackStock.value : this.trackStock,
      stock: data.stock.present ? data.stock.value : this.stock,
      minStock: data.minStock.present ? data.minStock.value : this.minStock,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('costCents: $costCents, ')
          ..write('barcode: $barcode, ')
          ..write('iconId: $iconId, ')
          ..write('trackStock: $trackStock, ')
          ..write('stock: $stock, ')
          ..write('minStock: $minStock, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, priceCents, costCents, barcode, iconId, trackStock, stock, minStock, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.priceCents == this.priceCents &&
          other.costCents == this.costCents &&
          other.barcode == this.barcode &&
          other.iconId == this.iconId &&
          other.trackStock == this.trackStock &&
          other.stock == this.stock &&
          other.minStock == this.minStock &&
          other.active == this.active);
}

class ProductsTableCompanion extends UpdateCompanion<ProductRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> priceCents;
  final Value<int> costCents;
  final Value<String?> barcode;
  final Value<String> iconId;
  final Value<bool> trackStock;
  final Value<double> stock;
  final Value<double?> minStock;
  final Value<bool> active;
  final Value<int> rowid;
  const ProductsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.costCents = const Value.absent(),
    this.barcode = const Value.absent(),
    this.iconId = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.stock = const Value.absent(),
    this.minStock = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsTableCompanion.insert({
    required String id,
    required String name,
    required int priceCents,
    this.costCents = const Value.absent(),
    this.barcode = const Value.absent(),
    this.iconId = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.stock = const Value.absent(),
    this.minStock = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       priceCents = Value(priceCents);
  static Insertable<ProductRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? priceCents,
    Expression<int>? costCents,
    Expression<String>? barcode,
    Expression<String>? iconId,
    Expression<bool>? trackStock,
    Expression<double>? stock,
    Expression<double>? minStock,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (priceCents != null) 'price_cents': priceCents,
      if (costCents != null) 'cost_cents': costCents,
      if (barcode != null) 'barcode': barcode,
      if (iconId != null) 'icon_id': iconId,
      if (trackStock != null) 'track_stock': trackStock,
      if (stock != null) 'stock': stock,
      if (minStock != null) 'min_stock': minStock,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? priceCents,
    Value<int>? costCents,
    Value<String?>? barcode,
    Value<String>? iconId,
    Value<bool>? trackStock,
    Value<double>? stock,
    Value<double?>? minStock,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return ProductsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      costCents: costCents ?? this.costCents,
      barcode: barcode ?? this.barcode,
      iconId: iconId ?? this.iconId,
      trackStock: trackStock ?? this.trackStock,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (costCents.present) {
      map['cost_cents'] = Variable<int>(costCents.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (iconId.present) {
      map['icon_id'] = Variable<String>(iconId.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (stock.present) {
      map['stock'] = Variable<double>(stock.value);
    }
    if (minStock.present) {
      map['min_stock'] = Variable<double>(minStock.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('costCents: $costCents, ')
          ..write('barcode: $barcode, ')
          ..write('iconId: $iconId, ')
          ..write('trackStock: $trackStock, ')
          ..write('stock: $stock, ')
          ..write('minStock: $minStock, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTableTable extends CustomersTable with TableInfo<$CustomersTableTable, CustomerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, phone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(Insertable<CustomerRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(_phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}phone']),
    );
  }

  @override
  $CustomersTableTable createAlias(String alias) {
    return $CustomersTableTable(attachedDatabase, alias);
  }
}

class CustomerRow extends DataClass implements Insertable<CustomerRow> {
  final String id;
  final String name;
  final String? phone;
  const CustomerRow({required this.id, required this.name, this.phone});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    return map;
  }

  CustomersTableCompanion toCompanion(bool nullToAbsent) {
    return CustomersTableCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent ? const Value.absent() : Value(phone),
    );
  }

  factory CustomerRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
    };
  }

  CustomerRow copyWith({String? id, String? name, Value<String?> phone = const Value.absent()}) =>
      CustomerRow(id: id ?? this.id, name: name ?? this.name, phone: phone.present ? phone.value : this.phone);
  CustomerRow copyWithCompanion(CustomersTableCompanion data) {
    return CustomerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerRow && other.id == this.id && other.name == this.name && other.phone == this.phone);
}

class CustomersTableCompanion extends UpdateCompanion<CustomerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<int> rowid;
  const CustomersTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersTableCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CustomerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersTableCompanion copyWith({Value<String>? id, Value<String>? name, Value<String?>? phone, Value<int>? rowid}) {
    return CustomersTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTableTable extends SalesTable with TableInfo<$SalesTableTable, SaleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folioMeta = const VerificationMeta('folio');
  @override
  late final GeneratedColumn<int> folio = GeneratedColumn<int>(
    'folio',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SaleKind, String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<SaleKind>($SalesTableTable.$converterkind);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayMethod?, String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<PayMethod?>($SalesTableTable.$convertermethodn);
  static const VerificationMeta _receivedCentsMeta = const VerificationMeta('receivedCents');
  @override
  late final GeneratedColumn<int> receivedCents = GeneratedColumn<int>(
    'received_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, folio, createdAt, kind, sessionId, method, receivedCents, customerId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<SaleRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('folio')) {
      context.handle(_folioMeta, folio.isAcceptableOrUnknown(data['folio']!, _folioMeta));
    } else if (isInserting) {
      context.missing(_folioMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('received_cents')) {
      context.handle(
        _receivedCentsMeta,
        receivedCents.isAcceptableOrUnknown(data['received_cents']!, _receivedCentsMeta),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(_customerIdMeta, customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      folio: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}folio'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      kind: $SalesTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ),
      sessionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      method: $SalesTableTable.$convertermethodn.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}method']),
      ),
      receivedCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}received_cents']),
      customerId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}customer_id']),
    );
  }

  @override
  $SalesTableTable createAlias(String alias) {
    return $SalesTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SaleKind, String, String> $converterkind = const EnumNameConverter<SaleKind>(
    SaleKind.values,
  );
  static JsonTypeConverter2<PayMethod, String, String> $convertermethod = const EnumNameConverter<PayMethod>(
    PayMethod.values,
  );
  static JsonTypeConverter2<PayMethod?, String?, String?> $convertermethodn = JsonTypeConverter2.asNullable(
    $convertermethod,
  );
}

class SaleRow extends DataClass implements Insertable<SaleRow> {
  final String id;
  final int folio;
  final DateTime createdAt;
  final SaleKind kind;
  final String? sessionId;
  final PayMethod? method;
  final int? receivedCents;
  final String? customerId;
  const SaleRow({
    required this.id,
    required this.folio,
    required this.createdAt,
    required this.kind,
    this.sessionId,
    this.method,
    this.receivedCents,
    this.customerId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['folio'] = Variable<int>(folio);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['kind'] = Variable<String>($SalesTableTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>($SalesTableTable.$convertermethodn.toSql(method));
    }
    if (!nullToAbsent || receivedCents != null) {
      map['received_cents'] = Variable<int>(receivedCents);
    }
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    return map;
  }

  SalesTableCompanion toCompanion(bool nullToAbsent) {
    return SalesTableCompanion(
      id: Value(id),
      folio: Value(folio),
      createdAt: Value(createdAt),
      kind: Value(kind),
      sessionId: sessionId == null && nullToAbsent ? const Value.absent() : Value(sessionId),
      method: method == null && nullToAbsent ? const Value.absent() : Value(method),
      receivedCents: receivedCents == null && nullToAbsent ? const Value.absent() : Value(receivedCents),
      customerId: customerId == null && nullToAbsent ? const Value.absent() : Value(customerId),
    );
  }

  factory SaleRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleRow(
      id: serializer.fromJson<String>(json['id']),
      folio: serializer.fromJson<int>(json['folio']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      kind: $SalesTableTable.$converterkind.fromJson(serializer.fromJson<String>(json['kind'])),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      method: $SalesTableTable.$convertermethodn.fromJson(serializer.fromJson<String?>(json['method'])),
      receivedCents: serializer.fromJson<int?>(json['receivedCents']),
      customerId: serializer.fromJson<String?>(json['customerId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'folio': serializer.toJson<int>(folio),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'kind': serializer.toJson<String>($SalesTableTable.$converterkind.toJson(kind)),
      'sessionId': serializer.toJson<String?>(sessionId),
      'method': serializer.toJson<String?>($SalesTableTable.$convertermethodn.toJson(method)),
      'receivedCents': serializer.toJson<int?>(receivedCents),
      'customerId': serializer.toJson<String?>(customerId),
    };
  }

  SaleRow copyWith({
    String? id,
    int? folio,
    DateTime? createdAt,
    SaleKind? kind,
    Value<String?> sessionId = const Value.absent(),
    Value<PayMethod?> method = const Value.absent(),
    Value<int?> receivedCents = const Value.absent(),
    Value<String?> customerId = const Value.absent(),
  }) => SaleRow(
    id: id ?? this.id,
    folio: folio ?? this.folio,
    createdAt: createdAt ?? this.createdAt,
    kind: kind ?? this.kind,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    method: method.present ? method.value : this.method,
    receivedCents: receivedCents.present ? receivedCents.value : this.receivedCents,
    customerId: customerId.present ? customerId.value : this.customerId,
  );
  SaleRow copyWithCompanion(SalesTableCompanion data) {
    return SaleRow(
      id: data.id.present ? data.id.value : this.id,
      folio: data.folio.present ? data.folio.value : this.folio,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      method: data.method.present ? data.method.value : this.method,
      receivedCents: data.receivedCents.present ? data.receivedCents.value : this.receivedCents,
      customerId: data.customerId.present ? data.customerId.value : this.customerId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleRow(')
          ..write('id: $id, ')
          ..write('folio: $folio, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('sessionId: $sessionId, ')
          ..write('method: $method, ')
          ..write('receivedCents: $receivedCents, ')
          ..write('customerId: $customerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, folio, createdAt, kind, sessionId, method, receivedCents, customerId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleRow &&
          other.id == this.id &&
          other.folio == this.folio &&
          other.createdAt == this.createdAt &&
          other.kind == this.kind &&
          other.sessionId == this.sessionId &&
          other.method == this.method &&
          other.receivedCents == this.receivedCents &&
          other.customerId == this.customerId);
}

class SalesTableCompanion extends UpdateCompanion<SaleRow> {
  final Value<String> id;
  final Value<int> folio;
  final Value<DateTime> createdAt;
  final Value<SaleKind> kind;
  final Value<String?> sessionId;
  final Value<PayMethod?> method;
  final Value<int?> receivedCents;
  final Value<String?> customerId;
  final Value<int> rowid;
  const SalesTableCompanion({
    this.id = const Value.absent(),
    this.folio = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.method = const Value.absent(),
    this.receivedCents = const Value.absent(),
    this.customerId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesTableCompanion.insert({
    required String id,
    required int folio,
    required DateTime createdAt,
    required SaleKind kind,
    this.sessionId = const Value.absent(),
    this.method = const Value.absent(),
    this.receivedCents = const Value.absent(),
    this.customerId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       folio = Value(folio),
       createdAt = Value(createdAt),
       kind = Value(kind);
  static Insertable<SaleRow> custom({
    Expression<String>? id,
    Expression<int>? folio,
    Expression<DateTime>? createdAt,
    Expression<String>? kind,
    Expression<String>? sessionId,
    Expression<String>? method,
    Expression<int>? receivedCents,
    Expression<String>? customerId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folio != null) 'folio': folio,
      if (createdAt != null) 'created_at': createdAt,
      if (kind != null) 'kind': kind,
      if (sessionId != null) 'session_id': sessionId,
      if (method != null) 'method': method,
      if (receivedCents != null) 'received_cents': receivedCents,
      if (customerId != null) 'customer_id': customerId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesTableCompanion copyWith({
    Value<String>? id,
    Value<int>? folio,
    Value<DateTime>? createdAt,
    Value<SaleKind>? kind,
    Value<String?>? sessionId,
    Value<PayMethod?>? method,
    Value<int?>? receivedCents,
    Value<String?>? customerId,
    Value<int>? rowid,
  }) {
    return SalesTableCompanion(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      sessionId: sessionId ?? this.sessionId,
      method: method ?? this.method,
      receivedCents: receivedCents ?? this.receivedCents,
      customerId: customerId ?? this.customerId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (folio.present) {
      map['folio'] = Variable<int>(folio.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>($SalesTableTable.$converterkind.toSql(kind.value));
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>($SalesTableTable.$convertermethodn.toSql(method.value));
    }
    if (receivedCents.present) {
      map['received_cents'] = Variable<int>(receivedCents.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesTableCompanion(')
          ..write('id: $id, ')
          ..write('folio: $folio, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('sessionId: $sessionId, ')
          ..write('method: $method, ')
          ..write('receivedCents: $receivedCents, ')
          ..write('customerId: $customerId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SaleLinesTableTable extends SaleLinesTable with TableInfo<$SaleLinesTableTable, SaleLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleLinesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineKeyMeta = const VerificationMeta('lineKey');
  @override
  late final GeneratedColumn<String> lineKey = GeneratedColumn<String>(
    'line_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCentsMeta = const VerificationMeta('unitCents');
  @override
  late final GeneratedColumn<int> unitCents = GeneratedColumn<int>(
    'unit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCostCentsMeta = const VerificationMeta('unitCostCents');
  @override
  late final GeneratedColumn<int> unitCostCents = GeneratedColumn<int>(
    'unit_cost_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [saleId, position, lineKey, productId, name, unitCents, unitCostCents, qty];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  VerificationContext validateIntegrity(Insertable<SaleLineRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sale_id')) {
      context.handle(_saleIdMeta, saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta));
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('line_key')) {
      context.handle(_lineKeyMeta, lineKey.isAcceptableOrUnknown(data['line_key']!, _lineKeyMeta));
    } else if (isInserting) {
      context.missing(_lineKeyMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta, productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit_cents')) {
      context.handle(_unitCentsMeta, unitCents.isAcceptableOrUnknown(data['unit_cents']!, _unitCentsMeta));
    } else if (isInserting) {
      context.missing(_unitCentsMeta);
    }
    if (data.containsKey('unit_cost_cents')) {
      context.handle(
        _unitCostCentsMeta,
        unitCostCents.isAcceptableOrUnknown(data['unit_cost_cents']!, _unitCostCentsMeta),
      );
    }
    if (data.containsKey('qty')) {
      context.handle(_qtyMeta, qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta));
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {saleId, position};
  @override
  SaleLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleLineRow(
      saleId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}sale_id'])!,
      position: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      lineKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}line_key'])!,
      productId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}product_id']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      unitCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}unit_cents'])!,
      unitCostCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}unit_cost_cents'])!,
      qty: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}qty'])!,
    );
  }

  @override
  $SaleLinesTableTable createAlias(String alias) {
    return $SaleLinesTableTable(attachedDatabase, alias);
  }
}

class SaleLineRow extends DataClass implements Insertable<SaleLineRow> {
  final String saleId;
  final int position;
  final String lineKey;
  final String? productId;
  final String name;
  final int unitCents;
  final int unitCostCents;
  final double qty;
  const SaleLineRow({
    required this.saleId,
    required this.position,
    required this.lineKey,
    this.productId,
    required this.name,
    required this.unitCents,
    required this.unitCostCents,
    required this.qty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sale_id'] = Variable<String>(saleId);
    map['position'] = Variable<int>(position);
    map['line_key'] = Variable<String>(lineKey);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['name'] = Variable<String>(name);
    map['unit_cents'] = Variable<int>(unitCents);
    map['unit_cost_cents'] = Variable<int>(unitCostCents);
    map['qty'] = Variable<double>(qty);
    return map;
  }

  SaleLinesTableCompanion toCompanion(bool nullToAbsent) {
    return SaleLinesTableCompanion(
      saleId: Value(saleId),
      position: Value(position),
      lineKey: Value(lineKey),
      productId: productId == null && nullToAbsent ? const Value.absent() : Value(productId),
      name: Value(name),
      unitCents: Value(unitCents),
      unitCostCents: Value(unitCostCents),
      qty: Value(qty),
    );
  }

  factory SaleLineRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleLineRow(
      saleId: serializer.fromJson<String>(json['saleId']),
      position: serializer.fromJson<int>(json['position']),
      lineKey: serializer.fromJson<String>(json['lineKey']),
      productId: serializer.fromJson<String?>(json['productId']),
      name: serializer.fromJson<String>(json['name']),
      unitCents: serializer.fromJson<int>(json['unitCents']),
      unitCostCents: serializer.fromJson<int>(json['unitCostCents']),
      qty: serializer.fromJson<double>(json['qty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'saleId': serializer.toJson<String>(saleId),
      'position': serializer.toJson<int>(position),
      'lineKey': serializer.toJson<String>(lineKey),
      'productId': serializer.toJson<String?>(productId),
      'name': serializer.toJson<String>(name),
      'unitCents': serializer.toJson<int>(unitCents),
      'unitCostCents': serializer.toJson<int>(unitCostCents),
      'qty': serializer.toJson<double>(qty),
    };
  }

  SaleLineRow copyWith({
    String? saleId,
    int? position,
    String? lineKey,
    Value<String?> productId = const Value.absent(),
    String? name,
    int? unitCents,
    int? unitCostCents,
    double? qty,
  }) => SaleLineRow(
    saleId: saleId ?? this.saleId,
    position: position ?? this.position,
    lineKey: lineKey ?? this.lineKey,
    productId: productId.present ? productId.value : this.productId,
    name: name ?? this.name,
    unitCents: unitCents ?? this.unitCents,
    unitCostCents: unitCostCents ?? this.unitCostCents,
    qty: qty ?? this.qty,
  );
  SaleLineRow copyWithCompanion(SaleLinesTableCompanion data) {
    return SaleLineRow(
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      position: data.position.present ? data.position.value : this.position,
      lineKey: data.lineKey.present ? data.lineKey.value : this.lineKey,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      unitCents: data.unitCents.present ? data.unitCents.value : this.unitCents,
      unitCostCents: data.unitCostCents.present ? data.unitCostCents.value : this.unitCostCents,
      qty: data.qty.present ? data.qty.value : this.qty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleLineRow(')
          ..write('saleId: $saleId, ')
          ..write('position: $position, ')
          ..write('lineKey: $lineKey, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unitCents: $unitCents, ')
          ..write('unitCostCents: $unitCostCents, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(saleId, position, lineKey, productId, name, unitCents, unitCostCents, qty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleLineRow &&
          other.saleId == this.saleId &&
          other.position == this.position &&
          other.lineKey == this.lineKey &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.unitCents == this.unitCents &&
          other.unitCostCents == this.unitCostCents &&
          other.qty == this.qty);
}

class SaleLinesTableCompanion extends UpdateCompanion<SaleLineRow> {
  final Value<String> saleId;
  final Value<int> position;
  final Value<String> lineKey;
  final Value<String?> productId;
  final Value<String> name;
  final Value<int> unitCents;
  final Value<int> unitCostCents;
  final Value<double> qty;
  final Value<int> rowid;
  const SaleLinesTableCompanion({
    this.saleId = const Value.absent(),
    this.position = const Value.absent(),
    this.lineKey = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.unitCents = const Value.absent(),
    this.unitCostCents = const Value.absent(),
    this.qty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleLinesTableCompanion.insert({
    required String saleId,
    required int position,
    required String lineKey,
    this.productId = const Value.absent(),
    required String name,
    required int unitCents,
    this.unitCostCents = const Value.absent(),
    required double qty,
    this.rowid = const Value.absent(),
  }) : saleId = Value(saleId),
       position = Value(position),
       lineKey = Value(lineKey),
       name = Value(name),
       unitCents = Value(unitCents),
       qty = Value(qty);
  static Insertable<SaleLineRow> custom({
    Expression<String>? saleId,
    Expression<int>? position,
    Expression<String>? lineKey,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<int>? unitCents,
    Expression<int>? unitCostCents,
    Expression<double>? qty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (saleId != null) 'sale_id': saleId,
      if (position != null) 'position': position,
      if (lineKey != null) 'line_key': lineKey,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (unitCents != null) 'unit_cents': unitCents,
      if (unitCostCents != null) 'unit_cost_cents': unitCostCents,
      if (qty != null) 'qty': qty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleLinesTableCompanion copyWith({
    Value<String>? saleId,
    Value<int>? position,
    Value<String>? lineKey,
    Value<String?>? productId,
    Value<String>? name,
    Value<int>? unitCents,
    Value<int>? unitCostCents,
    Value<double>? qty,
    Value<int>? rowid,
  }) {
    return SaleLinesTableCompanion(
      saleId: saleId ?? this.saleId,
      position: position ?? this.position,
      lineKey: lineKey ?? this.lineKey,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      unitCents: unitCents ?? this.unitCents,
      unitCostCents: unitCostCents ?? this.unitCostCents,
      qty: qty ?? this.qty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (lineKey.present) {
      map['line_key'] = Variable<String>(lineKey.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unitCents.present) {
      map['unit_cents'] = Variable<int>(unitCents.value);
    }
    if (unitCostCents.present) {
      map['unit_cost_cents'] = Variable<int>(unitCostCents.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleLinesTableCompanion(')
          ..write('saleId: $saleId, ')
          ..write('position: $position, ')
          ..write('lineKey: $lineKey, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('unitCents: $unitCents, ')
          ..write('unitCostCents: $unitCostCents, ')
          ..write('qty: $qty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreditEntriesTableTable extends CreditEntriesTable with TableInfo<$CreditEntriesTableTable, CreditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreditEntriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CreditType, String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CreditType>($CreditEntriesTableTable.$convertertype);
  static const VerificationMeta _amountCentsMeta = const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayMethod?, String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<PayMethod?>($CreditEntriesTableTable.$convertermethodn);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, customerId, type, amountCents, createdAt, saleId, method, sessionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'credit_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CreditRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(_customerIdMeta, customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta));
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(_amountCentsMeta, amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(_saleIdMeta, saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CreditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreditRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      customerId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}customer_id'])!,
      type: $CreditEntriesTableTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      ),
      amountCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      saleId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}sale_id']),
      method: $CreditEntriesTableTable.$convertermethodn.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}method']),
      ),
      sessionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}session_id']),
    );
  }

  @override
  $CreditEntriesTableTable createAlias(String alias) {
    return $CreditEntriesTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CreditType, String, String> $convertertype = const EnumNameConverter<CreditType>(
    CreditType.values,
  );
  static JsonTypeConverter2<PayMethod, String, String> $convertermethod = const EnumNameConverter<PayMethod>(
    PayMethod.values,
  );
  static JsonTypeConverter2<PayMethod?, String?, String?> $convertermethodn = JsonTypeConverter2.asNullable(
    $convertermethod,
  );
}

class CreditRow extends DataClass implements Insertable<CreditRow> {
  final String id;
  final String customerId;
  final CreditType type;
  final int amountCents;
  final DateTime createdAt;
  final String? saleId;
  final PayMethod? method;
  final String? sessionId;
  const CreditRow({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountCents,
    required this.createdAt,
    this.saleId,
    this.method,
    this.sessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    {
      map['type'] = Variable<String>($CreditEntriesTableTable.$convertertype.toSql(type));
    }
    map['amount_cents'] = Variable<int>(amountCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || saleId != null) {
      map['sale_id'] = Variable<String>(saleId);
    }
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>($CreditEntriesTableTable.$convertermethodn.toSql(method));
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    return map;
  }

  CreditEntriesTableCompanion toCompanion(bool nullToAbsent) {
    return CreditEntriesTableCompanion(
      id: Value(id),
      customerId: Value(customerId),
      type: Value(type),
      amountCents: Value(amountCents),
      createdAt: Value(createdAt),
      saleId: saleId == null && nullToAbsent ? const Value.absent() : Value(saleId),
      method: method == null && nullToAbsent ? const Value.absent() : Value(method),
      sessionId: sessionId == null && nullToAbsent ? const Value.absent() : Value(sessionId),
    );
  }

  factory CreditRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreditRow(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      type: $CreditEntriesTableTable.$convertertype.fromJson(serializer.fromJson<String>(json['type'])),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      saleId: serializer.fromJson<String?>(json['saleId']),
      method: $CreditEntriesTableTable.$convertermethodn.fromJson(serializer.fromJson<String?>(json['method'])),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'type': serializer.toJson<String>($CreditEntriesTableTable.$convertertype.toJson(type)),
      'amountCents': serializer.toJson<int>(amountCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'saleId': serializer.toJson<String?>(saleId),
      'method': serializer.toJson<String?>($CreditEntriesTableTable.$convertermethodn.toJson(method)),
      'sessionId': serializer.toJson<String?>(sessionId),
    };
  }

  CreditRow copyWith({
    String? id,
    String? customerId,
    CreditType? type,
    int? amountCents,
    DateTime? createdAt,
    Value<String?> saleId = const Value.absent(),
    Value<PayMethod?> method = const Value.absent(),
    Value<String?> sessionId = const Value.absent(),
  }) => CreditRow(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    createdAt: createdAt ?? this.createdAt,
    saleId: saleId.present ? saleId.value : this.saleId,
    method: method.present ? method.value : this.method,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
  );
  CreditRow copyWithCompanion(CreditEntriesTableCompanion data) {
    return CreditRow(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present ? data.customerId.value : this.customerId,
      type: data.type.present ? data.type.value : this.type,
      amountCents: data.amountCents.present ? data.amountCents.value : this.amountCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      method: data.method.present ? data.method.value : this.method,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreditRow(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, customerId, type, amountCents, createdAt, saleId, method, sessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreditRow &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.type == this.type &&
          other.amountCents == this.amountCents &&
          other.createdAt == this.createdAt &&
          other.saleId == this.saleId &&
          other.method == this.method &&
          other.sessionId == this.sessionId);
}

class CreditEntriesTableCompanion extends UpdateCompanion<CreditRow> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<CreditType> type;
  final Value<int> amountCents;
  final Value<DateTime> createdAt;
  final Value<String?> saleId;
  final Value<PayMethod?> method;
  final Value<String?> sessionId;
  final Value<int> rowid;
  const CreditEntriesTableCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.saleId = const Value.absent(),
    this.method = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CreditEntriesTableCompanion.insert({
    required String id,
    required String customerId,
    required CreditType type,
    required int amountCents,
    required DateTime createdAt,
    this.saleId = const Value.absent(),
    this.method = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       type = Value(type),
       amountCents = Value(amountCents),
       createdAt = Value(createdAt);
  static Insertable<CreditRow> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? type,
    Expression<int>? amountCents,
    Expression<DateTime>? createdAt,
    Expression<String>? saleId,
    Expression<String>? method,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (type != null) 'type': type,
      if (amountCents != null) 'amount_cents': amountCents,
      if (createdAt != null) 'created_at': createdAt,
      if (saleId != null) 'sale_id': saleId,
      if (method != null) 'method': method,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CreditEntriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<CreditType>? type,
    Value<int>? amountCents,
    Value<DateTime>? createdAt,
    Value<String?>? saleId,
    Value<PayMethod?>? method,
    Value<String?>? sessionId,
    Value<int>? rowid,
  }) {
    return CreditEntriesTableCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amountCents: amountCents ?? this.amountCents,
      createdAt: createdAt ?? this.createdAt,
      saleId: saleId ?? this.saleId,
      method: method ?? this.method,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>($CreditEntriesTableTable.$convertertype.toSql(type.value));
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>($CreditEntriesTableTable.$convertermethodn.toSql(method.value));
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreditEntriesTableCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('type: $type, ')
          ..write('amountCents: $amountCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('saleId: $saleId, ')
          ..write('method: $method, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CashSessionsTableTable extends CashSessionsTable with TableInfo<$CashSessionsTableTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta('openedAt');
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingCentsMeta = const VerificationMeta('openingCents');
  @override
  late final GeneratedColumn<int> openingCents = GeneratedColumn<int>(
    'opening_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta('closedAt');
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCentsMeta = const VerificationMeta('expectedCents');
  @override
  late final GeneratedColumn<int> expectedCents = GeneratedColumn<int>(
    'expected_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countedCentsMeta = const VerificationMeta('countedCents');
  @override
  late final GeneratedColumn<int> countedCents = GeneratedColumn<int>(
    'counted_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, openedAt, openingCents, closedAt, expectedCents, countedCents];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<SessionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(_openedAtMeta, openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta));
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('opening_cents')) {
      context.handle(_openingCentsMeta, openingCents.isAcceptableOrUnknown(data['opening_cents']!, _openingCentsMeta));
    } else if (isInserting) {
      context.missing(_openingCentsMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(_closedAtMeta, closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta));
    }
    if (data.containsKey('expected_cents')) {
      context.handle(
        _expectedCentsMeta,
        expectedCents.isAcceptableOrUnknown(data['expected_cents']!, _expectedCentsMeta),
      );
    }
    if (data.containsKey('counted_cents')) {
      context.handle(_countedCentsMeta, countedCents.isAcceptableOrUnknown(data['counted_cents']!, _countedCentsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      openedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}opened_at'])!,
      openingCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}opening_cents'])!,
      closedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}closed_at']),
      expectedCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}expected_cents']),
      countedCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}counted_cents']),
    );
  }

  @override
  $CashSessionsTableTable createAlias(String alias) {
    return $CashSessionsTableTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final DateTime openedAt;
  final int openingCents;
  final DateTime? closedAt;
  final int? expectedCents;
  final int? countedCents;
  const SessionRow({
    required this.id,
    required this.openedAt,
    required this.openingCents,
    this.closedAt,
    this.expectedCents,
    this.countedCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['opened_at'] = Variable<DateTime>(openedAt);
    map['opening_cents'] = Variable<int>(openingCents);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || expectedCents != null) {
      map['expected_cents'] = Variable<int>(expectedCents);
    }
    if (!nullToAbsent || countedCents != null) {
      map['counted_cents'] = Variable<int>(countedCents);
    }
    return map;
  }

  CashSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return CashSessionsTableCompanion(
      id: Value(id),
      openedAt: Value(openedAt),
      openingCents: Value(openingCents),
      closedAt: closedAt == null && nullToAbsent ? const Value.absent() : Value(closedAt),
      expectedCents: expectedCents == null && nullToAbsent ? const Value.absent() : Value(expectedCents),
      countedCents: countedCents == null && nullToAbsent ? const Value.absent() : Value(countedCents),
    );
  }

  factory SessionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      openingCents: serializer.fromJson<int>(json['openingCents']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      expectedCents: serializer.fromJson<int?>(json['expectedCents']),
      countedCents: serializer.fromJson<int?>(json['countedCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'openingCents': serializer.toJson<int>(openingCents),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'expectedCents': serializer.toJson<int?>(expectedCents),
      'countedCents': serializer.toJson<int?>(countedCents),
    };
  }

  SessionRow copyWith({
    String? id,
    DateTime? openedAt,
    int? openingCents,
    Value<DateTime?> closedAt = const Value.absent(),
    Value<int?> expectedCents = const Value.absent(),
    Value<int?> countedCents = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    openedAt: openedAt ?? this.openedAt,
    openingCents: openingCents ?? this.openingCents,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    expectedCents: expectedCents.present ? expectedCents.value : this.expectedCents,
    countedCents: countedCents.present ? countedCents.value : this.countedCents,
  );
  SessionRow copyWithCompanion(CashSessionsTableCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      openingCents: data.openingCents.present ? data.openingCents.value : this.openingCents,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      expectedCents: data.expectedCents.present ? data.expectedCents.value : this.expectedCents,
      countedCents: data.countedCents.present ? data.countedCents.value : this.countedCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('openedAt: $openedAt, ')
          ..write('openingCents: $openingCents, ')
          ..write('closedAt: $closedAt, ')
          ..write('expectedCents: $expectedCents, ')
          ..write('countedCents: $countedCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, openedAt, openingCents, closedAt, expectedCents, countedCents);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.openedAt == this.openedAt &&
          other.openingCents == this.openingCents &&
          other.closedAt == this.closedAt &&
          other.expectedCents == this.expectedCents &&
          other.countedCents == this.countedCents);
}

class CashSessionsTableCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<DateTime> openedAt;
  final Value<int> openingCents;
  final Value<DateTime?> closedAt;
  final Value<int?> expectedCents;
  final Value<int?> countedCents;
  final Value<int> rowid;
  const CashSessionsTableCompanion({
    this.id = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.openingCents = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.expectedCents = const Value.absent(),
    this.countedCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CashSessionsTableCompanion.insert({
    required String id,
    required DateTime openedAt,
    required int openingCents,
    this.closedAt = const Value.absent(),
    this.expectedCents = const Value.absent(),
    this.countedCents = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       openedAt = Value(openedAt),
       openingCents = Value(openingCents);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<DateTime>? openedAt,
    Expression<int>? openingCents,
    Expression<DateTime>? closedAt,
    Expression<int>? expectedCents,
    Expression<int>? countedCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (openedAt != null) 'opened_at': openedAt,
      if (openingCents != null) 'opening_cents': openingCents,
      if (closedAt != null) 'closed_at': closedAt,
      if (expectedCents != null) 'expected_cents': expectedCents,
      if (countedCents != null) 'counted_cents': countedCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CashSessionsTableCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? openedAt,
    Value<int>? openingCents,
    Value<DateTime?>? closedAt,
    Value<int?>? expectedCents,
    Value<int?>? countedCents,
    Value<int>? rowid,
  }) {
    return CashSessionsTableCompanion(
      id: id ?? this.id,
      openedAt: openedAt ?? this.openedAt,
      openingCents: openingCents ?? this.openingCents,
      closedAt: closedAt ?? this.closedAt,
      expectedCents: expectedCents ?? this.expectedCents,
      countedCents: countedCents ?? this.countedCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (openingCents.present) {
      map['opening_cents'] = Variable<int>(openingCents.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (expectedCents.present) {
      map['expected_cents'] = Variable<int>(expectedCents.value);
    }
    if (countedCents.present) {
      map['counted_cents'] = Variable<int>(countedCents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('openedAt: $openedAt, ')
          ..write('openingCents: $openingCents, ')
          ..write('closedAt: $closedAt, ')
          ..write('expectedCents: $expectedCents, ')
          ..write('countedCents: $countedCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CashMovementsTableTable extends CashMovementsTable with TableInfo<$CashMovementsTableTable, MovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashMovementsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CashKind, String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CashKind>($CashMovementsTableTable.$converterkind);
  static const VerificationMeta _amountCentsMeta = const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conceptMeta = const VerificationMeta('concept');
  @override
  late final GeneratedColumn<String> concept = GeneratedColumn<String>(
    'concept',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, kind, amountCents, concept, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_movements';
  @override
  VerificationContext validateIntegrity(Insertable<MovementRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(_amountCentsMeta, amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('concept')) {
      context.handle(_conceptMeta, concept.isAcceptableOrUnknown(data['concept']!, _conceptMeta));
    } else if (isInserting) {
      context.missing(_conceptMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MovementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovementRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      kind: $CashMovementsTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ),
      amountCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      concept: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}concept'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CashMovementsTableTable createAlias(String alias) {
    return $CashMovementsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CashKind, String, String> $converterkind = const EnumNameConverter<CashKind>(
    CashKind.values,
  );
}

class MovementRow extends DataClass implements Insertable<MovementRow> {
  final String id;
  final String sessionId;
  final CashKind kind;
  final int amountCents;
  final String concept;
  final DateTime createdAt;
  const MovementRow({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.amountCents,
    required this.concept,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    {
      map['kind'] = Variable<String>($CashMovementsTableTable.$converterkind.toSql(kind));
    }
    map['amount_cents'] = Variable<int>(amountCents);
    map['concept'] = Variable<String>(concept);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CashMovementsTableCompanion toCompanion(bool nullToAbsent) {
    return CashMovementsTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      kind: Value(kind),
      amountCents: Value(amountCents),
      concept: Value(concept),
      createdAt: Value(createdAt),
    );
  }

  factory MovementRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovementRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      kind: $CashMovementsTableTable.$converterkind.fromJson(serializer.fromJson<String>(json['kind'])),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      concept: serializer.fromJson<String>(json['concept']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'kind': serializer.toJson<String>($CashMovementsTableTable.$converterkind.toJson(kind)),
      'amountCents': serializer.toJson<int>(amountCents),
      'concept': serializer.toJson<String>(concept),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MovementRow copyWith({
    String? id,
    String? sessionId,
    CashKind? kind,
    int? amountCents,
    String? concept,
    DateTime? createdAt,
  }) => MovementRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    concept: concept ?? this.concept,
    createdAt: createdAt ?? this.createdAt,
  );
  MovementRow copyWithCompanion(CashMovementsTableCompanion data) {
    return MovementRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountCents: data.amountCents.present ? data.amountCents.value : this.amountCents,
      concept: data.concept.present ? data.concept.value : this.concept,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovementRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('concept: $concept, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, kind, amountCents, concept, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovementRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.amountCents == this.amountCents &&
          other.concept == this.concept &&
          other.createdAt == this.createdAt);
}

class CashMovementsTableCompanion extends UpdateCompanion<MovementRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<CashKind> kind;
  final Value<int> amountCents;
  final Value<String> concept;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CashMovementsTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.concept = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CashMovementsTableCompanion.insert({
    required String id,
    required String sessionId,
    required CashKind kind,
    required int amountCents,
    required String concept,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       kind = Value(kind),
       amountCents = Value(amountCents),
       concept = Value(concept),
       createdAt = Value(createdAt);
  static Insertable<MovementRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<int>? amountCents,
    Expression<String>? concept,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (amountCents != null) 'amount_cents': amountCents,
      if (concept != null) 'concept': concept,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CashMovementsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<CashKind>? kind,
    Value<int>? amountCents,
    Value<String>? concept,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CashMovementsTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      concept: concept ?? this.concept,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>($CashMovementsTableTable.$converterkind.toSql(kind.value));
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (concept.present) {
      map['concept'] = Variable<String>(concept.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementsTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('concept: $concept, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTableTable extends MetaTable with TableInfo<$MetaTableTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(Insertable<MetaRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $MetaTableTable createAlias(String alias) {
    return $MetaTableTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaTableCompanion toCompanion(bool nullToAbsent) {
    return MetaTableCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  MetaRow copyWith({String? key, String? value}) => MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaTableCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaTableCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaTableCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<MetaRow> custom({Expression<String>? key, Expression<String>? value, Expression<int>? rowid}) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaTableCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return MetaTableCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GavilanDb extends GeneratedDatabase {
  _$GavilanDb(QueryExecutor e) : super(e);
  $GavilanDbManager get managers => $GavilanDbManager(this);
  late final $OutboxTableTable outboxTable = $OutboxTableTable(this);
  late final $ProductsTableTable productsTable = $ProductsTableTable(this);
  late final $CustomersTableTable customersTable = $CustomersTableTable(this);
  late final $SalesTableTable salesTable = $SalesTableTable(this);
  late final $SaleLinesTableTable saleLinesTable = $SaleLinesTableTable(this);
  late final $CreditEntriesTableTable creditEntriesTable = $CreditEntriesTableTable(this);
  late final $CashSessionsTableTable cashSessionsTable = $CashSessionsTableTable(this);
  late final $CashMovementsTableTable cashMovementsTable = $CashMovementsTableTable(this);
  late final $MetaTableTable metaTable = $MetaTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outboxTable,
    productsTable,
    customersTable,
    salesTable,
    saleLinesTable,
    creditEntriesTable,
    cashSessionsTable,
    cashMovementsTable,
    metaTable,
  ];
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$OutboxTableTableCreateCompanionBuilder = OutboxTableCompanion Function({
  Value<int> id,
  required String payload,
  required DateTime createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});
typedef $$OutboxTableTableUpdateCompanionBuilder = OutboxTableCompanion Function({
  Value<int> id,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});

class $$OutboxTableTableFilterComposer extends Composer<_$GavilanDb, $OutboxTableTable> {
  $$OutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableTableOrderingComposer extends Composer<_$GavilanDb, $OutboxTableTable> {
  $$OutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableTableAnnotationComposer extends Composer<_$GavilanDb, $OutboxTableTable> {
  $$OutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload => $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts => $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError => $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $OutboxTableTable,
          OutboxRow,
          $$OutboxTableTableFilterComposer,
          $$OutboxTableTableOrderingComposer,
          $$OutboxTableTableAnnotationComposer,
          $$OutboxTableTableCreateCompanionBuilder,
          $$OutboxTableTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$GavilanDb, $OutboxTableTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableTableManager(_$GavilanDb db, $OutboxTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$OutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$OutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$OutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxTableCompanion(
                id: id,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String payload,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxTableCompanion.insert(
                id: id,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTableTable, OutboxRow>(table),
                  BaseReferences<_$GavilanDb, $OutboxTableTable, OutboxRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $OutboxTableTable,
      OutboxRow,
      $$OutboxTableTableFilterComposer,
      $$OutboxTableTableOrderingComposer,
      $$OutboxTableTableAnnotationComposer,
      $$OutboxTableTableCreateCompanionBuilder,
      $$OutboxTableTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$GavilanDb, $OutboxTableTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableTableCreateCompanionBuilder = ProductsTableCompanion Function({
  required String id,
  required String name,
  required int priceCents,
  Value<int> costCents,
  Value<String?> barcode,
  Value<String> iconId,
  Value<bool> trackStock,
  Value<double> stock,
  Value<double?> minStock,
  Value<bool> active,
  Value<int> rowid,
});
typedef $$ProductsTableTableUpdateCompanionBuilder = ProductsTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> priceCents,
  Value<int> costCents,
  Value<String?> barcode,
  Value<String> iconId,
  Value<bool> trackStock,
  Value<double> stock,
  Value<double?> minStock,
  Value<bool> active,
  Value<int> rowid,
});

class $$ProductsTableTableFilterComposer extends Composer<_$GavilanDb, $ProductsTableTable> {
  $$ProductsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceCents =>
      $composableBuilder(column: $table.priceCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconId =>
      $composableBuilder(column: $table.iconId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trackStock =>
      $composableBuilder(column: $table.trackStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get minStock =>
      $composableBuilder(column: $table.minStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => ColumnFilters(column));
}

class $$ProductsTableTableOrderingComposer extends Composer<_$GavilanDb, $ProductsTableTable> {
  $$ProductsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceCents =>
      $composableBuilder(column: $table.priceCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconId =>
      $composableBuilder(column: $table.iconId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trackStock =>
      $composableBuilder(column: $table.trackStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get minStock =>
      $composableBuilder(column: $table.minStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => ColumnOrderings(column));
}

class $$ProductsTableTableAnnotationComposer extends Composer<_$GavilanDb, $ProductsTableTable> {
  $$ProductsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(column: $table.priceCents, builder: (column) => column);

  GeneratedColumn<int> get costCents => $composableBuilder(column: $table.costCents, builder: (column) => column);

  GeneratedColumn<String> get barcode => $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get iconId => $composableBuilder(column: $table.iconId, builder: (column) => column);

  GeneratedColumn<bool> get trackStock => $composableBuilder(column: $table.trackStock, builder: (column) => column);

  GeneratedColumn<double> get stock => $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<double> get minStock => $composableBuilder(column: $table.minStock, builder: (column) => column);

  GeneratedColumn<bool> get active => $composableBuilder(column: $table.active, builder: (column) => column);
}

class $$ProductsTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $ProductsTableTable,
          ProductRow,
          $$ProductsTableTableFilterComposer,
          $$ProductsTableTableOrderingComposer,
          $$ProductsTableTableAnnotationComposer,
          $$ProductsTableTableCreateCompanionBuilder,
          $$ProductsTableTableUpdateCompanionBuilder,
          (ProductRow, BaseReferences<_$GavilanDb, $ProductsTableTable, ProductRow>),
          ProductRow,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableTableManager(_$GavilanDb db, $ProductsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ProductsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ProductsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ProductsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> priceCents = const Value.absent(),
                Value<int> costCents = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> iconId = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double> stock = const Value.absent(),
                Value<double?> minStock = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsTableCompanion(
                id: id,
                name: name,
                priceCents: priceCents,
                costCents: costCents,
                barcode: barcode,
                iconId: iconId,
                trackStock: trackStock,
                stock: stock,
                minStock: minStock,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int priceCents,
                Value<int> costCents = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> iconId = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double> stock = const Value.absent(),
                Value<double?> minStock = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsTableCompanion.insert(
                id: id,
                name: name,
                priceCents: priceCents,
                costCents: costCents,
                barcode: barcode,
                iconId: iconId,
                trackStock: trackStock,
                stock: stock,
                minStock: minStock,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductsTableTable, ProductRow>(table),
                  BaseReferences<_$GavilanDb, $ProductsTableTable, ProductRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $ProductsTableTable,
      ProductRow,
      $$ProductsTableTableFilterComposer,
      $$ProductsTableTableOrderingComposer,
      $$ProductsTableTableAnnotationComposer,
      $$ProductsTableTableCreateCompanionBuilder,
      $$ProductsTableTableUpdateCompanionBuilder,
      (ProductRow, BaseReferences<_$GavilanDb, $ProductsTableTable, ProductRow>),
      ProductRow,
      PrefetchHooks Function()
    >;
typedef $$CustomersTableTableCreateCompanionBuilder = CustomersTableCompanion Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<int> rowid,
});
typedef $$CustomersTableTableUpdateCompanionBuilder = CustomersTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<int> rowid,
});

class $$CustomersTableTableFilterComposer extends Composer<_$GavilanDb, $CustomersTableTable> {
  $$CustomersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => ColumnFilters(column));
}

class $$CustomersTableTableOrderingComposer extends Composer<_$GavilanDb, $CustomersTableTable> {
  $$CustomersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => ColumnOrderings(column));
}

class $$CustomersTableTableAnnotationComposer extends Composer<_$GavilanDb, $CustomersTableTable> {
  $$CustomersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone => $composableBuilder(column: $table.phone, builder: (column) => column);
}

class $$CustomersTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $CustomersTableTable,
          CustomerRow,
          $$CustomersTableTableFilterComposer,
          $$CustomersTableTableOrderingComposer,
          $$CustomersTableTableAnnotationComposer,
          $$CustomersTableTableCreateCompanionBuilder,
          $$CustomersTableTableUpdateCompanionBuilder,
          (CustomerRow, BaseReferences<_$GavilanDb, $CustomersTableTable, CustomerRow>),
          CustomerRow,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableTableManager(_$GavilanDb db, $CustomersTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CustomersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CustomersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CustomersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CustomersTableCompanion(id: id, name: name, phone: phone, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> phone = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CustomersTableCompanion.insert(id: id, name: name, phone: phone, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomersTableTable, CustomerRow>(table),
                  BaseReferences<_$GavilanDb, $CustomersTableTable, CustomerRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $CustomersTableTable,
      CustomerRow,
      $$CustomersTableTableFilterComposer,
      $$CustomersTableTableOrderingComposer,
      $$CustomersTableTableAnnotationComposer,
      $$CustomersTableTableCreateCompanionBuilder,
      $$CustomersTableTableUpdateCompanionBuilder,
      (CustomerRow, BaseReferences<_$GavilanDb, $CustomersTableTable, CustomerRow>),
      CustomerRow,
      PrefetchHooks Function()
    >;
typedef $$SalesTableTableCreateCompanionBuilder = SalesTableCompanion Function({
  required String id,
  required int folio,
  required DateTime createdAt,
  required SaleKind kind,
  Value<String?> sessionId,
  Value<PayMethod?> method,
  Value<int?> receivedCents,
  Value<String?> customerId,
  Value<int> rowid,
});
typedef $$SalesTableTableUpdateCompanionBuilder = SalesTableCompanion Function({
  Value<String> id,
  Value<int> folio,
  Value<DateTime> createdAt,
  Value<SaleKind> kind,
  Value<String?> sessionId,
  Value<PayMethod?> method,
  Value<int?> receivedCents,
  Value<String?> customerId,
  Value<int> rowid,
});

class $$SalesTableTableFilterComposer extends Composer<_$GavilanDb, $SalesTableTable> {
  $$SalesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get folio => $composableBuilder(column: $table.folio, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SaleKind, SaleKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PayMethod?, PayMethod, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get receivedCents =>
      $composableBuilder(column: $table.receivedCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId =>
      $composableBuilder(column: $table.customerId, builder: (column) => ColumnFilters(column));
}

class $$SalesTableTableOrderingComposer extends Composer<_$GavilanDb, $SalesTableTable> {
  $$SalesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get folio =>
      $composableBuilder(column: $table.folio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get receivedCents =>
      $composableBuilder(column: $table.receivedCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId =>
      $composableBuilder(column: $table.customerId, builder: (column) => ColumnOrderings(column));
}

class $$SalesTableTableAnnotationComposer extends Composer<_$GavilanDb, $SalesTableTable> {
  $$SalesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get folio => $composableBuilder(column: $table.folio, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SaleKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sessionId => $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PayMethod?, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get receivedCents =>
      $composableBuilder(column: $table.receivedCents, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(column: $table.customerId, builder: (column) => column);
}

class $$SalesTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $SalesTableTable,
          SaleRow,
          $$SalesTableTableFilterComposer,
          $$SalesTableTableOrderingComposer,
          $$SalesTableTableAnnotationComposer,
          $$SalesTableTableCreateCompanionBuilder,
          $$SalesTableTableUpdateCompanionBuilder,
          (SaleRow, BaseReferences<_$GavilanDb, $SalesTableTable, SaleRow>),
          SaleRow,
          PrefetchHooks Function()
        > {
  $$SalesTableTableTableManager(_$GavilanDb db, $SalesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SalesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SalesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SalesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> folio = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<SaleKind> kind = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<PayMethod?> method = const Value.absent(),
                Value<int?> receivedCents = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesTableCompanion(
                id: id,
                folio: folio,
                createdAt: createdAt,
                kind: kind,
                sessionId: sessionId,
                method: method,
                receivedCents: receivedCents,
                customerId: customerId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int folio,
                required DateTime createdAt,
                required SaleKind kind,
                Value<String?> sessionId = const Value.absent(),
                Value<PayMethod?> method = const Value.absent(),
                Value<int?> receivedCents = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesTableCompanion.insert(
                id: id,
                folio: folio,
                createdAt: createdAt,
                kind: kind,
                sessionId: sessionId,
                method: method,
                receivedCents: receivedCents,
                customerId: customerId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SalesTableTable, SaleRow>(table),
                  BaseReferences<_$GavilanDb, $SalesTableTable, SaleRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $SalesTableTable,
      SaleRow,
      $$SalesTableTableFilterComposer,
      $$SalesTableTableOrderingComposer,
      $$SalesTableTableAnnotationComposer,
      $$SalesTableTableCreateCompanionBuilder,
      $$SalesTableTableUpdateCompanionBuilder,
      (SaleRow, BaseReferences<_$GavilanDb, $SalesTableTable, SaleRow>),
      SaleRow,
      PrefetchHooks Function()
    >;
typedef $$SaleLinesTableTableCreateCompanionBuilder = SaleLinesTableCompanion Function({
  required String saleId,
  required int position,
  required String lineKey,
  Value<String?> productId,
  required String name,
  required int unitCents,
  Value<int> unitCostCents,
  required double qty,
  Value<int> rowid,
});
typedef $$SaleLinesTableTableUpdateCompanionBuilder = SaleLinesTableCompanion Function({
  Value<String> saleId,
  Value<int> position,
  Value<String> lineKey,
  Value<String?> productId,
  Value<String> name,
  Value<int> unitCents,
  Value<int> unitCostCents,
  Value<double> qty,
  Value<int> rowid,
});

class $$SaleLinesTableTableFilterComposer extends Composer<_$GavilanDb, $SaleLinesTableTable> {
  $$SaleLinesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineKey =>
      $composableBuilder(column: $table.lineKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitCents =>
      $composableBuilder(column: $table.unitCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitCostCents =>
      $composableBuilder(column: $table.unitCostCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qty => $composableBuilder(column: $table.qty, builder: (column) => ColumnFilters(column));
}

class $$SaleLinesTableTableOrderingComposer extends Composer<_$GavilanDb, $SaleLinesTableTable> {
  $$SaleLinesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineKey =>
      $composableBuilder(column: $table.lineKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitCents =>
      $composableBuilder(column: $table.unitCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitCostCents =>
      $composableBuilder(column: $table.unitCostCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => ColumnOrderings(column));
}

class $$SaleLinesTableTableAnnotationComposer extends Composer<_$GavilanDb, $SaleLinesTableTable> {
  $$SaleLinesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get saleId => $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<int> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get lineKey => $composableBuilder(column: $table.lineKey, builder: (column) => column);

  GeneratedColumn<String> get productId => $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get unitCents => $composableBuilder(column: $table.unitCents, builder: (column) => column);

  GeneratedColumn<int> get unitCostCents =>
      $composableBuilder(column: $table.unitCostCents, builder: (column) => column);

  GeneratedColumn<double> get qty => $composableBuilder(column: $table.qty, builder: (column) => column);
}

class $$SaleLinesTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $SaleLinesTableTable,
          SaleLineRow,
          $$SaleLinesTableTableFilterComposer,
          $$SaleLinesTableTableOrderingComposer,
          $$SaleLinesTableTableAnnotationComposer,
          $$SaleLinesTableTableCreateCompanionBuilder,
          $$SaleLinesTableTableUpdateCompanionBuilder,
          (SaleLineRow, BaseReferences<_$GavilanDb, $SaleLinesTableTable, SaleLineRow>),
          SaleLineRow,
          PrefetchHooks Function()
        > {
  $$SaleLinesTableTableTableManager(_$GavilanDb db, $SaleLinesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SaleLinesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SaleLinesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SaleLinesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> saleId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> lineKey = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> unitCents = const Value.absent(),
                Value<int> unitCostCents = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SaleLinesTableCompanion(
                saleId: saleId,
                position: position,
                lineKey: lineKey,
                productId: productId,
                name: name,
                unitCents: unitCents,
                unitCostCents: unitCostCents,
                qty: qty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String saleId,
                required int position,
                required String lineKey,
                Value<String?> productId = const Value.absent(),
                required String name,
                required int unitCents,
                Value<int> unitCostCents = const Value.absent(),
                required double qty,
                Value<int> rowid = const Value.absent(),
              }) => SaleLinesTableCompanion.insert(
                saleId: saleId,
                position: position,
                lineKey: lineKey,
                productId: productId,
                name: name,
                unitCents: unitCents,
                unitCostCents: unitCostCents,
                qty: qty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SaleLinesTableTable, SaleLineRow>(table),
                  BaseReferences<_$GavilanDb, $SaleLinesTableTable, SaleLineRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SaleLinesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $SaleLinesTableTable,
      SaleLineRow,
      $$SaleLinesTableTableFilterComposer,
      $$SaleLinesTableTableOrderingComposer,
      $$SaleLinesTableTableAnnotationComposer,
      $$SaleLinesTableTableCreateCompanionBuilder,
      $$SaleLinesTableTableUpdateCompanionBuilder,
      (SaleLineRow, BaseReferences<_$GavilanDb, $SaleLinesTableTable, SaleLineRow>),
      SaleLineRow,
      PrefetchHooks Function()
    >;
typedef $$CreditEntriesTableTableCreateCompanionBuilder = CreditEntriesTableCompanion Function({
  required String id,
  required String customerId,
  required CreditType type,
  required int amountCents,
  required DateTime createdAt,
  Value<String?> saleId,
  Value<PayMethod?> method,
  Value<String?> sessionId,
  Value<int> rowid,
});
typedef $$CreditEntriesTableTableUpdateCompanionBuilder = CreditEntriesTableCompanion Function({
  Value<String> id,
  Value<String> customerId,
  Value<CreditType> type,
  Value<int> amountCents,
  Value<DateTime> createdAt,
  Value<String?> saleId,
  Value<PayMethod?> method,
  Value<String?> sessionId,
  Value<int> rowid,
});

class $$CreditEntriesTableTableFilterComposer extends Composer<_$GavilanDb, $CreditEntriesTableTable> {
  $$CreditEntriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId =>
      $composableBuilder(column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CreditType, CreditType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PayMethod?, PayMethod, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));
}

class $$CreditEntriesTableTableOrderingComposer extends Composer<_$GavilanDb, $CreditEntriesTableTable> {
  $$CreditEntriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId =>
      $composableBuilder(column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));
}

class $$CreditEntriesTableTableAnnotationComposer extends Composer<_$GavilanDb, $CreditEntriesTableTable> {
  $$CreditEntriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(column: $table.customerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CreditType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get saleId => $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PayMethod?, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get sessionId => $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$CreditEntriesTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $CreditEntriesTableTable,
          CreditRow,
          $$CreditEntriesTableTableFilterComposer,
          $$CreditEntriesTableTableOrderingComposer,
          $$CreditEntriesTableTableAnnotationComposer,
          $$CreditEntriesTableTableCreateCompanionBuilder,
          $$CreditEntriesTableTableUpdateCompanionBuilder,
          (CreditRow, BaseReferences<_$GavilanDb, $CreditEntriesTableTable, CreditRow>),
          CreditRow,
          PrefetchHooks Function()
        > {
  $$CreditEntriesTableTableTableManager(_$GavilanDb db, $CreditEntriesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CreditEntriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CreditEntriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CreditEntriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<CreditType> type = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> saleId = const Value.absent(),
                Value<PayMethod?> method = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreditEntriesTableCompanion(
                id: id,
                customerId: customerId,
                type: type,
                amountCents: amountCents,
                createdAt: createdAt,
                saleId: saleId,
                method: method,
                sessionId: sessionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required CreditType type,
                required int amountCents,
                required DateTime createdAt,
                Value<String?> saleId = const Value.absent(),
                Value<PayMethod?> method = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreditEntriesTableCompanion.insert(
                id: id,
                customerId: customerId,
                type: type,
                amountCents: amountCents,
                createdAt: createdAt,
                saleId: saleId,
                method: method,
                sessionId: sessionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CreditEntriesTableTable, CreditRow>(table),
                  BaseReferences<_$GavilanDb, $CreditEntriesTableTable, CreditRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CreditEntriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $CreditEntriesTableTable,
      CreditRow,
      $$CreditEntriesTableTableFilterComposer,
      $$CreditEntriesTableTableOrderingComposer,
      $$CreditEntriesTableTableAnnotationComposer,
      $$CreditEntriesTableTableCreateCompanionBuilder,
      $$CreditEntriesTableTableUpdateCompanionBuilder,
      (CreditRow, BaseReferences<_$GavilanDb, $CreditEntriesTableTable, CreditRow>),
      CreditRow,
      PrefetchHooks Function()
    >;
typedef $$CashSessionsTableTableCreateCompanionBuilder = CashSessionsTableCompanion Function({
  required String id,
  required DateTime openedAt,
  required int openingCents,
  Value<DateTime?> closedAt,
  Value<int?> expectedCents,
  Value<int?> countedCents,
  Value<int> rowid,
});
typedef $$CashSessionsTableTableUpdateCompanionBuilder = CashSessionsTableCompanion Function({
  Value<String> id,
  Value<DateTime> openedAt,
  Value<int> openingCents,
  Value<DateTime?> closedAt,
  Value<int?> expectedCents,
  Value<int?> countedCents,
  Value<int> rowid,
});

class $$CashSessionsTableTableFilterComposer extends Composer<_$GavilanDb, $CashSessionsTableTable> {
  $$CashSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get openingCents =>
      $composableBuilder(column: $table.openingCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expectedCents =>
      $composableBuilder(column: $table.expectedCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get countedCents =>
      $composableBuilder(column: $table.countedCents, builder: (column) => ColumnFilters(column));
}

class $$CashSessionsTableTableOrderingComposer extends Composer<_$GavilanDb, $CashSessionsTableTable> {
  $$CashSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get openingCents =>
      $composableBuilder(column: $table.openingCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expectedCents =>
      $composableBuilder(column: $table.expectedCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get countedCents =>
      $composableBuilder(column: $table.countedCents, builder: (column) => ColumnOrderings(column));
}

class $$CashSessionsTableTableAnnotationComposer extends Composer<_$GavilanDb, $CashSessionsTableTable> {
  $$CashSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt => $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<int> get openingCents => $composableBuilder(column: $table.openingCents, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt => $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get expectedCents =>
      $composableBuilder(column: $table.expectedCents, builder: (column) => column);

  GeneratedColumn<int> get countedCents => $composableBuilder(column: $table.countedCents, builder: (column) => column);
}

class $$CashSessionsTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $CashSessionsTableTable,
          SessionRow,
          $$CashSessionsTableTableFilterComposer,
          $$CashSessionsTableTableOrderingComposer,
          $$CashSessionsTableTableAnnotationComposer,
          $$CashSessionsTableTableCreateCompanionBuilder,
          $$CashSessionsTableTableUpdateCompanionBuilder,
          (SessionRow, BaseReferences<_$GavilanDb, $CashSessionsTableTable, SessionRow>),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$CashSessionsTableTableTableManager(_$GavilanDb db, $CashSessionsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CashSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CashSessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CashSessionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<int> openingCents = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> expectedCents = const Value.absent(),
                Value<int?> countedCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CashSessionsTableCompanion(
                id: id,
                openedAt: openedAt,
                openingCents: openingCents,
                closedAt: closedAt,
                expectedCents: expectedCents,
                countedCents: countedCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime openedAt,
                required int openingCents,
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> expectedCents = const Value.absent(),
                Value<int?> countedCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CashSessionsTableCompanion.insert(
                id: id,
                openedAt: openedAt,
                openingCents: openingCents,
                closedAt: closedAt,
                expectedCents: expectedCents,
                countedCents: countedCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CashSessionsTableTable, SessionRow>(table),
                  BaseReferences<_$GavilanDb, $CashSessionsTableTable, SessionRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CashSessionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $CashSessionsTableTable,
      SessionRow,
      $$CashSessionsTableTableFilterComposer,
      $$CashSessionsTableTableOrderingComposer,
      $$CashSessionsTableTableAnnotationComposer,
      $$CashSessionsTableTableCreateCompanionBuilder,
      $$CashSessionsTableTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$GavilanDb, $CashSessionsTableTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$CashMovementsTableTableCreateCompanionBuilder = CashMovementsTableCompanion Function({
  required String id,
  required String sessionId,
  required CashKind kind,
  required int amountCents,
  required String concept,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CashMovementsTableTableUpdateCompanionBuilder = CashMovementsTableCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<CashKind> kind,
  Value<int> amountCents,
  Value<String> concept,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$CashMovementsTableTableFilterComposer extends Composer<_$GavilanDb, $CashMovementsTableTable> {
  $$CashMovementsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CashKind, CashKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get concept =>
      $composableBuilder(column: $table.concept, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CashMovementsTableTableOrderingComposer extends Composer<_$GavilanDb, $CashMovementsTableTable> {
  $$CashMovementsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get concept =>
      $composableBuilder(column: $table.concept, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CashMovementsTableTableAnnotationComposer extends Composer<_$GavilanDb, $CashMovementsTableTable> {
  $$CashMovementsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId => $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CashKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<String> get concept => $composableBuilder(column: $table.concept, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CashMovementsTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $CashMovementsTableTable,
          MovementRow,
          $$CashMovementsTableTableFilterComposer,
          $$CashMovementsTableTableOrderingComposer,
          $$CashMovementsTableTableAnnotationComposer,
          $$CashMovementsTableTableCreateCompanionBuilder,
          $$CashMovementsTableTableUpdateCompanionBuilder,
          (MovementRow, BaseReferences<_$GavilanDb, $CashMovementsTableTable, MovementRow>),
          MovementRow,
          PrefetchHooks Function()
        > {
  $$CashMovementsTableTableTableManager(_$GavilanDb db, $CashMovementsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CashMovementsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CashMovementsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CashMovementsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<CashKind> kind = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> concept = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CashMovementsTableCompanion(
                id: id,
                sessionId: sessionId,
                kind: kind,
                amountCents: amountCents,
                concept: concept,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required CashKind kind,
                required int amountCents,
                required String concept,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CashMovementsTableCompanion.insert(
                id: id,
                sessionId: sessionId,
                kind: kind,
                amountCents: amountCents,
                concept: concept,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CashMovementsTableTable, MovementRow>(table),
                  BaseReferences<_$GavilanDb, $CashMovementsTableTable, MovementRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CashMovementsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $CashMovementsTableTable,
      MovementRow,
      $$CashMovementsTableTableFilterComposer,
      $$CashMovementsTableTableOrderingComposer,
      $$CashMovementsTableTableAnnotationComposer,
      $$CashMovementsTableTableCreateCompanionBuilder,
      $$CashMovementsTableTableUpdateCompanionBuilder,
      (MovementRow, BaseReferences<_$GavilanDb, $CashMovementsTableTable, MovementRow>),
      MovementRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableTableCreateCompanionBuilder = MetaTableCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableTableUpdateCompanionBuilder = MetaTableCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableTableFilterComposer extends Composer<_$GavilanDb, $MetaTableTable> {
  $$MetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$MetaTableTableOrderingComposer extends Composer<_$GavilanDb, $MetaTableTable> {
  $$MetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$MetaTableTableAnnotationComposer extends Composer<_$GavilanDb, $MetaTableTable> {
  $$MetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableTableManager
    extends
        RootTableManager<
          _$GavilanDb,
          $MetaTableTable,
          MetaRow,
          $$MetaTableTableFilterComposer,
          $$MetaTableTableOrderingComposer,
          $$MetaTableTableAnnotationComposer,
          $$MetaTableTableCreateCompanionBuilder,
          $$MetaTableTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$GavilanDb, $MetaTableTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableTableManager(_$GavilanDb db, $MetaTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaTableCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTableTable, MetaRow>(table),
                  BaseReferences<_$GavilanDb, $MetaTableTable, MetaRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GavilanDb,
      $MetaTableTable,
      MetaRow,
      $$MetaTableTableFilterComposer,
      $$MetaTableTableOrderingComposer,
      $$MetaTableTableAnnotationComposer,
      $$MetaTableTableCreateCompanionBuilder,
      $$MetaTableTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$GavilanDb, $MetaTableTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $GavilanDbManager {
  final _$GavilanDb _db;
  $GavilanDbManager(this._db);
  $$OutboxTableTableTableManager get outboxTable => $$OutboxTableTableTableManager(_db, _db.outboxTable);
  $$ProductsTableTableTableManager get productsTable => $$ProductsTableTableTableManager(_db, _db.productsTable);
  $$CustomersTableTableTableManager get customersTable => $$CustomersTableTableTableManager(_db, _db.customersTable);
  $$SalesTableTableTableManager get salesTable => $$SalesTableTableTableManager(_db, _db.salesTable);
  $$SaleLinesTableTableTableManager get saleLinesTable => $$SaleLinesTableTableTableManager(_db, _db.saleLinesTable);
  $$CreditEntriesTableTableTableManager get creditEntriesTable =>
      $$CreditEntriesTableTableTableManager(_db, _db.creditEntriesTable);
  $$CashSessionsTableTableTableManager get cashSessionsTable =>
      $$CashSessionsTableTableTableManager(_db, _db.cashSessionsTable);
  $$CashMovementsTableTableTableManager get cashMovementsTable =>
      $$CashMovementsTableTableTableManager(_db, _db.cashMovementsTable);
  $$MetaTableTableTableManager get metaTable => $$MetaTableTableTableManager(_db, _db.metaTable);
}
