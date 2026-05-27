// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    durationMs,
    transcript,
    modelId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    } else if (isInserting) {
      context.missing(_transcriptMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;

  /// Unix epoch milliseconds, UTC. Drives default sort and timestamp display.
  final int createdAt;

  /// Length of the original recording, in milliseconds.
  final int durationMs;

  /// The transcribed text (single paragraph; whisper line breaks collapsed).
  final String transcript;

  /// Which whisper model produced this transcript (e.g. `ggml-tiny.en`).
  final String modelId;
  const Note({
    required this.id,
    required this.createdAt,
    required this.durationMs,
    required this.transcript,
    required this.modelId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['transcript'] = Variable<String>(transcript);
    map['model_id'] = Variable<String>(modelId);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      durationMs: Value(durationMs),
      transcript: Value(transcript),
      modelId: Value(modelId),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      transcript: serializer.fromJson<String>(json['transcript']),
      modelId: serializer.fromJson<String>(json['modelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'transcript': serializer.toJson<String>(transcript),
      'modelId': serializer.toJson<String>(modelId),
    };
  }

  Note copyWith({
    int? id,
    int? createdAt,
    int? durationMs,
    String? transcript,
    String? modelId,
  }) => Note(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    durationMs: durationMs ?? this.durationMs,
    transcript: transcript ?? this.transcript,
    modelId: modelId ?? this.modelId,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('transcript: $transcript, ')
          ..write('modelId: $modelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, durationMs, transcript, modelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.durationMs == this.durationMs &&
          other.transcript == this.transcript &&
          other.modelId == this.modelId);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<int> createdAt;
  final Value<int> durationMs;
  final Value<String> transcript;
  final Value<String> modelId;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.transcript = const Value.absent(),
    this.modelId = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required int createdAt,
    required int durationMs,
    required String transcript,
    required String modelId,
  }) : createdAt = Value(createdAt),
       durationMs = Value(durationMs),
       transcript = Value(transcript),
       modelId = Value(modelId);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<int>? createdAt,
    Expression<int>? durationMs,
    Expression<String>? transcript,
    Expression<String>? modelId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (transcript != null) 'transcript': transcript,
      if (modelId != null) 'model_id': modelId,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<int>? createdAt,
    Value<int>? durationMs,
    Value<String>? transcript,
    Value<String>? modelId,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      transcript: transcript ?? this.transcript,
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('transcript: $transcript, ')
          ..write('modelId: $modelId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notes];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      required int createdAt,
      required int durationMs,
      required String transcript,
      required String modelId,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<int> createdAt,
      Value<int> durationMs,
      Value<String> transcript,
      Value<String> modelId,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> transcript = const Value.absent(),
                Value<String> modelId = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                createdAt: createdAt,
                durationMs: durationMs,
                transcript: transcript,
                modelId: modelId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int createdAt,
                required int durationMs,
                required String transcript,
                required String modelId,
              }) => NotesCompanion.insert(
                id: id,
                createdAt: createdAt,
                durationMs: durationMs,
                transcript: transcript,
                modelId: modelId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
}
