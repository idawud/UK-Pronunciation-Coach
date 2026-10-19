// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_database.dart';

// ignore_for_file: type=lint
class $AttemptsTable extends Attempts
    with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passageIdMeta = const VerificationMeta(
    'passageId',
  );
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
    'passage_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AttemptsTable.$converterat);
  static const VerificationMeta _overallMeta = const VerificationMeta(
    'overall',
  );
  @override
  late final GeneratedColumn<int> overall = GeneratedColumn<int>(
    'overall',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<int> accuracy = GeneratedColumn<int>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fluencyMeta = const VerificationMeta(
    'fluency',
  );
  @override
  late final GeneratedColumn<int> fluency = GeneratedColumn<int>(
    'fluency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ModelTier, String> tier =
      GeneratedColumn<String>(
        'tier',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ModelTier>($AttemptsTable.$convertertier);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    passageId,
    at,
    overall,
    accuracy,
    fluency,
    audioPath,
    tier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('passage_id')) {
      context.handle(
        _passageIdMeta,
        passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_passageIdMeta);
    }
    if (data.containsKey('overall')) {
      context.handle(
        _overallMeta,
        overall.isAcceptableOrUnknown(data['overall']!, _overallMeta),
      );
    } else if (isInserting) {
      context.missing(_overallMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('fluency')) {
      context.handle(
        _fluencyMeta,
        fluency.isAcceptableOrUnknown(data['fluency']!, _fluencyMeta),
      );
    } else if (isInserting) {
      context.missing(_fluencyMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      passageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passage_id'],
      )!,
      at: $AttemptsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
      overall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overall'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accuracy'],
      )!,
      fluency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fluency'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      tier: $AttemptsTable.$convertertier.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tier'],
        )!,
      ),
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterat = const DateTimeCodec();
  static JsonTypeConverter2<ModelTier, String, String> $convertertier =
      const EnumNameConverter<ModelTier>(ModelTier.values);
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final String id;
  final String passageId;
  final DateTime at;
  final int overall;
  final int accuracy;
  final int fluency;
  final String? audioPath;
  final ModelTier tier;
  const AttemptRow({
    required this.id,
    required this.passageId,
    required this.at,
    required this.overall,
    required this.accuracy,
    required this.fluency,
    this.audioPath,
    required this.tier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['passage_id'] = Variable<String>(passageId);
    {
      map['at'] = Variable<int>($AttemptsTable.$converterat.toSql(at));
    }
    map['overall'] = Variable<int>(overall);
    map['accuracy'] = Variable<int>(accuracy);
    map['fluency'] = Variable<int>(fluency);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    {
      map['tier'] = Variable<String>($AttemptsTable.$convertertier.toSql(tier));
    }
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      passageId: Value(passageId),
      at: Value(at),
      overall: Value(overall),
      accuracy: Value(accuracy),
      fluency: Value(fluency),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      tier: Value(tier),
    );
  }

  factory AttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<String>(json['id']),
      passageId: serializer.fromJson<String>(json['passageId']),
      at: serializer.fromJson<DateTime>(json['at']),
      overall: serializer.fromJson<int>(json['overall']),
      accuracy: serializer.fromJson<int>(json['accuracy']),
      fluency: serializer.fromJson<int>(json['fluency']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      tier: $AttemptsTable.$convertertier.fromJson(
        serializer.fromJson<String>(json['tier']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'passageId': serializer.toJson<String>(passageId),
      'at': serializer.toJson<DateTime>(at),
      'overall': serializer.toJson<int>(overall),
      'accuracy': serializer.toJson<int>(accuracy),
      'fluency': serializer.toJson<int>(fluency),
      'audioPath': serializer.toJson<String?>(audioPath),
      'tier': serializer.toJson<String>(
        $AttemptsTable.$convertertier.toJson(tier),
      ),
    };
  }

  AttemptRow copyWith({
    String? id,
    String? passageId,
    DateTime? at,
    int? overall,
    int? accuracy,
    int? fluency,
    Value<String?> audioPath = const Value.absent(),
    ModelTier? tier,
  }) => AttemptRow(
    id: id ?? this.id,
    passageId: passageId ?? this.passageId,
    at: at ?? this.at,
    overall: overall ?? this.overall,
    accuracy: accuracy ?? this.accuracy,
    fluency: fluency ?? this.fluency,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    tier: tier ?? this.tier,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
      at: data.at.present ? data.at.value : this.at,
      overall: data.overall.present ? data.overall.value : this.overall,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      fluency: data.fluency.present ? data.fluency.value : this.fluency,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      tier: data.tier.present ? data.tier.value : this.tier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('passageId: $passageId, ')
          ..write('at: $at, ')
          ..write('overall: $overall, ')
          ..write('accuracy: $accuracy, ')
          ..write('fluency: $fluency, ')
          ..write('audioPath: $audioPath, ')
          ..write('tier: $tier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    passageId,
    at,
    overall,
    accuracy,
    fluency,
    audioPath,
    tier,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.passageId == this.passageId &&
          other.at == this.at &&
          other.overall == this.overall &&
          other.accuracy == this.accuracy &&
          other.fluency == this.fluency &&
          other.audioPath == this.audioPath &&
          other.tier == this.tier);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<String> id;
  final Value<String> passageId;
  final Value<DateTime> at;
  final Value<int> overall;
  final Value<int> accuracy;
  final Value<int> fluency;
  final Value<String?> audioPath;
  final Value<ModelTier> tier;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.passageId = const Value.absent(),
    this.at = const Value.absent(),
    this.overall = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.fluency = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.tier = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required String passageId,
    required DateTime at,
    required int overall,
    required int accuracy,
    required int fluency,
    this.audioPath = const Value.absent(),
    required ModelTier tier,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       passageId = Value(passageId),
       at = Value(at),
       overall = Value(overall),
       accuracy = Value(accuracy),
       fluency = Value(fluency),
       tier = Value(tier);
  static Insertable<AttemptRow> custom({
    Expression<String>? id,
    Expression<String>? passageId,
    Expression<int>? at,
    Expression<int>? overall,
    Expression<int>? accuracy,
    Expression<int>? fluency,
    Expression<String>? audioPath,
    Expression<String>? tier,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (passageId != null) 'passage_id': passageId,
      if (at != null) 'at': at,
      if (overall != null) 'overall': overall,
      if (accuracy != null) 'accuracy': accuracy,
      if (fluency != null) 'fluency': fluency,
      if (audioPath != null) 'audio_path': audioPath,
      if (tier != null) 'tier': tier,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? passageId,
    Value<DateTime>? at,
    Value<int>? overall,
    Value<int>? accuracy,
    Value<int>? fluency,
    Value<String?>? audioPath,
    Value<ModelTier>? tier,
    Value<int>? rowid,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      passageId: passageId ?? this.passageId,
      at: at ?? this.at,
      overall: overall ?? this.overall,
      accuracy: accuracy ?? this.accuracy,
      fluency: fluency ?? this.fluency,
      audioPath: audioPath ?? this.audioPath,
      tier: tier ?? this.tier,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (at.present) {
      map['at'] = Variable<int>($AttemptsTable.$converterat.toSql(at.value));
    }
    if (overall.present) {
      map['overall'] = Variable<int>(overall.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<int>(accuracy.value);
    }
    if (fluency.present) {
      map['fluency'] = Variable<int>(fluency.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(
        $AttemptsTable.$convertertier.toSql(tier.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('passageId: $passageId, ')
          ..write('at: $at, ')
          ..write('overall: $overall, ')
          ..write('accuracy: $accuracy, ')
          ..write('fluency: $fluency, ')
          ..write('audioPath: $audioPath, ')
          ..write('tier: $tier, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordResultsTable extends WordResults
    with TableInfo<$WordResultsTable, WordResultsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attempts (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<WordResult>, Uint8List>
  words = GeneratedColumn<Uint8List>(
    'words',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  ).withConverter<List<WordResult>>($WordResultsTable.$converterwords);
  @override
  List<GeneratedColumn> get $columns => [attemptId, words];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordResultsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId};
  @override
  WordResultsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordResultsRow(
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      words: $WordResultsTable.$converterwords.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.blob,
          data['${effectivePrefix}words'],
        )!,
      ),
    );
  }

  @override
  $WordResultsTable createAlias(String alias) {
    return $WordResultsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<WordResult>, Uint8List> $converterwords =
      const WordResultsCodec();
}

class WordResultsRow extends DataClass implements Insertable<WordResultsRow> {
  final String attemptId;
  final List<WordResult> words;
  const WordResultsRow({required this.attemptId, required this.words});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    {
      map['words'] = Variable<Uint8List>(
        $WordResultsTable.$converterwords.toSql(words),
      );
    }
    return map;
  }

  WordResultsCompanion toCompanion(bool nullToAbsent) {
    return WordResultsCompanion(
      attemptId: Value(attemptId),
      words: Value(words),
    );
  }

  factory WordResultsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordResultsRow(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      words: serializer.fromJson<List<WordResult>>(json['words']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'words': serializer.toJson<List<WordResult>>(words),
    };
  }

  WordResultsRow copyWith({String? attemptId, List<WordResult>? words}) =>
      WordResultsRow(
        attemptId: attemptId ?? this.attemptId,
        words: words ?? this.words,
      );
  WordResultsRow copyWithCompanion(WordResultsCompanion data) {
    return WordResultsRow(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      words: data.words.present ? data.words.value : this.words,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordResultsRow(')
          ..write('attemptId: $attemptId, ')
          ..write('words: $words')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(attemptId, words);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordResultsRow &&
          other.attemptId == this.attemptId &&
          other.words == this.words);
}

class WordResultsCompanion extends UpdateCompanion<WordResultsRow> {
  final Value<String> attemptId;
  final Value<List<WordResult>> words;
  final Value<int> rowid;
  const WordResultsCompanion({
    this.attemptId = const Value.absent(),
    this.words = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordResultsCompanion.insert({
    required String attemptId,
    required List<WordResult> words,
    this.rowid = const Value.absent(),
  }) : attemptId = Value(attemptId),
       words = Value(words);
  static Insertable<WordResultsRow> custom({
    Expression<String>? attemptId,
    Expression<Uint8List>? words,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (words != null) 'words': words,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordResultsCompanion copyWith({
    Value<String>? attemptId,
    Value<List<WordResult>>? words,
    Value<int>? rowid,
  }) {
    return WordResultsCompanion(
      attemptId: attemptId ?? this.attemptId,
      words: words ?? this.words,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (words.present) {
      map['words'] = Variable<Uint8List>(
        $WordResultsTable.$converterwords.toSql(words.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordResultsCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('words: $words, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SoundStatsTable extends SoundStats
    with TableInfo<$SoundStatsTable, SoundStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SoundStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ipaMeta = const VerificationMeta('ipa');
  @override
  late final GeneratedColumn<String> ipa = GeneratedColumn<String>(
    'ipa',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> lastPractised =
      GeneratedColumn<int>(
        'last_practised',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SoundStatsTable.$converterlastPractised);
  @override
  List<GeneratedColumn> get $columns => [
    ipa,
    accuracy,
    attempts,
    lastPractised,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sound_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<SoundStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ipa')) {
      context.handle(
        _ipaMeta,
        ipa.isAcceptableOrUnknown(data['ipa']!, _ipaMeta),
      );
    } else if (isInserting) {
      context.missing(_ipaMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ipa};
  @override
  SoundStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SoundStatRow(
      ipa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ipa'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastPractised: $SoundStatsTable.$converterlastPractised.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_practised'],
        )!,
      ),
    );
  }

  @override
  $SoundStatsTable createAlias(String alias) {
    return $SoundStatsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastPractised =
      const DateTimeCodec();
}

class SoundStatRow extends DataClass implements Insertable<SoundStatRow> {
  final String ipa;
  final double accuracy;
  final int attempts;
  final DateTime lastPractised;
  const SoundStatRow({
    required this.ipa,
    required this.accuracy,
    required this.attempts,
    required this.lastPractised,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ipa'] = Variable<String>(ipa);
    map['accuracy'] = Variable<double>(accuracy);
    map['attempts'] = Variable<int>(attempts);
    {
      map['last_practised'] = Variable<int>(
        $SoundStatsTable.$converterlastPractised.toSql(lastPractised),
      );
    }
    return map;
  }

  SoundStatsCompanion toCompanion(bool nullToAbsent) {
    return SoundStatsCompanion(
      ipa: Value(ipa),
      accuracy: Value(accuracy),
      attempts: Value(attempts),
      lastPractised: Value(lastPractised),
    );
  }

  factory SoundStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SoundStatRow(
      ipa: serializer.fromJson<String>(json['ipa']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastPractised: serializer.fromJson<DateTime>(json['lastPractised']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ipa': serializer.toJson<String>(ipa),
      'accuracy': serializer.toJson<double>(accuracy),
      'attempts': serializer.toJson<int>(attempts),
      'lastPractised': serializer.toJson<DateTime>(lastPractised),
    };
  }

  SoundStatRow copyWith({
    String? ipa,
    double? accuracy,
    int? attempts,
    DateTime? lastPractised,
  }) => SoundStatRow(
    ipa: ipa ?? this.ipa,
    accuracy: accuracy ?? this.accuracy,
    attempts: attempts ?? this.attempts,
    lastPractised: lastPractised ?? this.lastPractised,
  );
  SoundStatRow copyWithCompanion(SoundStatsCompanion data) {
    return SoundStatRow(
      ipa: data.ipa.present ? data.ipa.value : this.ipa,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastPractised: data.lastPractised.present
          ? data.lastPractised.value
          : this.lastPractised,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SoundStatRow(')
          ..write('ipa: $ipa, ')
          ..write('accuracy: $accuracy, ')
          ..write('attempts: $attempts, ')
          ..write('lastPractised: $lastPractised')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ipa, accuracy, attempts, lastPractised);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SoundStatRow &&
          other.ipa == this.ipa &&
          other.accuracy == this.accuracy &&
          other.attempts == this.attempts &&
          other.lastPractised == this.lastPractised);
}

class SoundStatsCompanion extends UpdateCompanion<SoundStatRow> {
  final Value<String> ipa;
  final Value<double> accuracy;
  final Value<int> attempts;
  final Value<DateTime> lastPractised;
  final Value<int> rowid;
  const SoundStatsCompanion({
    this.ipa = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastPractised = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SoundStatsCompanion.insert({
    required String ipa,
    required double accuracy,
    required int attempts,
    required DateTime lastPractised,
    this.rowid = const Value.absent(),
  }) : ipa = Value(ipa),
       accuracy = Value(accuracy),
       attempts = Value(attempts),
       lastPractised = Value(lastPractised);
  static Insertable<SoundStatRow> custom({
    Expression<String>? ipa,
    Expression<double>? accuracy,
    Expression<int>? attempts,
    Expression<int>? lastPractised,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ipa != null) 'ipa': ipa,
      if (accuracy != null) 'accuracy': accuracy,
      if (attempts != null) 'attempts': attempts,
      if (lastPractised != null) 'last_practised': lastPractised,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SoundStatsCompanion copyWith({
    Value<String>? ipa,
    Value<double>? accuracy,
    Value<int>? attempts,
    Value<DateTime>? lastPractised,
    Value<int>? rowid,
  }) {
    return SoundStatsCompanion(
      ipa: ipa ?? this.ipa,
      accuracy: accuracy ?? this.accuracy,
      attempts: attempts ?? this.attempts,
      lastPractised: lastPractised ?? this.lastPractised,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ipa.present) {
      map['ipa'] = Variable<String>(ipa.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastPractised.present) {
      map['last_practised'] = Variable<int>(
        $SoundStatsTable.$converterlastPractised.toSql(lastPractised.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SoundStatsCompanion(')
          ..write('ipa: $ipa, ')
          ..write('accuracy: $accuracy, ')
          ..write('attempts: $attempts, ')
          ..write('lastPractised: $lastPractised, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewQueueTable extends ReviewQueue
    with TableInfo<$ReviewQueueTable, ReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<PhonemeSpec>, String>
  phonemes = GeneratedColumn<String>(
    'phonemes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<PhonemeSpec>>($ReviewQueueTable.$converterphonemes);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> due =
      GeneratedColumn<int>(
        'due',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ReviewQueueTable.$converterdue);
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<int> stage = GeneratedColumn<int>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScoreMeta = const VerificationMeta(
    'lastScore',
  );
  @override
  late final GeneratedColumn<int> lastScore = GeneratedColumn<int>(
    'last_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passageIdMeta = const VerificationMeta(
    'passageId',
  );
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
    'passage_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordKey,
    word,
    phonemes,
    due,
    intervalDays,
    ease,
    stage,
    lastScore,
    passageId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intervalDaysMeta);
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    } else if (isInserting) {
      context.missing(_easeMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('last_score')) {
      context.handle(
        _lastScoreMeta,
        lastScore.isAcceptableOrUnknown(data['last_score']!, _lastScoreMeta),
      );
    }
    if (data.containsKey('passage_id')) {
      context.handle(
        _passageIdMeta,
        passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordKey};
  @override
  ReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRow(
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      phonemes: $ReviewQueueTable.$converterphonemes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}phonemes'],
        )!,
      ),
      due: $ReviewQueueTable.$converterdue.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}due'],
        )!,
      ),
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage'],
      )!,
      lastScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_score'],
      ),
      passageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passage_id'],
      ),
    );
  }

  @override
  $ReviewQueueTable createAlias(String alias) {
    return $ReviewQueueTable(attachedDatabase, alias);
  }

  static TypeConverter<List<PhonemeSpec>, String> $converterphonemes =
      const PhonemeSpecsCodec();
  static TypeConverter<DateTime, int> $converterdue = const DateTimeCodec();
}

class ReviewRow extends DataClass implements Insertable<ReviewRow> {
  final String wordKey;
  final String word;
  final List<PhonemeSpec> phonemes;
  final DateTime due;
  final int intervalDays;
  final double ease;
  final int stage;
  final int? lastScore;
  final String? passageId;
  const ReviewRow({
    required this.wordKey,
    required this.word,
    required this.phonemes,
    required this.due,
    required this.intervalDays,
    required this.ease,
    required this.stage,
    this.lastScore,
    this.passageId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_key'] = Variable<String>(wordKey);
    map['word'] = Variable<String>(word);
    {
      map['phonemes'] = Variable<String>(
        $ReviewQueueTable.$converterphonemes.toSql(phonemes),
      );
    }
    {
      map['due'] = Variable<int>($ReviewQueueTable.$converterdue.toSql(due));
    }
    map['interval_days'] = Variable<int>(intervalDays);
    map['ease'] = Variable<double>(ease);
    map['stage'] = Variable<int>(stage);
    if (!nullToAbsent || lastScore != null) {
      map['last_score'] = Variable<int>(lastScore);
    }
    if (!nullToAbsent || passageId != null) {
      map['passage_id'] = Variable<String>(passageId);
    }
    return map;
  }

  ReviewQueueCompanion toCompanion(bool nullToAbsent) {
    return ReviewQueueCompanion(
      wordKey: Value(wordKey),
      word: Value(word),
      phonemes: Value(phonemes),
      due: Value(due),
      intervalDays: Value(intervalDays),
      ease: Value(ease),
      stage: Value(stage),
      lastScore: lastScore == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScore),
      passageId: passageId == null && nullToAbsent
          ? const Value.absent()
          : Value(passageId),
    );
  }

  factory ReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewRow(
      wordKey: serializer.fromJson<String>(json['wordKey']),
      word: serializer.fromJson<String>(json['word']),
      phonemes: serializer.fromJson<List<PhonemeSpec>>(json['phonemes']),
      due: serializer.fromJson<DateTime>(json['due']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      ease: serializer.fromJson<double>(json['ease']),
      stage: serializer.fromJson<int>(json['stage']),
      lastScore: serializer.fromJson<int?>(json['lastScore']),
      passageId: serializer.fromJson<String?>(json['passageId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordKey': serializer.toJson<String>(wordKey),
      'word': serializer.toJson<String>(word),
      'phonemes': serializer.toJson<List<PhonemeSpec>>(phonemes),
      'due': serializer.toJson<DateTime>(due),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'ease': serializer.toJson<double>(ease),
      'stage': serializer.toJson<int>(stage),
      'lastScore': serializer.toJson<int?>(lastScore),
      'passageId': serializer.toJson<String?>(passageId),
    };
  }

  ReviewRow copyWith({
    String? wordKey,
    String? word,
    List<PhonemeSpec>? phonemes,
    DateTime? due,
    int? intervalDays,
    double? ease,
    int? stage,
    Value<int?> lastScore = const Value.absent(),
    Value<String?> passageId = const Value.absent(),
  }) => ReviewRow(
    wordKey: wordKey ?? this.wordKey,
    word: word ?? this.word,
    phonemes: phonemes ?? this.phonemes,
    due: due ?? this.due,
    intervalDays: intervalDays ?? this.intervalDays,
    ease: ease ?? this.ease,
    stage: stage ?? this.stage,
    lastScore: lastScore.present ? lastScore.value : this.lastScore,
    passageId: passageId.present ? passageId.value : this.passageId,
  );
  ReviewRow copyWithCompanion(ReviewQueueCompanion data) {
    return ReviewRow(
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      word: data.word.present ? data.word.value : this.word,
      phonemes: data.phonemes.present ? data.phonemes.value : this.phonemes,
      due: data.due.present ? data.due.value : this.due,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      ease: data.ease.present ? data.ease.value : this.ease,
      stage: data.stage.present ? data.stage.value : this.stage,
      lastScore: data.lastScore.present ? data.lastScore.value : this.lastScore,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRow(')
          ..write('wordKey: $wordKey, ')
          ..write('word: $word, ')
          ..write('phonemes: $phonemes, ')
          ..write('due: $due, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('stage: $stage, ')
          ..write('lastScore: $lastScore, ')
          ..write('passageId: $passageId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    wordKey,
    word,
    phonemes,
    due,
    intervalDays,
    ease,
    stage,
    lastScore,
    passageId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewRow &&
          other.wordKey == this.wordKey &&
          other.word == this.word &&
          other.phonemes == this.phonemes &&
          other.due == this.due &&
          other.intervalDays == this.intervalDays &&
          other.ease == this.ease &&
          other.stage == this.stage &&
          other.lastScore == this.lastScore &&
          other.passageId == this.passageId);
}

class ReviewQueueCompanion extends UpdateCompanion<ReviewRow> {
  final Value<String> wordKey;
  final Value<String> word;
  final Value<List<PhonemeSpec>> phonemes;
  final Value<DateTime> due;
  final Value<int> intervalDays;
  final Value<double> ease;
  final Value<int> stage;
  final Value<int?> lastScore;
  final Value<String?> passageId;
  final Value<int> rowid;
  const ReviewQueueCompanion({
    this.wordKey = const Value.absent(),
    this.word = const Value.absent(),
    this.phonemes = const Value.absent(),
    this.due = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.stage = const Value.absent(),
    this.lastScore = const Value.absent(),
    this.passageId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewQueueCompanion.insert({
    required String wordKey,
    required String word,
    required List<PhonemeSpec> phonemes,
    required DateTime due,
    required int intervalDays,
    required double ease,
    required int stage,
    this.lastScore = const Value.absent(),
    this.passageId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordKey = Value(wordKey),
       word = Value(word),
       phonemes = Value(phonemes),
       due = Value(due),
       intervalDays = Value(intervalDays),
       ease = Value(ease),
       stage = Value(stage);
  static Insertable<ReviewRow> custom({
    Expression<String>? wordKey,
    Expression<String>? word,
    Expression<String>? phonemes,
    Expression<int>? due,
    Expression<int>? intervalDays,
    Expression<double>? ease,
    Expression<int>? stage,
    Expression<int>? lastScore,
    Expression<String>? passageId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordKey != null) 'word_key': wordKey,
      if (word != null) 'word': word,
      if (phonemes != null) 'phonemes': phonemes,
      if (due != null) 'due': due,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (ease != null) 'ease': ease,
      if (stage != null) 'stage': stage,
      if (lastScore != null) 'last_score': lastScore,
      if (passageId != null) 'passage_id': passageId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewQueueCompanion copyWith({
    Value<String>? wordKey,
    Value<String>? word,
    Value<List<PhonemeSpec>>? phonemes,
    Value<DateTime>? due,
    Value<int>? intervalDays,
    Value<double>? ease,
    Value<int>? stage,
    Value<int?>? lastScore,
    Value<String?>? passageId,
    Value<int>? rowid,
  }) {
    return ReviewQueueCompanion(
      wordKey: wordKey ?? this.wordKey,
      word: word ?? this.word,
      phonemes: phonemes ?? this.phonemes,
      due: due ?? this.due,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      stage: stage ?? this.stage,
      lastScore: lastScore ?? this.lastScore,
      passageId: passageId ?? this.passageId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (phonemes.present) {
      map['phonemes'] = Variable<String>(
        $ReviewQueueTable.$converterphonemes.toSql(phonemes.value),
      );
    }
    if (due.present) {
      map['due'] = Variable<int>(
        $ReviewQueueTable.$converterdue.toSql(due.value),
      );
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(stage.value);
    }
    if (lastScore.present) {
      map['last_score'] = Variable<int>(lastScore.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewQueueCompanion(')
          ..write('wordKey: $wordKey, ')
          ..write('word: $word, ')
          ..write('phonemes: $phonemes, ')
          ..write('due: $due, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('stage: $stage, ')
          ..write('lastScore: $lastScore, ')
          ..write('passageId: $passageId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTableTable extends UserProfileTable
    with TableInfo<$UserProfileTableTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyGoalMinutesMeta = const VerificationMeta(
    'dailyGoalMinutes',
  );
  @override
  late final GeneratedColumn<int> dailyGoalMinutes = GeneratedColumn<int>(
    'daily_goal_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastPractice =
      GeneratedColumn<int>(
        'last_practice',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $UserProfileTableTable.$converterlastPracticen,
      );
  static const VerificationMeta _keepRecordingsMeta = const VerificationMeta(
    'keepRecordings',
  );
  @override
  late final GeneratedColumn<bool> keepRecordings = GeneratedColumn<bool>(
    'keep_recordings',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_recordings" IN (0, 1))',
    ),
  );
  static const VerificationMeta _placementDoneMeta = const VerificationMeta(
    'placementDone',
  );
  @override
  late final GeneratedColumn<bool> placementDone = GeneratedColumn<bool>(
    'placement_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("placement_done" IN (0, 1))',
    ),
  );
  static const VerificationMeta _placementLevelMeta = const VerificationMeta(
    'placementLevel',
  );
  @override
  late final GeneratedColumn<int> placementLevel = GeneratedColumn<int>(
    'placement_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textScaleMeta = const VerificationMeta(
    'textScale',
  );
  @override
  late final GeneratedColumn<double> textScale = GeneratedColumn<double>(
    'text_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ModelTier?, String> tierOverride =
      GeneratedColumn<String>(
        'tier_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ModelTier?>(
        $UserProfileTableTable.$convertertierOverriden,
      );
  static const VerificationMeta _onboardingDoneMeta = const VerificationMeta(
    'onboardingDone',
  );
  @override
  late final GeneratedColumn<bool> onboardingDone = GeneratedColumn<bool>(
    'onboarding_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_done" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    level,
    dailyGoalMinutes,
    streak,
    lastPractice,
    keepRecordings,
    placementDone,
    placementLevel,
    reminderMinutes,
    textScale,
    tierOverride,
    onboardingDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('daily_goal_minutes')) {
      context.handle(
        _dailyGoalMinutesMeta,
        dailyGoalMinutes.isAcceptableOrUnknown(
          data['daily_goal_minutes']!,
          _dailyGoalMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyGoalMinutesMeta);
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    } else if (isInserting) {
      context.missing(_streakMeta);
    }
    if (data.containsKey('keep_recordings')) {
      context.handle(
        _keepRecordingsMeta,
        keepRecordings.isAcceptableOrUnknown(
          data['keep_recordings']!,
          _keepRecordingsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_keepRecordingsMeta);
    }
    if (data.containsKey('placement_done')) {
      context.handle(
        _placementDoneMeta,
        placementDone.isAcceptableOrUnknown(
          data['placement_done']!,
          _placementDoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placementDoneMeta);
    }
    if (data.containsKey('placement_level')) {
      context.handle(
        _placementLevelMeta,
        placementLevel.isAcceptableOrUnknown(
          data['placement_level']!,
          _placementLevelMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('text_scale')) {
      context.handle(
        _textScaleMeta,
        textScale.isAcceptableOrUnknown(data['text_scale']!, _textScaleMeta),
      );
    } else if (isInserting) {
      context.missing(_textScaleMeta);
    }
    if (data.containsKey('onboarding_done')) {
      context.handle(
        _onboardingDoneMeta,
        onboardingDone.isAcceptableOrUnknown(
          data['onboarding_done']!,
          _onboardingDoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_onboardingDoneMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      dailyGoalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_goal_minutes'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      lastPractice: $UserProfileTableTable.$converterlastPracticen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_practice'],
        ),
      ),
      keepRecordings: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_recordings'],
      )!,
      placementDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}placement_done'],
      )!,
      placementLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}placement_level'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      textScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_scale'],
      )!,
      tierOverride: $UserProfileTableTable.$convertertierOverriden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tier_override'],
        ),
      ),
      onboardingDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_done'],
      )!,
    );
  }

  @override
  $UserProfileTableTable createAlias(String alias) {
    return $UserProfileTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterlastPractice =
      const DateTimeCodec();
  static TypeConverter<DateTime?, int?> $converterlastPracticen =
      NullAwareTypeConverter.wrap($converterlastPractice);
  static JsonTypeConverter2<ModelTier, String, String> $convertertierOverride =
      const EnumNameConverter<ModelTier>(ModelTier.values);
  static JsonTypeConverter2<ModelTier?, String?, String?>
  $convertertierOverriden = JsonTypeConverter2.asNullable(
    $convertertierOverride,
  );
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final int level;
  final int dailyGoalMinutes;
  final int streak;
  final DateTime? lastPractice;
  final bool keepRecordings;
  final bool placementDone;
  final int? placementLevel;
  final int? reminderMinutes;
  final double textScale;
  final ModelTier? tierOverride;
  final bool onboardingDone;
  const ProfileRow({
    required this.id,
    required this.level,
    required this.dailyGoalMinutes,
    required this.streak,
    this.lastPractice,
    required this.keepRecordings,
    required this.placementDone,
    this.placementLevel,
    this.reminderMinutes,
    required this.textScale,
    this.tierOverride,
    required this.onboardingDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['level'] = Variable<int>(level);
    map['daily_goal_minutes'] = Variable<int>(dailyGoalMinutes);
    map['streak'] = Variable<int>(streak);
    if (!nullToAbsent || lastPractice != null) {
      map['last_practice'] = Variable<int>(
        $UserProfileTableTable.$converterlastPracticen.toSql(lastPractice),
      );
    }
    map['keep_recordings'] = Variable<bool>(keepRecordings);
    map['placement_done'] = Variable<bool>(placementDone);
    if (!nullToAbsent || placementLevel != null) {
      map['placement_level'] = Variable<int>(placementLevel);
    }
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    map['text_scale'] = Variable<double>(textScale);
    if (!nullToAbsent || tierOverride != null) {
      map['tier_override'] = Variable<String>(
        $UserProfileTableTable.$convertertierOverriden.toSql(tierOverride),
      );
    }
    map['onboarding_done'] = Variable<bool>(onboardingDone);
    return map;
  }

  UserProfileTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfileTableCompanion(
      id: Value(id),
      level: Value(level),
      dailyGoalMinutes: Value(dailyGoalMinutes),
      streak: Value(streak),
      lastPractice: lastPractice == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPractice),
      keepRecordings: Value(keepRecordings),
      placementDone: Value(placementDone),
      placementLevel: placementLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(placementLevel),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      textScale: Value(textScale),
      tierOverride: tierOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(tierOverride),
      onboardingDone: Value(onboardingDone),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      level: serializer.fromJson<int>(json['level']),
      dailyGoalMinutes: serializer.fromJson<int>(json['dailyGoalMinutes']),
      streak: serializer.fromJson<int>(json['streak']),
      lastPractice: serializer.fromJson<DateTime?>(json['lastPractice']),
      keepRecordings: serializer.fromJson<bool>(json['keepRecordings']),
      placementDone: serializer.fromJson<bool>(json['placementDone']),
      placementLevel: serializer.fromJson<int?>(json['placementLevel']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      textScale: serializer.fromJson<double>(json['textScale']),
      tierOverride: $UserProfileTableTable.$convertertierOverriden.fromJson(
        serializer.fromJson<String?>(json['tierOverride']),
      ),
      onboardingDone: serializer.fromJson<bool>(json['onboardingDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'level': serializer.toJson<int>(level),
      'dailyGoalMinutes': serializer.toJson<int>(dailyGoalMinutes),
      'streak': serializer.toJson<int>(streak),
      'lastPractice': serializer.toJson<DateTime?>(lastPractice),
      'keepRecordings': serializer.toJson<bool>(keepRecordings),
      'placementDone': serializer.toJson<bool>(placementDone),
      'placementLevel': serializer.toJson<int?>(placementLevel),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'textScale': serializer.toJson<double>(textScale),
      'tierOverride': serializer.toJson<String?>(
        $UserProfileTableTable.$convertertierOverriden.toJson(tierOverride),
      ),
      'onboardingDone': serializer.toJson<bool>(onboardingDone),
    };
  }

  ProfileRow copyWith({
    int? id,
    int? level,
    int? dailyGoalMinutes,
    int? streak,
    Value<DateTime?> lastPractice = const Value.absent(),
    bool? keepRecordings,
    bool? placementDone,
    Value<int?> placementLevel = const Value.absent(),
    Value<int?> reminderMinutes = const Value.absent(),
    double? textScale,
    Value<ModelTier?> tierOverride = const Value.absent(),
    bool? onboardingDone,
  }) => ProfileRow(
    id: id ?? this.id,
    level: level ?? this.level,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    streak: streak ?? this.streak,
    lastPractice: lastPractice.present ? lastPractice.value : this.lastPractice,
    keepRecordings: keepRecordings ?? this.keepRecordings,
    placementDone: placementDone ?? this.placementDone,
    placementLevel: placementLevel.present
        ? placementLevel.value
        : this.placementLevel,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    textScale: textScale ?? this.textScale,
    tierOverride: tierOverride.present ? tierOverride.value : this.tierOverride,
    onboardingDone: onboardingDone ?? this.onboardingDone,
  );
  ProfileRow copyWithCompanion(UserProfileTableCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      dailyGoalMinutes: data.dailyGoalMinutes.present
          ? data.dailyGoalMinutes.value
          : this.dailyGoalMinutes,
      streak: data.streak.present ? data.streak.value : this.streak,
      lastPractice: data.lastPractice.present
          ? data.lastPractice.value
          : this.lastPractice,
      keepRecordings: data.keepRecordings.present
          ? data.keepRecordings.value
          : this.keepRecordings,
      placementDone: data.placementDone.present
          ? data.placementDone.value
          : this.placementDone,
      placementLevel: data.placementLevel.present
          ? data.placementLevel.value
          : this.placementLevel,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      textScale: data.textScale.present ? data.textScale.value : this.textScale,
      tierOverride: data.tierOverride.present
          ? data.tierOverride.value
          : this.tierOverride,
      onboardingDone: data.onboardingDone.present
          ? data.onboardingDone.value
          : this.onboardingDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('dailyGoalMinutes: $dailyGoalMinutes, ')
          ..write('streak: $streak, ')
          ..write('lastPractice: $lastPractice, ')
          ..write('keepRecordings: $keepRecordings, ')
          ..write('placementDone: $placementDone, ')
          ..write('placementLevel: $placementLevel, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('textScale: $textScale, ')
          ..write('tierOverride: $tierOverride, ')
          ..write('onboardingDone: $onboardingDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    level,
    dailyGoalMinutes,
    streak,
    lastPractice,
    keepRecordings,
    placementDone,
    placementLevel,
    reminderMinutes,
    textScale,
    tierOverride,
    onboardingDone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.level == this.level &&
          other.dailyGoalMinutes == this.dailyGoalMinutes &&
          other.streak == this.streak &&
          other.lastPractice == this.lastPractice &&
          other.keepRecordings == this.keepRecordings &&
          other.placementDone == this.placementDone &&
          other.placementLevel == this.placementLevel &&
          other.reminderMinutes == this.reminderMinutes &&
          other.textScale == this.textScale &&
          other.tierOverride == this.tierOverride &&
          other.onboardingDone == this.onboardingDone);
}

class UserProfileTableCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<int> level;
  final Value<int> dailyGoalMinutes;
  final Value<int> streak;
  final Value<DateTime?> lastPractice;
  final Value<bool> keepRecordings;
  final Value<bool> placementDone;
  final Value<int?> placementLevel;
  final Value<int?> reminderMinutes;
  final Value<double> textScale;
  final Value<ModelTier?> tierOverride;
  final Value<bool> onboardingDone;
  const UserProfileTableCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.dailyGoalMinutes = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastPractice = const Value.absent(),
    this.keepRecordings = const Value.absent(),
    this.placementDone = const Value.absent(),
    this.placementLevel = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.textScale = const Value.absent(),
    this.tierOverride = const Value.absent(),
    this.onboardingDone = const Value.absent(),
  });
  UserProfileTableCompanion.insert({
    this.id = const Value.absent(),
    required int level,
    required int dailyGoalMinutes,
    required int streak,
    this.lastPractice = const Value.absent(),
    required bool keepRecordings,
    required bool placementDone,
    this.placementLevel = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    required double textScale,
    this.tierOverride = const Value.absent(),
    required bool onboardingDone,
  }) : level = Value(level),
       dailyGoalMinutes = Value(dailyGoalMinutes),
       streak = Value(streak),
       keepRecordings = Value(keepRecordings),
       placementDone = Value(placementDone),
       textScale = Value(textScale),
       onboardingDone = Value(onboardingDone);
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<int>? level,
    Expression<int>? dailyGoalMinutes,
    Expression<int>? streak,
    Expression<int>? lastPractice,
    Expression<bool>? keepRecordings,
    Expression<bool>? placementDone,
    Expression<int>? placementLevel,
    Expression<int>? reminderMinutes,
    Expression<double>? textScale,
    Expression<String>? tierOverride,
    Expression<bool>? onboardingDone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      if (streak != null) 'streak': streak,
      if (lastPractice != null) 'last_practice': lastPractice,
      if (keepRecordings != null) 'keep_recordings': keepRecordings,
      if (placementDone != null) 'placement_done': placementDone,
      if (placementLevel != null) 'placement_level': placementLevel,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (textScale != null) 'text_scale': textScale,
      if (tierOverride != null) 'tier_override': tierOverride,
      if (onboardingDone != null) 'onboarding_done': onboardingDone,
    });
  }

  UserProfileTableCompanion copyWith({
    Value<int>? id,
    Value<int>? level,
    Value<int>? dailyGoalMinutes,
    Value<int>? streak,
    Value<DateTime?>? lastPractice,
    Value<bool>? keepRecordings,
    Value<bool>? placementDone,
    Value<int?>? placementLevel,
    Value<int?>? reminderMinutes,
    Value<double>? textScale,
    Value<ModelTier?>? tierOverride,
    Value<bool>? onboardingDone,
  }) {
    return UserProfileTableCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      streak: streak ?? this.streak,
      lastPractice: lastPractice ?? this.lastPractice,
      keepRecordings: keepRecordings ?? this.keepRecordings,
      placementDone: placementDone ?? this.placementDone,
      placementLevel: placementLevel ?? this.placementLevel,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      textScale: textScale ?? this.textScale,
      tierOverride: tierOverride ?? this.tierOverride,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (dailyGoalMinutes.present) {
      map['daily_goal_minutes'] = Variable<int>(dailyGoalMinutes.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (lastPractice.present) {
      map['last_practice'] = Variable<int>(
        $UserProfileTableTable.$converterlastPracticen.toSql(
          lastPractice.value,
        ),
      );
    }
    if (keepRecordings.present) {
      map['keep_recordings'] = Variable<bool>(keepRecordings.value);
    }
    if (placementDone.present) {
      map['placement_done'] = Variable<bool>(placementDone.value);
    }
    if (placementLevel.present) {
      map['placement_level'] = Variable<int>(placementLevel.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (textScale.present) {
      map['text_scale'] = Variable<double>(textScale.value);
    }
    if (tierOverride.present) {
      map['tier_override'] = Variable<String>(
        $UserProfileTableTable.$convertertierOverriden.toSql(
          tierOverride.value,
        ),
      );
    }
    if (onboardingDone.present) {
      map['onboarding_done'] = Variable<bool>(onboardingDone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('dailyGoalMinutes: $dailyGoalMinutes, ')
          ..write('streak: $streak, ')
          ..write('lastPractice: $lastPractice, ')
          ..write('keepRecordings: $keepRecordings, ')
          ..write('placementDone: $placementDone, ')
          ..write('placementLevel: $placementLevel, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('textScale: $textScale, ')
          ..write('tierOverride: $tierOverride, ')
          ..write('onboardingDone: $onboardingDone')
          ..write(')'))
        .toString();
  }
}

class $LevelChangesTable extends LevelChanges
    with TableInfo<$LevelChangesTable, LevelChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LevelChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fromLevelMeta = const VerificationMeta(
    'fromLevel',
  );
  @override
  late final GeneratedColumn<int> fromLevel = GeneratedColumn<int>(
    'from_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toLevelMeta = const VerificationMeta(
    'toLevel',
  );
  @override
  late final GeneratedColumn<int> toLevel = GeneratedColumn<int>(
    'to_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LevelChangesTable.$converterat);
  @override
  List<GeneratedColumn> get $columns => [id, fromLevel, toLevel, reason, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'level_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LevelChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_level')) {
      context.handle(
        _fromLevelMeta,
        fromLevel.isAcceptableOrUnknown(data['from_level']!, _fromLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_fromLevelMeta);
    }
    if (data.containsKey('to_level')) {
      context.handle(
        _toLevelMeta,
        toLevel.isAcceptableOrUnknown(data['to_level']!, _toLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_toLevelMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LevelChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LevelChangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_level'],
      )!,
      toLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_level'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      at: $LevelChangesTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
    );
  }

  @override
  $LevelChangesTable createAlias(String alias) {
    return $LevelChangesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterat = const DateTimeCodec();
}

class LevelChangeRow extends DataClass implements Insertable<LevelChangeRow> {
  final int id;
  final int fromLevel;
  final int toLevel;
  final String reason;
  final DateTime at;
  const LevelChangeRow({
    required this.id,
    required this.fromLevel,
    required this.toLevel,
    required this.reason,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_level'] = Variable<int>(fromLevel);
    map['to_level'] = Variable<int>(toLevel);
    map['reason'] = Variable<String>(reason);
    {
      map['at'] = Variable<int>($LevelChangesTable.$converterat.toSql(at));
    }
    return map;
  }

  LevelChangesCompanion toCompanion(bool nullToAbsent) {
    return LevelChangesCompanion(
      id: Value(id),
      fromLevel: Value(fromLevel),
      toLevel: Value(toLevel),
      reason: Value(reason),
      at: Value(at),
    );
  }

  factory LevelChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LevelChangeRow(
      id: serializer.fromJson<int>(json['id']),
      fromLevel: serializer.fromJson<int>(json['fromLevel']),
      toLevel: serializer.fromJson<int>(json['toLevel']),
      reason: serializer.fromJson<String>(json['reason']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromLevel': serializer.toJson<int>(fromLevel),
      'toLevel': serializer.toJson<int>(toLevel),
      'reason': serializer.toJson<String>(reason),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  LevelChangeRow copyWith({
    int? id,
    int? fromLevel,
    int? toLevel,
    String? reason,
    DateTime? at,
  }) => LevelChangeRow(
    id: id ?? this.id,
    fromLevel: fromLevel ?? this.fromLevel,
    toLevel: toLevel ?? this.toLevel,
    reason: reason ?? this.reason,
    at: at ?? this.at,
  );
  LevelChangeRow copyWithCompanion(LevelChangesCompanion data) {
    return LevelChangeRow(
      id: data.id.present ? data.id.value : this.id,
      fromLevel: data.fromLevel.present ? data.fromLevel.value : this.fromLevel,
      toLevel: data.toLevel.present ? data.toLevel.value : this.toLevel,
      reason: data.reason.present ? data.reason.value : this.reason,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LevelChangeRow(')
          ..write('id: $id, ')
          ..write('fromLevel: $fromLevel, ')
          ..write('toLevel: $toLevel, ')
          ..write('reason: $reason, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fromLevel, toLevel, reason, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LevelChangeRow &&
          other.id == this.id &&
          other.fromLevel == this.fromLevel &&
          other.toLevel == this.toLevel &&
          other.reason == this.reason &&
          other.at == this.at);
}

class LevelChangesCompanion extends UpdateCompanion<LevelChangeRow> {
  final Value<int> id;
  final Value<int> fromLevel;
  final Value<int> toLevel;
  final Value<String> reason;
  final Value<DateTime> at;
  const LevelChangesCompanion({
    this.id = const Value.absent(),
    this.fromLevel = const Value.absent(),
    this.toLevel = const Value.absent(),
    this.reason = const Value.absent(),
    this.at = const Value.absent(),
  });
  LevelChangesCompanion.insert({
    this.id = const Value.absent(),
    required int fromLevel,
    required int toLevel,
    required String reason,
    required DateTime at,
  }) : fromLevel = Value(fromLevel),
       toLevel = Value(toLevel),
       reason = Value(reason),
       at = Value(at);
  static Insertable<LevelChangeRow> custom({
    Expression<int>? id,
    Expression<int>? fromLevel,
    Expression<int>? toLevel,
    Expression<String>? reason,
    Expression<int>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromLevel != null) 'from_level': fromLevel,
      if (toLevel != null) 'to_level': toLevel,
      if (reason != null) 'reason': reason,
      if (at != null) 'at': at,
    });
  }

  LevelChangesCompanion copyWith({
    Value<int>? id,
    Value<int>? fromLevel,
    Value<int>? toLevel,
    Value<String>? reason,
    Value<DateTime>? at,
  }) {
    return LevelChangesCompanion(
      id: id ?? this.id,
      fromLevel: fromLevel ?? this.fromLevel,
      toLevel: toLevel ?? this.toLevel,
      reason: reason ?? this.reason,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromLevel.present) {
      map['from_level'] = Variable<int>(fromLevel.value);
    }
    if (toLevel.present) {
      map['to_level'] = Variable<int>(toLevel.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(
        $LevelChangesTable.$converterat.toSql(at.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LevelChangesCompanion(')
          ..write('id: $id, ')
          ..write('fromLevel: $fromLevel, ')
          ..write('toLevel: $toLevel, ')
          ..write('reason: $reason, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> start =
      GeneratedColumn<int>(
        'start',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PracticeSessionsTable.$converterstart);
  static const VerificationMeta _durationUsMeta = const VerificationMeta(
    'durationUs',
  );
  @override
  late final GeneratedColumn<int> durationUs = GeneratedColumn<int>(
    'duration_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, start, durationUs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('duration_us')) {
      context.handle(
        _durationUsMeta,
        durationUs.isAcceptableOrUnknown(data['duration_us']!, _durationUsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      start: $PracticeSessionsTable.$converterstart.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}start'],
        )!,
      ),
      durationUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_us'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterstart = const DateTimeCodec();
}

class PracticeSessionRow extends DataClass
    implements Insertable<PracticeSessionRow> {
  final int id;
  final DateTime start;
  final int durationUs;
  const PracticeSessionRow({
    required this.id,
    required this.start,
    required this.durationUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['start'] = Variable<int>(
        $PracticeSessionsTable.$converterstart.toSql(start),
      );
    }
    map['duration_us'] = Variable<int>(durationUs);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      start: Value(start),
      durationUs: Value(durationUs),
    );
  }

  factory PracticeSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSessionRow(
      id: serializer.fromJson<int>(json['id']),
      start: serializer.fromJson<DateTime>(json['start']),
      durationUs: serializer.fromJson<int>(json['durationUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'start': serializer.toJson<DateTime>(start),
      'durationUs': serializer.toJson<int>(durationUs),
    };
  }

  PracticeSessionRow copyWith({int? id, DateTime? start, int? durationUs}) =>
      PracticeSessionRow(
        id: id ?? this.id,
        start: start ?? this.start,
        durationUs: durationUs ?? this.durationUs,
      );
  PracticeSessionRow copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSessionRow(
      id: data.id.present ? data.id.value : this.id,
      start: data.start.present ? data.start.value : this.start,
      durationUs: data.durationUs.present
          ? data.durationUs.value
          : this.durationUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionRow(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('durationUs: $durationUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, start, durationUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSessionRow &&
          other.id == this.id &&
          other.start == this.start &&
          other.durationUs == this.durationUs);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSessionRow> {
  final Value<int> id;
  final Value<DateTime> start;
  final Value<int> durationUs;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.start = const Value.absent(),
    this.durationUs = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime start,
    required int durationUs,
  }) : start = Value(start),
       durationUs = Value(durationUs);
  static Insertable<PracticeSessionRow> custom({
    Expression<int>? id,
    Expression<int>? start,
    Expression<int>? durationUs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (start != null) 'start': start,
      if (durationUs != null) 'duration_us': durationUs,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? start,
    Value<int>? durationUs,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      start: start ?? this.start,
      durationUs: durationUs ?? this.durationUs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (start.present) {
      map['start'] = Variable<int>(
        $PracticeSessionsTable.$converterstart.toSql(start.value),
      );
    }
    if (durationUs.present) {
      map['duration_us'] = Variable<int>(durationUs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('durationUs: $durationUs')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProgressDatabase extends GeneratedDatabase {
  _$ProgressDatabase(QueryExecutor e) : super(e);
  $ProgressDatabaseManager get managers => $ProgressDatabaseManager(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $WordResultsTable wordResults = $WordResultsTable(this);
  late final $SoundStatsTable soundStats = $SoundStatsTable(this);
  late final $ReviewQueueTable reviewQueue = $ReviewQueueTable(this);
  late final $UserProfileTableTable userProfileTable = $UserProfileTableTable(
    this,
  );
  late final $LevelChangesTable levelChanges = $LevelChangesTable(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final Index attemptsAt = Index(
    'attempts_at',
    'CREATE INDEX attempts_at ON attempts (at)',
  );
  late final Index attemptsPassage = Index(
    'attempts_passage',
    'CREATE INDEX attempts_passage ON attempts (passage_id, at)',
  );
  late final Index reviewQueueDue = Index(
    'review_queue_due',
    'CREATE INDEX review_queue_due ON review_queue (due)',
  );
  late final Index practiceSessionsStart = Index(
    'practice_sessions_start',
    'CREATE INDEX practice_sessions_start ON practice_sessions (start)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    attempts,
    wordResults,
    soundStats,
    reviewQueue,
    userProfileTable,
    levelChanges,
    practiceSessions,
    attemptsAt,
    attemptsPassage,
    reviewQueueDue,
    practiceSessionsStart,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'attempts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('word_results', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  required String id,
  required String passageId,
  required DateTime at,
  required int overall,
  required int accuracy,
  required int fluency,
  Value<String?> audioPath,
  required ModelTier tier,
  Value<int> rowid,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<String> id,
  Value<String> passageId,
  Value<DateTime> at,
  Value<int> overall,
  Value<int> accuracy,
  Value<int> fluency,
  Value<String?> audioPath,
  Value<ModelTier> tier,
  Value<int> rowid,
});

final class $$AttemptsTableReferences
    extends BaseReferences<_$ProgressDatabase, $AttemptsTable, AttemptRow> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WordResultsTable, List<WordResultsRow>>
  _wordResultsRefsTable(_$ProgressDatabase db) => MultiTypedResultKey.fromTable(
    db.wordResults,
    aliasName: 'attempts__id__word_results__attempt_id',
  );

  $$WordResultsTableProcessedTableManager get wordResultsRefs {
    final manager = $$WordResultsTableTableManager(
      $_db,
      $_db.wordResults,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wordResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttemptsTableFilterComposer
    extends Composer<_$ProgressDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fluency => $composableBuilder(
    column: $table.fluency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ModelTier, ModelTier, String> get tier =>
      $composableBuilder(
        column: $table.tier,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> wordResultsRefs(
    Expression<bool> Function($$WordResultsTableFilterComposer f) f,
  ) {
    final $$WordResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordResults,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordResultsTableFilterComposer(
            $db: $db,
            $table: $db.wordResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fluency => $composableBuilder(
    column: $table.fluency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get passageId =>
      $composableBuilder(column: $table.passageId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get overall =>
      $composableBuilder(column: $table.overall, builder: (column) => column);

  GeneratedColumn<int> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<int> get fluency =>
      $composableBuilder(column: $table.fluency, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ModelTier, String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  Expression<T> wordResultsRefs<T extends Object>(
    Expression<T> Function($$WordResultsTableAnnotationComposer a) f,
  ) {
    final $$WordResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wordResults,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.wordResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (AttemptRow, $$AttemptsTableReferences),
          AttemptRow,
          PrefetchHooks Function({bool wordResultsRefs})
        > {
  $$AttemptsTableTableManager(_$ProgressDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> passageId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> overall = const Value.absent(),
                Value<int> accuracy = const Value.absent(),
                Value<int> fluency = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<ModelTier> tier = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                passageId: passageId,
                at: at,
                overall: overall,
                accuracy: accuracy,
                fluency: fluency,
                audioPath: audioPath,
                tier: tier,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String passageId,
                required DateTime at,
                required int overall,
                required int accuracy,
                required int fluency,
                Value<String?> audioPath = const Value.absent(),
                required ModelTier tier,
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                passageId: passageId,
                at: at,
                overall: overall,
                accuracy: accuracy,
                fluency: fluency,
                audioPath: audioPath,
                tier: tier,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, AttemptRow>(table),
                  $$AttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordResultsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (wordResultsRefs) db.wordResults],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wordResultsRefs)
                    await $_getPrefetchedData<
                      AttemptRow,
                      $AttemptsTable,
                      WordResultsRow
                    >(
                      currentTable: table,
                      referencedTable: $$AttemptsTableReferences
                          ._wordResultsRefsTable(db),
                      managerFromTypedResult: (p0) => $$AttemptsTableReferences(
                        db,
                        table,
                        p0,
                      ).wordResultsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.attemptId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, $$AttemptsTableReferences),
      AttemptRow,
      PrefetchHooks Function({bool wordResultsRefs})
    >;
typedef $$WordResultsTableCreateCompanionBuilder =
    WordResultsCompanion Function({
      required String attemptId,
      required List<WordResult> words,
      Value<int> rowid,
    });
typedef $$WordResultsTableUpdateCompanionBuilder =
    WordResultsCompanion Function({
      Value<String> attemptId,
      Value<List<WordResult>> words,
      Value<int> rowid,
    });

final class $$WordResultsTableReferences
    extends
        BaseReferences<_$ProgressDatabase, $WordResultsTable, WordResultsRow> {
  $$WordResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AttemptsTable _attemptIdTable(_$ProgressDatabase db) =>
      db.attempts.createAlias('word_results__attempt_id__attempts__id');

  $$AttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WordResultsTableFilterComposer
    extends Composer<_$ProgressDatabase, $WordResultsTable> {
  $$WordResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<List<WordResult>, List<WordResult>, Uint8List>
  get words => $composableBuilder(
    column: $table.words,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$AttemptsTableFilterComposer get attemptId {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordResultsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $WordResultsTable> {
  $$WordResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get words => $composableBuilder(
    column: $table.words,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttemptsTableOrderingComposer get attemptId {
    final $$AttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordResultsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $WordResultsTable> {
  $$WordResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<List<WordResult>, Uint8List> get words =>
      $composableBuilder(column: $table.words, builder: (column) => column);

  $$AttemptsTableAnnotationComposer get attemptId {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WordResultsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $WordResultsTable,
          WordResultsRow,
          $$WordResultsTableFilterComposer,
          $$WordResultsTableOrderingComposer,
          $$WordResultsTableAnnotationComposer,
          $$WordResultsTableCreateCompanionBuilder,
          $$WordResultsTableUpdateCompanionBuilder,
          (WordResultsRow, $$WordResultsTableReferences),
          WordResultsRow,
          PrefetchHooks Function({bool attemptId})
        > {
  $$WordResultsTableTableManager(_$ProgressDatabase db, $WordResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> attemptId = const Value.absent(),
                Value<List<WordResult>> words = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordResultsCompanion(
                attemptId: attemptId,
                words: words,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String attemptId,
                required List<WordResult> words,
                Value<int> rowid = const Value.absent(),
              }) => WordResultsCompanion.insert(
                attemptId: attemptId,
                words: words,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordResultsTable, WordResultsRow>(table),
                  $$WordResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (attemptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attemptId,
                        referencedTable: $$WordResultsTableReferences
                            ._attemptIdTable(db),
                        referencedColumn: $$WordResultsTableReferences
                            ._attemptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WordResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $WordResultsTable,
      WordResultsRow,
      $$WordResultsTableFilterComposer,
      $$WordResultsTableOrderingComposer,
      $$WordResultsTableAnnotationComposer,
      $$WordResultsTableCreateCompanionBuilder,
      $$WordResultsTableUpdateCompanionBuilder,
      (WordResultsRow, $$WordResultsTableReferences),
      WordResultsRow,
      PrefetchHooks Function({bool attemptId})
    >;
typedef $$SoundStatsTableCreateCompanionBuilder = SoundStatsCompanion Function({
  required String ipa,
  required double accuracy,
  required int attempts,
  required DateTime lastPractised,
  Value<int> rowid,
});
typedef $$SoundStatsTableUpdateCompanionBuilder = SoundStatsCompanion Function({
  Value<String> ipa,
  Value<double> accuracy,
  Value<int> attempts,
  Value<DateTime> lastPractised,
  Value<int> rowid,
});

class $$SoundStatsTableFilterComposer
    extends Composer<_$ProgressDatabase, $SoundStatsTable> {
  $$SoundStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get lastPractised =>
      $composableBuilder(
        column: $table.lastPractised,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SoundStatsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $SoundStatsTable> {
  $$SoundStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ipa => $composableBuilder(
    column: $table.ipa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPractised => $composableBuilder(
    column: $table.lastPractised,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SoundStatsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $SoundStatsTable> {
  $$SoundStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ipa =>
      $composableBuilder(column: $table.ipa, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get lastPractised =>
      $composableBuilder(
        column: $table.lastPractised,
        builder: (column) => column,
      );
}

class $$SoundStatsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $SoundStatsTable,
          SoundStatRow,
          $$SoundStatsTableFilterComposer,
          $$SoundStatsTableOrderingComposer,
          $$SoundStatsTableAnnotationComposer,
          $$SoundStatsTableCreateCompanionBuilder,
          $$SoundStatsTableUpdateCompanionBuilder,
          (
            SoundStatRow,
            BaseReferences<_$ProgressDatabase, $SoundStatsTable, SoundStatRow>,
          ),
          SoundStatRow,
          PrefetchHooks Function()
        > {
  $$SoundStatsTableTableManager(_$ProgressDatabase db, $SoundStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SoundStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SoundStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SoundStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ipa = const Value.absent(),
                Value<double> accuracy = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> lastPractised = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SoundStatsCompanion(
                ipa: ipa,
                accuracy: accuracy,
                attempts: attempts,
                lastPractised: lastPractised,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ipa,
                required double accuracy,
                required int attempts,
                required DateTime lastPractised,
                Value<int> rowid = const Value.absent(),
              }) => SoundStatsCompanion.insert(
                ipa: ipa,
                accuracy: accuracy,
                attempts: attempts,
                lastPractised: lastPractised,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SoundStatsTable, SoundStatRow>(table),
                  BaseReferences<
                    _$ProgressDatabase,
                    $SoundStatsTable,
                    SoundStatRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SoundStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $SoundStatsTable,
      SoundStatRow,
      $$SoundStatsTableFilterComposer,
      $$SoundStatsTableOrderingComposer,
      $$SoundStatsTableAnnotationComposer,
      $$SoundStatsTableCreateCompanionBuilder,
      $$SoundStatsTableUpdateCompanionBuilder,
      (
        SoundStatRow,
        BaseReferences<_$ProgressDatabase, $SoundStatsTable, SoundStatRow>,
      ),
      SoundStatRow,
      PrefetchHooks Function()
    >;
typedef $$ReviewQueueTableCreateCompanionBuilder =
    ReviewQueueCompanion Function({
      required String wordKey,
      required String word,
      required List<PhonemeSpec> phonemes,
      required DateTime due,
      required int intervalDays,
      required double ease,
      required int stage,
      Value<int?> lastScore,
      Value<String?> passageId,
      Value<int> rowid,
    });
typedef $$ReviewQueueTableUpdateCompanionBuilder =
    ReviewQueueCompanion Function({
      Value<String> wordKey,
      Value<String> word,
      Value<List<PhonemeSpec>> phonemes,
      Value<DateTime> due,
      Value<int> intervalDays,
      Value<double> ease,
      Value<int> stage,
      Value<int?> lastScore,
      Value<String?> passageId,
      Value<int> rowid,
    });

class $$ReviewQueueTableFilterComposer
    extends Composer<_$ProgressDatabase, $ReviewQueueTable> {
  $$ReviewQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<PhonemeSpec>, List<PhonemeSpec>, String>
  get phonemes => $composableBuilder(
    column: $table.phonemes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get due =>
      $composableBuilder(
        column: $table.due,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScore => $composableBuilder(
    column: $table.lastScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewQueueTableOrderingComposer
    extends Composer<_$ProgressDatabase, $ReviewQueueTable> {
  $$ReviewQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonemes => $composableBuilder(
    column: $table.phonemes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScore => $composableBuilder(
    column: $table.lastScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewQueueTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $ReviewQueueTable> {
  $$ReviewQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<PhonemeSpec>, String> get phonemes =>
      $composableBuilder(column: $table.phonemes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ease =>
      $composableBuilder(column: $table.ease, builder: (column) => column);

  GeneratedColumn<int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get lastScore =>
      $composableBuilder(column: $table.lastScore, builder: (column) => column);

  GeneratedColumn<String> get passageId =>
      $composableBuilder(column: $table.passageId, builder: (column) => column);
}

class $$ReviewQueueTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $ReviewQueueTable,
          ReviewRow,
          $$ReviewQueueTableFilterComposer,
          $$ReviewQueueTableOrderingComposer,
          $$ReviewQueueTableAnnotationComposer,
          $$ReviewQueueTableCreateCompanionBuilder,
          $$ReviewQueueTableUpdateCompanionBuilder,
          (
            ReviewRow,
            BaseReferences<_$ProgressDatabase, $ReviewQueueTable, ReviewRow>,
          ),
          ReviewRow,
          PrefetchHooks Function()
        > {
  $$ReviewQueueTableTableManager(_$ProgressDatabase db, $ReviewQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordKey = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<List<PhonemeSpec>> phonemes = const Value.absent(),
                Value<DateTime> due = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int?> lastScore = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewQueueCompanion(
                wordKey: wordKey,
                word: word,
                phonemes: phonemes,
                due: due,
                intervalDays: intervalDays,
                ease: ease,
                stage: stage,
                lastScore: lastScore,
                passageId: passageId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordKey,
                required String word,
                required List<PhonemeSpec> phonemes,
                required DateTime due,
                required int intervalDays,
                required double ease,
                required int stage,
                Value<int?> lastScore = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewQueueCompanion.insert(
                wordKey: wordKey,
                word: word,
                phonemes: phonemes,
                due: due,
                intervalDays: intervalDays,
                ease: ease,
                stage: stage,
                lastScore: lastScore,
                passageId: passageId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewQueueTable, ReviewRow>(table),
                  BaseReferences<
                    _$ProgressDatabase,
                    $ReviewQueueTable,
                    ReviewRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $ReviewQueueTable,
      ReviewRow,
      $$ReviewQueueTableFilterComposer,
      $$ReviewQueueTableOrderingComposer,
      $$ReviewQueueTableAnnotationComposer,
      $$ReviewQueueTableCreateCompanionBuilder,
      $$ReviewQueueTableUpdateCompanionBuilder,
      (
        ReviewRow,
        BaseReferences<_$ProgressDatabase, $ReviewQueueTable, ReviewRow>,
      ),
      ReviewRow,
      PrefetchHooks Function()
    >;
typedef $$UserProfileTableTableCreateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      required int level,
      required int dailyGoalMinutes,
      required int streak,
      Value<DateTime?> lastPractice,
      required bool keepRecordings,
      required bool placementDone,
      Value<int?> placementLevel,
      Value<int?> reminderMinutes,
      required double textScale,
      Value<ModelTier?> tierOverride,
      required bool onboardingDone,
    });
typedef $$UserProfileTableTableUpdateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      Value<int> level,
      Value<int> dailyGoalMinutes,
      Value<int> streak,
      Value<DateTime?> lastPractice,
      Value<bool> keepRecordings,
      Value<bool> placementDone,
      Value<int?> placementLevel,
      Value<int?> reminderMinutes,
      Value<double> textScale,
      Value<ModelTier?> tierOverride,
      Value<bool> onboardingDone,
    });

class $$UserProfileTableTableFilterComposer
    extends Composer<_$ProgressDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyGoalMinutes => $composableBuilder(
    column: $table.dailyGoalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastPractice =>
      $composableBuilder(
        column: $table.lastPractice,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get keepRecordings => $composableBuilder(
    column: $table.keepRecordings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get placementDone => $composableBuilder(
    column: $table.placementDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get placementLevel => $composableBuilder(
    column: $table.placementLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ModelTier?, ModelTier, String>
  get tierOverride => $composableBuilder(
    column: $table.tierOverride,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableTableOrderingComposer
    extends Composer<_$ProgressDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyGoalMinutes => $composableBuilder(
    column: $table.dailyGoalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPractice => $composableBuilder(
    column: $table.lastPractice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepRecordings => $composableBuilder(
    column: $table.keepRecordings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get placementDone => $composableBuilder(
    column: $table.placementDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get placementLevel => $composableBuilder(
    column: $table.placementLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tierOverride => $composableBuilder(
    column: $table.tierOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get dailyGoalMinutes => $composableBuilder(
    column: $table.dailyGoalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastPractice =>
      $composableBuilder(
        column: $table.lastPractice,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get keepRecordings => $composableBuilder(
    column: $table.keepRecordings,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get placementDone => $composableBuilder(
    column: $table.placementDone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get placementLevel => $composableBuilder(
    column: $table.placementLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get textScale =>
      $composableBuilder(column: $table.textScale, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ModelTier?, String> get tierOverride =>
      $composableBuilder(
        column: $table.tierOverride,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => column,
  );
}

class $$UserProfileTableTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $UserProfileTableTable,
          ProfileRow,
          $$UserProfileTableTableFilterComposer,
          $$UserProfileTableTableOrderingComposer,
          $$UserProfileTableTableAnnotationComposer,
          $$UserProfileTableTableCreateCompanionBuilder,
          $$UserProfileTableTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<
              _$ProgressDatabase,
              $UserProfileTableTable,
              ProfileRow
            >,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableTableManager(
    _$ProgressDatabase db,
    $UserProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> dailyGoalMinutes = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastPractice = const Value.absent(),
                Value<bool> keepRecordings = const Value.absent(),
                Value<bool> placementDone = const Value.absent(),
                Value<int?> placementLevel = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<ModelTier?> tierOverride = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
              }) => UserProfileTableCompanion(
                id: id,
                level: level,
                dailyGoalMinutes: dailyGoalMinutes,
                streak: streak,
                lastPractice: lastPractice,
                keepRecordings: keepRecordings,
                placementDone: placementDone,
                placementLevel: placementLevel,
                reminderMinutes: reminderMinutes,
                textScale: textScale,
                tierOverride: tierOverride,
                onboardingDone: onboardingDone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int level,
                required int dailyGoalMinutes,
                required int streak,
                Value<DateTime?> lastPractice = const Value.absent(),
                required bool keepRecordings,
                required bool placementDone,
                Value<int?> placementLevel = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                required double textScale,
                Value<ModelTier?> tierOverride = const Value.absent(),
                required bool onboardingDone,
              }) => UserProfileTableCompanion.insert(
                id: id,
                level: level,
                dailyGoalMinutes: dailyGoalMinutes,
                streak: streak,
                lastPractice: lastPractice,
                keepRecordings: keepRecordings,
                placementDone: placementDone,
                placementLevel: placementLevel,
                reminderMinutes: reminderMinutes,
                textScale: textScale,
                tierOverride: tierOverride,
                onboardingDone: onboardingDone,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfileTableTable, ProfileRow>(table),
                  BaseReferences<
                    _$ProgressDatabase,
                    $UserProfileTableTable,
                    ProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $UserProfileTableTable,
      ProfileRow,
      $$UserProfileTableTableFilterComposer,
      $$UserProfileTableTableOrderingComposer,
      $$UserProfileTableTableAnnotationComposer,
      $$UserProfileTableTableCreateCompanionBuilder,
      $$UserProfileTableTableUpdateCompanionBuilder,
      (
        ProfileRow,
        BaseReferences<_$ProgressDatabase, $UserProfileTableTable, ProfileRow>,
      ),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$LevelChangesTableCreateCompanionBuilder =
    LevelChangesCompanion Function({
      Value<int> id,
      required int fromLevel,
      required int toLevel,
      required String reason,
      required DateTime at,
    });
typedef $$LevelChangesTableUpdateCompanionBuilder =
    LevelChangesCompanion Function({
      Value<int> id,
      Value<int> fromLevel,
      Value<int> toLevel,
      Value<String> reason,
      Value<DateTime> at,
    });

class $$LevelChangesTableFilterComposer
    extends Composer<_$ProgressDatabase, $LevelChangesTable> {
  $$LevelChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromLevel => $composableBuilder(
    column: $table.fromLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toLevel => $composableBuilder(
    column: $table.toLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$LevelChangesTableOrderingComposer
    extends Composer<_$ProgressDatabase, $LevelChangesTable> {
  $$LevelChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromLevel => $composableBuilder(
    column: $table.fromLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toLevel => $composableBuilder(
    column: $table.toLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LevelChangesTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $LevelChangesTable> {
  $$LevelChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fromLevel =>
      $composableBuilder(column: $table.fromLevel, builder: (column) => column);

  GeneratedColumn<int> get toLevel =>
      $composableBuilder(column: $table.toLevel, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$LevelChangesTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $LevelChangesTable,
          LevelChangeRow,
          $$LevelChangesTableFilterComposer,
          $$LevelChangesTableOrderingComposer,
          $$LevelChangesTableAnnotationComposer,
          $$LevelChangesTableCreateCompanionBuilder,
          $$LevelChangesTableUpdateCompanionBuilder,
          (
            LevelChangeRow,
            BaseReferences<
              _$ProgressDatabase,
              $LevelChangesTable,
              LevelChangeRow
            >,
          ),
          LevelChangeRow,
          PrefetchHooks Function()
        > {
  $$LevelChangesTableTableManager(
    _$ProgressDatabase db,
    $LevelChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LevelChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LevelChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LevelChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fromLevel = const Value.absent(),
                Value<int> toLevel = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => LevelChangesCompanion(
                id: id,
                fromLevel: fromLevel,
                toLevel: toLevel,
                reason: reason,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fromLevel,
                required int toLevel,
                required String reason,
                required DateTime at,
              }) => LevelChangesCompanion.insert(
                id: id,
                fromLevel: fromLevel,
                toLevel: toLevel,
                reason: reason,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LevelChangesTable, LevelChangeRow>(table),
                  BaseReferences<
                    _$ProgressDatabase,
                    $LevelChangesTable,
                    LevelChangeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LevelChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $LevelChangesTable,
      LevelChangeRow,
      $$LevelChangesTableFilterComposer,
      $$LevelChangesTableOrderingComposer,
      $$LevelChangesTableAnnotationComposer,
      $$LevelChangesTableCreateCompanionBuilder,
      $$LevelChangesTableUpdateCompanionBuilder,
      (
        LevelChangeRow,
        BaseReferences<_$ProgressDatabase, $LevelChangesTable, LevelChangeRow>,
      ),
      LevelChangeRow,
      PrefetchHooks Function()
    >;
typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      required DateTime start,
      required int durationUs,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      Value<DateTime> start,
      Value<int> durationUs,
    });

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$ProgressDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get start =>
      $composableBuilder(
        column: $table.start,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get durationUs => $composableBuilder(
    column: $table.durationUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$ProgressDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationUs => $composableBuilder(
    column: $table.durationUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$ProgressDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<int> get durationUs => $composableBuilder(
    column: $table.durationUs,
    builder: (column) => column,
  );
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$ProgressDatabase,
          $PracticeSessionsTable,
          PracticeSessionRow,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (
            PracticeSessionRow,
            BaseReferences<
              _$ProgressDatabase,
              $PracticeSessionsTable,
              PracticeSessionRow
            >,
          ),
          PracticeSessionRow,
          PrefetchHooks Function()
        > {
  $$PracticeSessionsTableTableManager(
    _$ProgressDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<int> durationUs = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                start: start,
                durationUs: durationUs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime start,
                required int durationUs,
              }) => PracticeSessionsCompanion.insert(
                id: id,
                start: start,
                durationUs: durationUs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeSessionsTable, PracticeSessionRow>(
                    table,
                  ),
                  BaseReferences<
                    _$ProgressDatabase,
                    $PracticeSessionsTable,
                    PracticeSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ProgressDatabase,
      $PracticeSessionsTable,
      PracticeSessionRow,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (
        PracticeSessionRow,
        BaseReferences<
          _$ProgressDatabase,
          $PracticeSessionsTable,
          PracticeSessionRow
        >,
      ),
      PracticeSessionRow,
      PrefetchHooks Function()
    >;

class $ProgressDatabaseManager {
  final _$ProgressDatabase _db;
  $ProgressDatabaseManager(this._db);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$WordResultsTableTableManager get wordResults =>
      $$WordResultsTableTableManager(_db, _db.wordResults);
  $$SoundStatsTableTableManager get soundStats =>
      $$SoundStatsTableTableManager(_db, _db.soundStats);
  $$ReviewQueueTableTableManager get reviewQueue =>
      $$ReviewQueueTableTableManager(_db, _db.reviewQueue);
  $$UserProfileTableTableTableManager get userProfileTable =>
      $$UserProfileTableTableTableManager(_db, _db.userProfileTable);
  $$LevelChangesTableTableManager get levelChanges =>
      $$LevelChangesTableTableManager(_db, _db.levelChanges);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
}
