// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $LocalAccountsTable extends LocalAccounts
    with TableInfo<$LocalAccountsTable, LocalAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, email, lastOpenedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  LocalAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAccount(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
    );
  }

  @override
  $LocalAccountsTable createAlias(String alias) {
    return $LocalAccountsTable(attachedDatabase, alias);
  }
}

class LocalAccount extends DataClass implements Insertable<LocalAccount> {
  final String userId;
  final String? email;
  final DateTime lastOpenedAt;
  const LocalAccount({
    required this.userId,
    this.email,
    required this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    return map;
  }

  LocalAccountsCompanion toCompanion(bool nullToAbsent) {
    return LocalAccountsCompanion(
      userId: Value(userId),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      lastOpenedAt: Value(lastOpenedAt),
    );
  }

  factory LocalAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAccount(
      userId: serializer.fromJson<String>(json['userId']),
      email: serializer.fromJson<String?>(json['email']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'email': serializer.toJson<String?>(email),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
    };
  }

  LocalAccount copyWith({
    String? userId,
    Value<String?> email = const Value.absent(),
    DateTime? lastOpenedAt,
  }) => LocalAccount(
    userId: userId ?? this.userId,
    email: email.present ? email.value : this.email,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );
  LocalAccount copyWithCompanion(LocalAccountsCompanion data) {
    return LocalAccount(
      userId: data.userId.present ? data.userId.value : this.userId,
      email: data.email.present ? data.email.value : this.email,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccount(')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, email, lastOpenedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAccount &&
          other.userId == this.userId &&
          other.email == this.email &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class LocalAccountsCompanion extends UpdateCompanion<LocalAccount> {
  final Value<String> userId;
  final Value<String?> email;
  final Value<DateTime> lastOpenedAt;
  final Value<int> rowid;
  const LocalAccountsCompanion({
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAccountsCompanion.insert({
    required String userId,
    this.email = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<LocalAccount> custom({
    Expression<String>? userId,
    Expression<String>? email,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (email != null) 'email': email,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAccountsCompanion copyWith({
    Value<String>? userId,
    Value<String?>? email,
    Value<DateTime>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return LocalAccountsCompanion(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountsCompanion(')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProjectsTable extends LocalProjects
    with TableInfo<$LocalProjectsTable, LocalProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registryJsonMeta = const VerificationMeta(
    'registryJson',
  );
  @override
  late final GeneratedColumn<String> registryJson = GeneratedColumn<String>(
    'registry_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rulesJsonMeta = const VerificationMeta(
    'rulesJson',
  );
  @override
  late final GeneratedColumn<String> rulesJson = GeneratedColumn<String>(
    'rules_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('updated'),
  );
  static const VerificationMeta _offlineEnabledMeta = const VerificationMeta(
    'offlineEnabled',
  );
  @override
  late final GeneratedColumn<bool> offlineEnabled = GeneratedColumn<bool>(
    'offline_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("offline_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    summaryJson,
    snapshotJson,
    registryJson,
    rulesJson,
    revision,
    syncState,
    offlineEnabled,
    byteSize,
    syncedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('registry_json')) {
      context.handle(
        _registryJsonMeta,
        registryJson.isAcceptableOrUnknown(
          data['registry_json']!,
          _registryJsonMeta,
        ),
      );
    }
    if (data.containsKey('rules_json')) {
      context.handle(
        _rulesJsonMeta,
        rulesJson.isAcceptableOrUnknown(data['rules_json']!, _rulesJsonMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('offline_enabled')) {
      context.handle(
        _offlineEnabledMeta,
        offlineEnabled.isAcceptableOrUnknown(
          data['offline_enabled']!,
          _offlineEnabledMeta,
        ),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId};
  @override
  LocalProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProject(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      ),
      registryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registry_json'],
      ),
      rulesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules_json'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      offlineEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}offline_enabled'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LocalProjectsTable createAlias(String alias) {
    return $LocalProjectsTable(attachedDatabase, alias);
  }
}

class LocalProject extends DataClass implements Insertable<LocalProject> {
  final String userId;
  final String projectId;
  final String summaryJson;
  final String? snapshotJson;
  final String? registryJson;
  final String? rulesJson;
  final int revision;
  final String syncState;
  final bool offlineEnabled;
  final int byteSize;
  final DateTime? syncedAt;
  final DateTime? updatedAt;
  const LocalProject({
    required this.userId,
    required this.projectId,
    required this.summaryJson,
    this.snapshotJson,
    this.registryJson,
    this.rulesJson,
    required this.revision,
    required this.syncState,
    required this.offlineEnabled,
    required this.byteSize,
    this.syncedAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['summary_json'] = Variable<String>(summaryJson);
    if (!nullToAbsent || snapshotJson != null) {
      map['snapshot_json'] = Variable<String>(snapshotJson);
    }
    if (!nullToAbsent || registryJson != null) {
      map['registry_json'] = Variable<String>(registryJson);
    }
    if (!nullToAbsent || rulesJson != null) {
      map['rules_json'] = Variable<String>(rulesJson);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_state'] = Variable<String>(syncState);
    map['offline_enabled'] = Variable<bool>(offlineEnabled);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LocalProjectsCompanion toCompanion(bool nullToAbsent) {
    return LocalProjectsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      summaryJson: Value(summaryJson),
      snapshotJson: snapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshotJson),
      registryJson: registryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(registryJson),
      rulesJson: rulesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rulesJson),
      revision: Value(revision),
      syncState: Value(syncState),
      offlineEnabled: Value(offlineEnabled),
      byteSize: Value(byteSize),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProject(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      snapshotJson: serializer.fromJson<String?>(json['snapshotJson']),
      registryJson: serializer.fromJson<String?>(json['registryJson']),
      rulesJson: serializer.fromJson<String?>(json['rulesJson']),
      revision: serializer.fromJson<int>(json['revision']),
      syncState: serializer.fromJson<String>(json['syncState']),
      offlineEnabled: serializer.fromJson<bool>(json['offlineEnabled']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'snapshotJson': serializer.toJson<String?>(snapshotJson),
      'registryJson': serializer.toJson<String?>(registryJson),
      'rulesJson': serializer.toJson<String?>(rulesJson),
      'revision': serializer.toJson<int>(revision),
      'syncState': serializer.toJson<String>(syncState),
      'offlineEnabled': serializer.toJson<bool>(offlineEnabled),
      'byteSize': serializer.toJson<int>(byteSize),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LocalProject copyWith({
    String? userId,
    String? projectId,
    String? summaryJson,
    Value<String?> snapshotJson = const Value.absent(),
    Value<String?> registryJson = const Value.absent(),
    Value<String?> rulesJson = const Value.absent(),
    int? revision,
    String? syncState,
    bool? offlineEnabled,
    int? byteSize,
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => LocalProject(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    summaryJson: summaryJson ?? this.summaryJson,
    snapshotJson: snapshotJson.present ? snapshotJson.value : this.snapshotJson,
    registryJson: registryJson.present ? registryJson.value : this.registryJson,
    rulesJson: rulesJson.present ? rulesJson.value : this.rulesJson,
    revision: revision ?? this.revision,
    syncState: syncState ?? this.syncState,
    offlineEnabled: offlineEnabled ?? this.offlineEnabled,
    byteSize: byteSize ?? this.byteSize,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  LocalProject copyWithCompanion(LocalProjectsCompanion data) {
    return LocalProject(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      registryJson: data.registryJson.present
          ? data.registryJson.value
          : this.registryJson,
      rulesJson: data.rulesJson.present ? data.rulesJson.value : this.rulesJson,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      offlineEnabled: data.offlineEnabled.present
          ? data.offlineEnabled.value
          : this.offlineEnabled,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProject(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('registryJson: $registryJson, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('revision: $revision, ')
          ..write('syncState: $syncState, ')
          ..write('offlineEnabled: $offlineEnabled, ')
          ..write('byteSize: $byteSize, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    projectId,
    summaryJson,
    snapshotJson,
    registryJson,
    rulesJson,
    revision,
    syncState,
    offlineEnabled,
    byteSize,
    syncedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProject &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.summaryJson == this.summaryJson &&
          other.snapshotJson == this.snapshotJson &&
          other.registryJson == this.registryJson &&
          other.rulesJson == this.rulesJson &&
          other.revision == this.revision &&
          other.syncState == this.syncState &&
          other.offlineEnabled == this.offlineEnabled &&
          other.byteSize == this.byteSize &&
          other.syncedAt == this.syncedAt &&
          other.updatedAt == this.updatedAt);
}

class LocalProjectsCompanion extends UpdateCompanion<LocalProject> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> summaryJson;
  final Value<String?> snapshotJson;
  final Value<String?> registryJson;
  final Value<String?> rulesJson;
  final Value<int> revision;
  final Value<String> syncState;
  final Value<bool> offlineEnabled;
  final Value<int> byteSize;
  final Value<DateTime?> syncedAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const LocalProjectsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.registryJson = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncState = const Value.absent(),
    this.offlineEnabled = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProjectsCompanion.insert({
    required String userId,
    required String projectId,
    required String summaryJson,
    this.snapshotJson = const Value.absent(),
    this.registryJson = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncState = const Value.absent(),
    this.offlineEnabled = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       summaryJson = Value(summaryJson);
  static Insertable<LocalProject> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? summaryJson,
    Expression<String>? snapshotJson,
    Expression<String>? registryJson,
    Expression<String>? rulesJson,
    Expression<int>? revision,
    Expression<String>? syncState,
    Expression<bool>? offlineEnabled,
    Expression<int>? byteSize,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (registryJson != null) 'registry_json': registryJson,
      if (rulesJson != null) 'rules_json': rulesJson,
      if (revision != null) 'revision': revision,
      if (syncState != null) 'sync_state': syncState,
      if (offlineEnabled != null) 'offline_enabled': offlineEnabled,
      if (byteSize != null) 'byte_size': byteSize,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProjectsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? summaryJson,
    Value<String?>? snapshotJson,
    Value<String?>? registryJson,
    Value<String?>? rulesJson,
    Value<int>? revision,
    Value<String>? syncState,
    Value<bool>? offlineEnabled,
    Value<int>? byteSize,
    Value<DateTime?>? syncedAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalProjectsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      summaryJson: summaryJson ?? this.summaryJson,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      registryJson: registryJson ?? this.registryJson,
      rulesJson: rulesJson ?? this.rulesJson,
      revision: revision ?? this.revision,
      syncState: syncState ?? this.syncState,
      offlineEnabled: offlineEnabled ?? this.offlineEnabled,
      byteSize: byteSize ?? this.byteSize,
      syncedAt: syncedAt ?? this.syncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (registryJson.present) {
      map['registry_json'] = Variable<String>(registryJson.value);
    }
    if (rulesJson.present) {
      map['rules_json'] = Variable<String>(rulesJson.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (offlineEnabled.present) {
      map['offline_enabled'] = Variable<bool>(offlineEnabled.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProjectsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('registryJson: $registryJson, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('revision: $revision, ')
          ..write('syncState: $syncState, ')
          ..write('offlineEnabled: $offlineEnabled, ')
          ..write('byteSize: $byteSize, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRulesTable extends LocalRules
    with TableInfo<$LocalRulesTable, LocalRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    version,
    checksum,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, version};
  @override
  LocalRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRule(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalRulesTable createAlias(String alias) {
    return $LocalRulesTable(attachedDatabase, alias);
  }
}

class LocalRule extends DataClass implements Insertable<LocalRule> {
  final String userId;
  final String projectId;
  final String version;
  final String checksum;
  final String payloadJson;
  final DateTime updatedAt;
  const LocalRule({
    required this.userId,
    required this.projectId,
    required this.version,
    required this.checksum,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['version'] = Variable<String>(version);
    map['checksum'] = Variable<String>(checksum);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalRulesCompanion toCompanion(bool nullToAbsent) {
    return LocalRulesCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      version: Value(version),
      checksum: Value(checksum),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRule(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      version: serializer.fromJson<String>(json['version']),
      checksum: serializer.fromJson<String>(json['checksum']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'version': serializer.toJson<String>(version),
      'checksum': serializer.toJson<String>(checksum),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalRule copyWith({
    String? userId,
    String? projectId,
    String? version,
    String? checksum,
    String? payloadJson,
    DateTime? updatedAt,
  }) => LocalRule(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    version: version ?? this.version,
    checksum: checksum ?? this.checksum,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalRule copyWithCompanion(LocalRulesCompanion data) {
    return LocalRule(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      version: data.version.present ? data.version.value : this.version,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRule(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, projectId, version, checksum, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRule &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.version == this.version &&
          other.checksum == this.checksum &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class LocalRulesCompanion extends UpdateCompanion<LocalRule> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> version;
  final Value<String> checksum;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalRulesCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.version = const Value.absent(),
    this.checksum = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRulesCompanion.insert({
    required String userId,
    required String projectId,
    required String version,
    required String checksum,
    required String payloadJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       version = Value(version),
       checksum = Value(checksum),
       payloadJson = Value(payloadJson);
  static Insertable<LocalRule> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? version,
    Expression<String>? checksum,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (version != null) 'version': version,
      if (checksum != null) 'checksum': checksum,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRulesCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? version,
    Value<String>? checksum,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalRulesCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRulesCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProposalsTable extends LocalProposals
    with TableInfo<$LocalProposalsTable, LocalProposal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProposalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proposalIdMeta = const VerificationMeta(
    'proposalId',
  );
  @override
  late final GeneratedColumn<String> proposalId = GeneratedColumn<String>(
    'proposal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    proposalId,
    payloadJson,
    state,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_proposals';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProposal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('proposal_id')) {
      context.handle(
        _proposalIdMeta,
        proposalId.isAcceptableOrUnknown(data['proposal_id']!, _proposalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_proposalIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, proposalId};
  @override
  LocalProposal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProposal(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      proposalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proposal_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalProposalsTable createAlias(String alias) {
    return $LocalProposalsTable(attachedDatabase, alias);
  }
}

class LocalProposal extends DataClass implements Insertable<LocalProposal> {
  final String userId;
  final String projectId;
  final String proposalId;
  final String payloadJson;
  final String state;
  final DateTime createdAt;
  const LocalProposal({
    required this.userId,
    required this.projectId,
    required this.proposalId,
    required this.payloadJson,
    required this.state,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['proposal_id'] = Variable<String>(proposalId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalProposalsCompanion toCompanion(bool nullToAbsent) {
    return LocalProposalsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      proposalId: Value(proposalId),
      payloadJson: Value(payloadJson),
      state: Value(state),
      createdAt: Value(createdAt),
    );
  }

  factory LocalProposal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProposal(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      proposalId: serializer.fromJson<String>(json['proposalId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'proposalId': serializer.toJson<String>(proposalId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalProposal copyWith({
    String? userId,
    String? projectId,
    String? proposalId,
    String? payloadJson,
    String? state,
    DateTime? createdAt,
  }) => LocalProposal(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    proposalId: proposalId ?? this.proposalId,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalProposal copyWithCompanion(LocalProposalsCompanion data) {
    return LocalProposal(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      proposalId: data.proposalId.present
          ? data.proposalId.value
          : this.proposalId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProposal(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('proposalId: $proposalId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, projectId, proposalId, payloadJson, state, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProposal &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.proposalId == this.proposalId &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.createdAt == this.createdAt);
}

class LocalProposalsCompanion extends UpdateCompanion<LocalProposal> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> proposalId;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalProposalsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.proposalId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProposalsCompanion.insert({
    required String userId,
    required String projectId,
    required String proposalId,
    required String payloadJson,
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       proposalId = Value(proposalId),
       payloadJson = Value(payloadJson);
  static Insertable<LocalProposal> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? proposalId,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (proposalId != null) 'proposal_id': proposalId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProposalsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? proposalId,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalProposalsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      proposalId: proposalId ?? this.proposalId,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (proposalId.present) {
      map['proposal_id'] = Variable<String>(proposalId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
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
    return (StringBuffer('LocalProposalsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('proposalId: $proposalId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOperationsTable extends LocalOperations
    with TableInfo<$LocalOperationsTable, LocalOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    operationId,
    baseRevision,
    payloadJson,
    state,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseRevisionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, operationId};
  @override
  LocalOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOperation(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalOperationsTable createAlias(String alias) {
    return $LocalOperationsTable(attachedDatabase, alias);
  }
}

class LocalOperation extends DataClass implements Insertable<LocalOperation> {
  final String userId;
  final String projectId;
  final String operationId;
  final int baseRevision;
  final String payloadJson;
  final String state;
  final DateTime createdAt;
  const LocalOperation({
    required this.userId,
    required this.projectId,
    required this.operationId,
    required this.baseRevision,
    required this.payloadJson,
    required this.state,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['operation_id'] = Variable<String>(operationId);
    map['base_revision'] = Variable<int>(baseRevision);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalOperationsCompanion toCompanion(bool nullToAbsent) {
    return LocalOperationsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      operationId: Value(operationId),
      baseRevision: Value(baseRevision),
      payloadJson: Value(payloadJson),
      state: Value(state),
      createdAt: Value(createdAt),
    );
  }

  factory LocalOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOperation(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'operationId': serializer.toJson<String>(operationId),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalOperation copyWith({
    String? userId,
    String? projectId,
    String? operationId,
    int? baseRevision,
    String? payloadJson,
    String? state,
    DateTime? createdAt,
  }) => LocalOperation(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    operationId: operationId ?? this.operationId,
    baseRevision: baseRevision ?? this.baseRevision,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalOperation copyWithCompanion(LocalOperationsCompanion data) {
    return LocalOperation(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOperation(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('operationId: $operationId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    projectId,
    operationId,
    baseRevision,
    payloadJson,
    state,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOperation &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.operationId == this.operationId &&
          other.baseRevision == this.baseRevision &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.createdAt == this.createdAt);
}

class LocalOperationsCompanion extends UpdateCompanion<LocalOperation> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> operationId;
  final Value<int> baseRevision;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalOperationsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOperationsCompanion.insert({
    required String userId,
    required String projectId,
    required String operationId,
    required int baseRevision,
    required String payloadJson,
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       operationId = Value(operationId),
       baseRevision = Value(baseRevision),
       payloadJson = Value(payloadJson);
  static Insertable<LocalOperation> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? operationId,
    Expression<int>? baseRevision,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (operationId != null) 'operation_id': operationId,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOperationsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? operationId,
    Value<int>? baseRevision,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalOperationsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      operationId: operationId ?? this.operationId,
      baseRevision: baseRevision ?? this.baseRevision,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
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
    return (StringBuffer('LocalOperationsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('operationId: $operationId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalConflictsTable extends LocalConflicts
    with TableInfo<$LocalConflictsTable, LocalConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conflictIdMeta = const VerificationMeta(
    'conflictId',
  );
  @override
  late final GeneratedColumn<String> conflictId = GeneratedColumn<String>(
    'conflict_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    conflictId,
    payloadJson,
    state,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('conflict_id')) {
      context.handle(
        _conflictIdMeta,
        conflictId.isAcceptableOrUnknown(data['conflict_id']!, _conflictIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conflictIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, conflictId};
  @override
  LocalConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConflict(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      conflictId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalConflictsTable createAlias(String alias) {
    return $LocalConflictsTable(attachedDatabase, alias);
  }
}

class LocalConflict extends DataClass implements Insertable<LocalConflict> {
  final String userId;
  final String projectId;
  final String conflictId;
  final String payloadJson;
  final String state;
  final DateTime createdAt;
  const LocalConflict({
    required this.userId,
    required this.projectId,
    required this.conflictId,
    required this.payloadJson,
    required this.state,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['conflict_id'] = Variable<String>(conflictId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalConflictsCompanion toCompanion(bool nullToAbsent) {
    return LocalConflictsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      conflictId: Value(conflictId),
      payloadJson: Value(payloadJson),
      state: Value(state),
      createdAt: Value(createdAt),
    );
  }

  factory LocalConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConflict(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      conflictId: serializer.fromJson<String>(json['conflictId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'conflictId': serializer.toJson<String>(conflictId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalConflict copyWith({
    String? userId,
    String? projectId,
    String? conflictId,
    String? payloadJson,
    String? state,
    DateTime? createdAt,
  }) => LocalConflict(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    conflictId: conflictId ?? this.conflictId,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalConflict copyWithCompanion(LocalConflictsCompanion data) {
    return LocalConflict(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      conflictId: data.conflictId.present
          ? data.conflictId.value
          : this.conflictId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConflict(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('conflictId: $conflictId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, projectId, conflictId, payloadJson, state, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConflict &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.conflictId == this.conflictId &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.createdAt == this.createdAt);
}

class LocalConflictsCompanion extends UpdateCompanion<LocalConflict> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> conflictId;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalConflictsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.conflictId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalConflictsCompanion.insert({
    required String userId,
    required String projectId,
    required String conflictId,
    required String payloadJson,
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       conflictId = Value(conflictId),
       payloadJson = Value(payloadJson);
  static Insertable<LocalConflict> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? conflictId,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (conflictId != null) 'conflict_id': conflictId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalConflictsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? conflictId,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalConflictsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      conflictId: conflictId ?? this.conflictId,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (conflictId.present) {
      map['conflict_id'] = Variable<String>(conflictId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
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
    return (StringBuffer('LocalConflictsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('conflictId: $conflictId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalManifestsTable extends LocalManifests
    with TableInfo<$LocalManifestsTable, LocalManifest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    kind,
    version,
    checksum,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalManifest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, kind};
  @override
  LocalManifest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalManifest(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalManifestsTable createAlias(String alias) {
    return $LocalManifestsTable(attachedDatabase, alias);
  }
}

class LocalManifest extends DataClass implements Insertable<LocalManifest> {
  final String userId;
  final String projectId;
  final String kind;
  final String version;
  final String checksum;
  final String payloadJson;
  final DateTime updatedAt;
  const LocalManifest({
    required this.userId,
    required this.projectId,
    required this.kind,
    required this.version,
    required this.checksum,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['kind'] = Variable<String>(kind);
    map['version'] = Variable<String>(version);
    map['checksum'] = Variable<String>(checksum);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalManifestsCompanion toCompanion(bool nullToAbsent) {
    return LocalManifestsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      kind: Value(kind),
      version: Value(version),
      checksum: Value(checksum),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalManifest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalManifest(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      version: serializer.fromJson<String>(json['version']),
      checksum: serializer.fromJson<String>(json['checksum']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'kind': serializer.toJson<String>(kind),
      'version': serializer.toJson<String>(version),
      'checksum': serializer.toJson<String>(checksum),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalManifest copyWith({
    String? userId,
    String? projectId,
    String? kind,
    String? version,
    String? checksum,
    String? payloadJson,
    DateTime? updatedAt,
  }) => LocalManifest(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    kind: kind ?? this.kind,
    version: version ?? this.version,
    checksum: checksum ?? this.checksum,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalManifest copyWithCompanion(LocalManifestsCompanion data) {
    return LocalManifest(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      version: data.version.present ? data.version.value : this.version,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalManifest(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    projectId,
    kind,
    version,
    checksum,
    payloadJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalManifest &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.version == this.version &&
          other.checksum == this.checksum &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class LocalManifestsCompanion extends UpdateCompanion<LocalManifest> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> kind;
  final Value<String> version;
  final Value<String> checksum;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalManifestsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.version = const Value.absent(),
    this.checksum = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalManifestsCompanion.insert({
    required String userId,
    this.projectId = const Value.absent(),
    required String kind,
    required String version,
    required String checksum,
    required String payloadJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       kind = Value(kind),
       version = Value(version),
       checksum = Value(checksum),
       payloadJson = Value(payloadJson);
  static Insertable<LocalManifest> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? kind,
    Expression<String>? version,
    Expression<String>? checksum,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (version != null) 'version': version,
      if (checksum != null) 'checksum': checksum,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalManifestsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? kind,
    Value<String>? version,
    Value<String>? checksum,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalManifestsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalManifestsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalArtifactsTable extends LocalArtifacts
    with TableInfo<$LocalArtifactsTable, LocalArtifact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artifactIdMeta = const VerificationMeta(
    'artifactId',
  );
  @override
  late final GeneratedColumn<String> artifactId = GeneratedColumn<String>(
    'artifact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    artifactId,
    kind,
    path,
    checksum,
    byteSize,
    state,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_artifacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalArtifact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('artifact_id')) {
      context.handle(
        _artifactIdMeta,
        artifactId.isAcceptableOrUnknown(data['artifact_id']!, _artifactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artifactIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, artifactId};
  @override
  LocalArtifact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalArtifact(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      artifactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artifact_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalArtifactsTable createAlias(String alias) {
    return $LocalArtifactsTable(attachedDatabase, alias);
  }
}

class LocalArtifact extends DataClass implements Insertable<LocalArtifact> {
  final String userId;
  final String projectId;
  final String artifactId;
  final String kind;
  final String path;
  final String checksum;
  final int byteSize;
  final String state;
  final DateTime createdAt;
  const LocalArtifact({
    required this.userId,
    required this.projectId,
    required this.artifactId,
    required this.kind,
    required this.path,
    required this.checksum,
    required this.byteSize,
    required this.state,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['artifact_id'] = Variable<String>(artifactId);
    map['kind'] = Variable<String>(kind);
    map['path'] = Variable<String>(path);
    map['checksum'] = Variable<String>(checksum);
    map['byte_size'] = Variable<int>(byteSize);
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalArtifactsCompanion toCompanion(bool nullToAbsent) {
    return LocalArtifactsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      artifactId: Value(artifactId),
      kind: Value(kind),
      path: Value(path),
      checksum: Value(checksum),
      byteSize: Value(byteSize),
      state: Value(state),
      createdAt: Value(createdAt),
    );
  }

  factory LocalArtifact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalArtifact(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      artifactId: serializer.fromJson<String>(json['artifactId']),
      kind: serializer.fromJson<String>(json['kind']),
      path: serializer.fromJson<String>(json['path']),
      checksum: serializer.fromJson<String>(json['checksum']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'artifactId': serializer.toJson<String>(artifactId),
      'kind': serializer.toJson<String>(kind),
      'path': serializer.toJson<String>(path),
      'checksum': serializer.toJson<String>(checksum),
      'byteSize': serializer.toJson<int>(byteSize),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalArtifact copyWith({
    String? userId,
    String? projectId,
    String? artifactId,
    String? kind,
    String? path,
    String? checksum,
    int? byteSize,
    String? state,
    DateTime? createdAt,
  }) => LocalArtifact(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    artifactId: artifactId ?? this.artifactId,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    checksum: checksum ?? this.checksum,
    byteSize: byteSize ?? this.byteSize,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalArtifact copyWithCompanion(LocalArtifactsCompanion data) {
    return LocalArtifact(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      artifactId: data.artifactId.present
          ? data.artifactId.value
          : this.artifactId,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalArtifact(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('artifactId: $artifactId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('checksum: $checksum, ')
          ..write('byteSize: $byteSize, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    projectId,
    artifactId,
    kind,
    path,
    checksum,
    byteSize,
    state,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalArtifact &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.artifactId == this.artifactId &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.checksum == this.checksum &&
          other.byteSize == this.byteSize &&
          other.state == this.state &&
          other.createdAt == this.createdAt);
}

class LocalArtifactsCompanion extends UpdateCompanion<LocalArtifact> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> artifactId;
  final Value<String> kind;
  final Value<String> path;
  final Value<String> checksum;
  final Value<int> byteSize;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalArtifactsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.artifactId = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.checksum = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalArtifactsCompanion.insert({
    required String userId,
    required String projectId,
    required String artifactId,
    required String kind,
    required String path,
    required String checksum,
    this.byteSize = const Value.absent(),
    required String state,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       artifactId = Value(artifactId),
       kind = Value(kind),
       path = Value(path),
       checksum = Value(checksum),
       state = Value(state);
  static Insertable<LocalArtifact> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? artifactId,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<String>? checksum,
    Expression<int>? byteSize,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (artifactId != null) 'artifact_id': artifactId,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (checksum != null) 'checksum': checksum,
      if (byteSize != null) 'byte_size': byteSize,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalArtifactsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? artifactId,
    Value<String>? kind,
    Value<String>? path,
    Value<String>? checksum,
    Value<int>? byteSize,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalArtifactsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      artifactId: artifactId ?? this.artifactId,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      checksum: checksum ?? this.checksum,
      byteSize: byteSize ?? this.byteSize,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (artifactId.present) {
      map['artifact_id'] = Variable<String>(artifactId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
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
    return (StringBuffer('LocalArtifactsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('artifactId: $artifactId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('checksum: $checksum, ')
          ..write('byteSize: $byteSize, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalInvitationDraftsTable extends LocalInvitationDrafts
    with TableInfo<$LocalInvitationDraftsTable, LocalInvitationDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInvitationDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    projectId,
    draftId,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_invitation_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalInvitationDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, projectId, draftId};
  @override
  LocalInvitationDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInvitationDraft(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalInvitationDraftsTable createAlias(String alias) {
    return $LocalInvitationDraftsTable(attachedDatabase, alias);
  }
}

class LocalInvitationDraft extends DataClass
    implements Insertable<LocalInvitationDraft> {
  final String userId;
  final String projectId;
  final String draftId;
  final String payloadJson;
  final DateTime createdAt;
  const LocalInvitationDraft({
    required this.userId,
    required this.projectId,
    required this.draftId,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['project_id'] = Variable<String>(projectId);
    map['draft_id'] = Variable<String>(draftId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalInvitationDraftsCompanion toCompanion(bool nullToAbsent) {
    return LocalInvitationDraftsCompanion(
      userId: Value(userId),
      projectId: Value(projectId),
      draftId: Value(draftId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalInvitationDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInvitationDraft(
      userId: serializer.fromJson<String>(json['userId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      draftId: serializer.fromJson<String>(json['draftId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'projectId': serializer.toJson<String>(projectId),
      'draftId': serializer.toJson<String>(draftId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalInvitationDraft copyWith({
    String? userId,
    String? projectId,
    String? draftId,
    String? payloadJson,
    DateTime? createdAt,
  }) => LocalInvitationDraft(
    userId: userId ?? this.userId,
    projectId: projectId ?? this.projectId,
    draftId: draftId ?? this.draftId,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalInvitationDraft copyWithCompanion(LocalInvitationDraftsCompanion data) {
    return LocalInvitationDraft(
      userId: data.userId.present ? data.userId.value : this.userId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInvitationDraft(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('draftId: $draftId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, projectId, draftId, payloadJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInvitationDraft &&
          other.userId == this.userId &&
          other.projectId == this.projectId &&
          other.draftId == this.draftId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class LocalInvitationDraftsCompanion
    extends UpdateCompanion<LocalInvitationDraft> {
  final Value<String> userId;
  final Value<String> projectId;
  final Value<String> draftId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalInvitationDraftsCompanion({
    this.userId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.draftId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInvitationDraftsCompanion.insert({
    required String userId,
    required String projectId,
    required String draftId,
    required String payloadJson,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       projectId = Value(projectId),
       draftId = Value(draftId),
       payloadJson = Value(payloadJson);
  static Insertable<LocalInvitationDraft> custom({
    Expression<String>? userId,
    Expression<String>? projectId,
    Expression<String>? draftId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (projectId != null) 'project_id': projectId,
      if (draftId != null) 'draft_id': draftId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInvitationDraftsCompanion copyWith({
    Value<String>? userId,
    Value<String>? projectId,
    Value<String>? draftId,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalInvitationDraftsCompanion(
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      draftId: draftId ?? this.draftId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('LocalInvitationDraftsCompanion(')
          ..write('userId: $userId, ')
          ..write('projectId: $projectId, ')
          ..write('draftId: $draftId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $LocalAccountsTable localAccounts = $LocalAccountsTable(this);
  late final $LocalProjectsTable localProjects = $LocalProjectsTable(this);
  late final $LocalRulesTable localRules = $LocalRulesTable(this);
  late final $LocalProposalsTable localProposals = $LocalProposalsTable(this);
  late final $LocalOperationsTable localOperations = $LocalOperationsTable(
    this,
  );
  late final $LocalConflictsTable localConflicts = $LocalConflictsTable(this);
  late final $LocalManifestsTable localManifests = $LocalManifestsTable(this);
  late final $LocalArtifactsTable localArtifacts = $LocalArtifactsTable(this);
  late final $LocalInvitationDraftsTable localInvitationDrafts =
      $LocalInvitationDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localAccounts,
    localProjects,
    localRules,
    localProposals,
    localOperations,
    localConflicts,
    localManifests,
    localArtifacts,
    localInvitationDrafts,
  ];
}

typedef $$LocalAccountsTableCreateCompanionBuilder =
    LocalAccountsCompanion Function({
      required String userId,
      Value<String?> email,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$LocalAccountsTableUpdateCompanionBuilder =
    LocalAccountsCompanion Function({
      Value<String> userId,
      Value<String?> email,
      Value<DateTime> lastOpenedAt,
      Value<int> rowid,
    });

class $$LocalAccountsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAccountsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAccountsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$LocalAccountsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalAccountsTable,
          LocalAccount,
          $$LocalAccountsTableFilterComposer,
          $$LocalAccountsTableOrderingComposer,
          $$LocalAccountsTableAnnotationComposer,
          $$LocalAccountsTableCreateCompanionBuilder,
          $$LocalAccountsTableUpdateCompanionBuilder,
          (
            LocalAccount,
            BaseReferences<
              _$OfflineDatabase,
              $LocalAccountsTable,
              LocalAccount
            >,
          ),
          LocalAccount,
          PrefetchHooks Function()
        > {
  $$LocalAccountsTableTableManager(
    _$OfflineDatabase db,
    $LocalAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion(
                userId: userId,
                email: email,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> email = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion.insert(
                userId: userId,
                email: email,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalAccountsTable,
      LocalAccount,
      $$LocalAccountsTableFilterComposer,
      $$LocalAccountsTableOrderingComposer,
      $$LocalAccountsTableAnnotationComposer,
      $$LocalAccountsTableCreateCompanionBuilder,
      $$LocalAccountsTableUpdateCompanionBuilder,
      (
        LocalAccount,
        BaseReferences<_$OfflineDatabase, $LocalAccountsTable, LocalAccount>,
      ),
      LocalAccount,
      PrefetchHooks Function()
    >;
typedef $$LocalProjectsTableCreateCompanionBuilder =
    LocalProjectsCompanion Function({
      required String userId,
      required String projectId,
      required String summaryJson,
      Value<String?> snapshotJson,
      Value<String?> registryJson,
      Value<String?> rulesJson,
      Value<int> revision,
      Value<String> syncState,
      Value<bool> offlineEnabled,
      Value<int> byteSize,
      Value<DateTime?> syncedAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalProjectsTableUpdateCompanionBuilder =
    LocalProjectsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> summaryJson,
      Value<String?> snapshotJson,
      Value<String?> registryJson,
      Value<String?> rulesJson,
      Value<int> revision,
      Value<String> syncState,
      Value<bool> offlineEnabled,
      Value<int> byteSize,
      Value<DateTime?> syncedAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$LocalProjectsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registryJson => $composableBuilder(
    column: $table.registryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get offlineEnabled => $composableBuilder(
    column: $table.offlineEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProjectsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registryJson => $composableBuilder(
    column: $table.registryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get offlineEnabled => $composableBuilder(
    column: $table.offlineEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProjectsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registryJson => $composableBuilder(
    column: $table.registryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rulesJson =>
      $composableBuilder(column: $table.rulesJson, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<bool> get offlineEnabled => $composableBuilder(
    column: $table.offlineEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalProjectsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalProjectsTable,
          LocalProject,
          $$LocalProjectsTableFilterComposer,
          $$LocalProjectsTableOrderingComposer,
          $$LocalProjectsTableAnnotationComposer,
          $$LocalProjectsTableCreateCompanionBuilder,
          $$LocalProjectsTableUpdateCompanionBuilder,
          (
            LocalProject,
            BaseReferences<
              _$OfflineDatabase,
              $LocalProjectsTable,
              LocalProject
            >,
          ),
          LocalProject,
          PrefetchHooks Function()
        > {
  $$LocalProjectsTableTableManager(
    _$OfflineDatabase db,
    $LocalProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> summaryJson = const Value.absent(),
                Value<String?> snapshotJson = const Value.absent(),
                Value<String?> registryJson = const Value.absent(),
                Value<String?> rulesJson = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> offlineEnabled = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProjectsCompanion(
                userId: userId,
                projectId: projectId,
                summaryJson: summaryJson,
                snapshotJson: snapshotJson,
                registryJson: registryJson,
                rulesJson: rulesJson,
                revision: revision,
                syncState: syncState,
                offlineEnabled: offlineEnabled,
                byteSize: byteSize,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String summaryJson,
                Value<String?> snapshotJson = const Value.absent(),
                Value<String?> registryJson = const Value.absent(),
                Value<String?> rulesJson = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> offlineEnabled = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProjectsCompanion.insert(
                userId: userId,
                projectId: projectId,
                summaryJson: summaryJson,
                snapshotJson: snapshotJson,
                registryJson: registryJson,
                rulesJson: rulesJson,
                revision: revision,
                syncState: syncState,
                offlineEnabled: offlineEnabled,
                byteSize: byteSize,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalProjectsTable,
      LocalProject,
      $$LocalProjectsTableFilterComposer,
      $$LocalProjectsTableOrderingComposer,
      $$LocalProjectsTableAnnotationComposer,
      $$LocalProjectsTableCreateCompanionBuilder,
      $$LocalProjectsTableUpdateCompanionBuilder,
      (
        LocalProject,
        BaseReferences<_$OfflineDatabase, $LocalProjectsTable, LocalProject>,
      ),
      LocalProject,
      PrefetchHooks Function()
    >;
typedef $$LocalRulesTableCreateCompanionBuilder =
    LocalRulesCompanion Function({
      required String userId,
      required String projectId,
      required String version,
      required String checksum,
      required String payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalRulesTableUpdateCompanionBuilder =
    LocalRulesCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> version,
      Value<String> checksum,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalRulesTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalRulesTable> {
  $$LocalRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRulesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalRulesTable> {
  $$LocalRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRulesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalRulesTable> {
  $$LocalRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalRulesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalRulesTable,
          LocalRule,
          $$LocalRulesTableFilterComposer,
          $$LocalRulesTableOrderingComposer,
          $$LocalRulesTableAnnotationComposer,
          $$LocalRulesTableCreateCompanionBuilder,
          $$LocalRulesTableUpdateCompanionBuilder,
          (
            LocalRule,
            BaseReferences<_$OfflineDatabase, $LocalRulesTable, LocalRule>,
          ),
          LocalRule,
          PrefetchHooks Function()
        > {
  $$LocalRulesTableTableManager(_$OfflineDatabase db, $LocalRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRulesCompanion(
                userId: userId,
                projectId: projectId,
                version: version,
                checksum: checksum,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String version,
                required String checksum,
                required String payloadJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRulesCompanion.insert(
                userId: userId,
                projectId: projectId,
                version: version,
                checksum: checksum,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalRulesTable,
      LocalRule,
      $$LocalRulesTableFilterComposer,
      $$LocalRulesTableOrderingComposer,
      $$LocalRulesTableAnnotationComposer,
      $$LocalRulesTableCreateCompanionBuilder,
      $$LocalRulesTableUpdateCompanionBuilder,
      (
        LocalRule,
        BaseReferences<_$OfflineDatabase, $LocalRulesTable, LocalRule>,
      ),
      LocalRule,
      PrefetchHooks Function()
    >;
typedef $$LocalProposalsTableCreateCompanionBuilder =
    LocalProposalsCompanion Function({
      required String userId,
      required String projectId,
      required String proposalId,
      required String payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LocalProposalsTableUpdateCompanionBuilder =
    LocalProposalsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> proposalId,
      Value<String> payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalProposalsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalProposalsTable> {
  $$LocalProposalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proposalId => $composableBuilder(
    column: $table.proposalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProposalsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalProposalsTable> {
  $$LocalProposalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proposalId => $composableBuilder(
    column: $table.proposalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProposalsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalProposalsTable> {
  $$LocalProposalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get proposalId => $composableBuilder(
    column: $table.proposalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalProposalsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalProposalsTable,
          LocalProposal,
          $$LocalProposalsTableFilterComposer,
          $$LocalProposalsTableOrderingComposer,
          $$LocalProposalsTableAnnotationComposer,
          $$LocalProposalsTableCreateCompanionBuilder,
          $$LocalProposalsTableUpdateCompanionBuilder,
          (
            LocalProposal,
            BaseReferences<
              _$OfflineDatabase,
              $LocalProposalsTable,
              LocalProposal
            >,
          ),
          LocalProposal,
          PrefetchHooks Function()
        > {
  $$LocalProposalsTableTableManager(
    _$OfflineDatabase db,
    $LocalProposalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProposalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProposalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProposalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> proposalId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProposalsCompanion(
                userId: userId,
                projectId: projectId,
                proposalId: proposalId,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String proposalId,
                required String payloadJson,
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProposalsCompanion.insert(
                userId: userId,
                projectId: projectId,
                proposalId: proposalId,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProposalsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalProposalsTable,
      LocalProposal,
      $$LocalProposalsTableFilterComposer,
      $$LocalProposalsTableOrderingComposer,
      $$LocalProposalsTableAnnotationComposer,
      $$LocalProposalsTableCreateCompanionBuilder,
      $$LocalProposalsTableUpdateCompanionBuilder,
      (
        LocalProposal,
        BaseReferences<_$OfflineDatabase, $LocalProposalsTable, LocalProposal>,
      ),
      LocalProposal,
      PrefetchHooks Function()
    >;
typedef $$LocalOperationsTableCreateCompanionBuilder =
    LocalOperationsCompanion Function({
      required String userId,
      required String projectId,
      required String operationId,
      required int baseRevision,
      required String payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LocalOperationsTableUpdateCompanionBuilder =
    LocalOperationsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> operationId,
      Value<int> baseRevision,
      Value<String> payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalOperationsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalOperationsTable> {
  $$LocalOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalOperationsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalOperationsTable> {
  $$LocalOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOperationsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalOperationsTable> {
  $$LocalOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalOperationsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalOperationsTable,
          LocalOperation,
          $$LocalOperationsTableFilterComposer,
          $$LocalOperationsTableOrderingComposer,
          $$LocalOperationsTableAnnotationComposer,
          $$LocalOperationsTableCreateCompanionBuilder,
          $$LocalOperationsTableUpdateCompanionBuilder,
          (
            LocalOperation,
            BaseReferences<
              _$OfflineDatabase,
              $LocalOperationsTable,
              LocalOperation
            >,
          ),
          LocalOperation,
          PrefetchHooks Function()
        > {
  $$LocalOperationsTableTableManager(
    _$OfflineDatabase db,
    $LocalOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOperationsCompanion(
                userId: userId,
                projectId: projectId,
                operationId: operationId,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String operationId,
                required int baseRevision,
                required String payloadJson,
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOperationsCompanion.insert(
                userId: userId,
                projectId: projectId,
                operationId: operationId,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalOperationsTable,
      LocalOperation,
      $$LocalOperationsTableFilterComposer,
      $$LocalOperationsTableOrderingComposer,
      $$LocalOperationsTableAnnotationComposer,
      $$LocalOperationsTableCreateCompanionBuilder,
      $$LocalOperationsTableUpdateCompanionBuilder,
      (
        LocalOperation,
        BaseReferences<
          _$OfflineDatabase,
          $LocalOperationsTable,
          LocalOperation
        >,
      ),
      LocalOperation,
      PrefetchHooks Function()
    >;
typedef $$LocalConflictsTableCreateCompanionBuilder =
    LocalConflictsCompanion Function({
      required String userId,
      required String projectId,
      required String conflictId,
      required String payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LocalConflictsTableUpdateCompanionBuilder =
    LocalConflictsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> conflictId,
      Value<String> payloadJson,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalConflictsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalConflictsTable> {
  $$LocalConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConflictsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalConflictsTable> {
  $$LocalConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConflictsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalConflictsTable> {
  $$LocalConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get conflictId => $composableBuilder(
    column: $table.conflictId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalConflictsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalConflictsTable,
          LocalConflict,
          $$LocalConflictsTableFilterComposer,
          $$LocalConflictsTableOrderingComposer,
          $$LocalConflictsTableAnnotationComposer,
          $$LocalConflictsTableCreateCompanionBuilder,
          $$LocalConflictsTableUpdateCompanionBuilder,
          (
            LocalConflict,
            BaseReferences<
              _$OfflineDatabase,
              $LocalConflictsTable,
              LocalConflict
            >,
          ),
          LocalConflict,
          PrefetchHooks Function()
        > {
  $$LocalConflictsTableTableManager(
    _$OfflineDatabase db,
    $LocalConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> conflictId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConflictsCompanion(
                userId: userId,
                projectId: projectId,
                conflictId: conflictId,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String conflictId,
                required String payloadJson,
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConflictsCompanion.insert(
                userId: userId,
                projectId: projectId,
                conflictId: conflictId,
                payloadJson: payloadJson,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalConflictsTable,
      LocalConflict,
      $$LocalConflictsTableFilterComposer,
      $$LocalConflictsTableOrderingComposer,
      $$LocalConflictsTableAnnotationComposer,
      $$LocalConflictsTableCreateCompanionBuilder,
      $$LocalConflictsTableUpdateCompanionBuilder,
      (
        LocalConflict,
        BaseReferences<_$OfflineDatabase, $LocalConflictsTable, LocalConflict>,
      ),
      LocalConflict,
      PrefetchHooks Function()
    >;
typedef $$LocalManifestsTableCreateCompanionBuilder =
    LocalManifestsCompanion Function({
      required String userId,
      Value<String> projectId,
      required String kind,
      required String version,
      required String checksum,
      required String payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalManifestsTableUpdateCompanionBuilder =
    LocalManifestsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> kind,
      Value<String> version,
      Value<String> checksum,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalManifestsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalManifestsTable> {
  $$LocalManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalManifestsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalManifestsTable> {
  $$LocalManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalManifestsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalManifestsTable> {
  $$LocalManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalManifestsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalManifestsTable,
          LocalManifest,
          $$LocalManifestsTableFilterComposer,
          $$LocalManifestsTableOrderingComposer,
          $$LocalManifestsTableAnnotationComposer,
          $$LocalManifestsTableCreateCompanionBuilder,
          $$LocalManifestsTableUpdateCompanionBuilder,
          (
            LocalManifest,
            BaseReferences<
              _$OfflineDatabase,
              $LocalManifestsTable,
              LocalManifest
            >,
          ),
          LocalManifest,
          PrefetchHooks Function()
        > {
  $$LocalManifestsTableTableManager(
    _$OfflineDatabase db,
    $LocalManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalManifestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalManifestsCompanion(
                userId: userId,
                projectId: projectId,
                kind: kind,
                version: version,
                checksum: checksum,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String> projectId = const Value.absent(),
                required String kind,
                required String version,
                required String checksum,
                required String payloadJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalManifestsCompanion.insert(
                userId: userId,
                projectId: projectId,
                kind: kind,
                version: version,
                checksum: checksum,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalManifestsTable,
      LocalManifest,
      $$LocalManifestsTableFilterComposer,
      $$LocalManifestsTableOrderingComposer,
      $$LocalManifestsTableAnnotationComposer,
      $$LocalManifestsTableCreateCompanionBuilder,
      $$LocalManifestsTableUpdateCompanionBuilder,
      (
        LocalManifest,
        BaseReferences<_$OfflineDatabase, $LocalManifestsTable, LocalManifest>,
      ),
      LocalManifest,
      PrefetchHooks Function()
    >;
typedef $$LocalArtifactsTableCreateCompanionBuilder =
    LocalArtifactsCompanion Function({
      required String userId,
      required String projectId,
      required String artifactId,
      required String kind,
      required String path,
      required String checksum,
      Value<int> byteSize,
      required String state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LocalArtifactsTableUpdateCompanionBuilder =
    LocalArtifactsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> artifactId,
      Value<String> kind,
      Value<String> path,
      Value<String> checksum,
      Value<int> byteSize,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalArtifactsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalArtifactsTable> {
  $$LocalArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalArtifactsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalArtifactsTable> {
  $$LocalArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalArtifactsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalArtifactsTable> {
  $$LocalArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get artifactId => $composableBuilder(
    column: $table.artifactId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalArtifactsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalArtifactsTable,
          LocalArtifact,
          $$LocalArtifactsTableFilterComposer,
          $$LocalArtifactsTableOrderingComposer,
          $$LocalArtifactsTableAnnotationComposer,
          $$LocalArtifactsTableCreateCompanionBuilder,
          $$LocalArtifactsTableUpdateCompanionBuilder,
          (
            LocalArtifact,
            BaseReferences<
              _$OfflineDatabase,
              $LocalArtifactsTable,
              LocalArtifact
            >,
          ),
          LocalArtifact,
          PrefetchHooks Function()
        > {
  $$LocalArtifactsTableTableManager(
    _$OfflineDatabase db,
    $LocalArtifactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalArtifactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalArtifactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalArtifactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> artifactId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalArtifactsCompanion(
                userId: userId,
                projectId: projectId,
                artifactId: artifactId,
                kind: kind,
                path: path,
                checksum: checksum,
                byteSize: byteSize,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String artifactId,
                required String kind,
                required String path,
                required String checksum,
                Value<int> byteSize = const Value.absent(),
                required String state,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalArtifactsCompanion.insert(
                userId: userId,
                projectId: projectId,
                artifactId: artifactId,
                kind: kind,
                path: path,
                checksum: checksum,
                byteSize: byteSize,
                state: state,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalArtifactsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalArtifactsTable,
      LocalArtifact,
      $$LocalArtifactsTableFilterComposer,
      $$LocalArtifactsTableOrderingComposer,
      $$LocalArtifactsTableAnnotationComposer,
      $$LocalArtifactsTableCreateCompanionBuilder,
      $$LocalArtifactsTableUpdateCompanionBuilder,
      (
        LocalArtifact,
        BaseReferences<_$OfflineDatabase, $LocalArtifactsTable, LocalArtifact>,
      ),
      LocalArtifact,
      PrefetchHooks Function()
    >;
typedef $$LocalInvitationDraftsTableCreateCompanionBuilder =
    LocalInvitationDraftsCompanion Function({
      required String userId,
      required String projectId,
      required String draftId,
      required String payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LocalInvitationDraftsTableUpdateCompanionBuilder =
    LocalInvitationDraftsCompanion Function({
      Value<String> userId,
      Value<String> projectId,
      Value<String> draftId,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalInvitationDraftsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalInvitationDraftsTable> {
  $$LocalInvitationDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalInvitationDraftsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalInvitationDraftsTable> {
  $$LocalInvitationDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalInvitationDraftsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalInvitationDraftsTable> {
  $$LocalInvitationDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalInvitationDraftsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $LocalInvitationDraftsTable,
          LocalInvitationDraft,
          $$LocalInvitationDraftsTableFilterComposer,
          $$LocalInvitationDraftsTableOrderingComposer,
          $$LocalInvitationDraftsTableAnnotationComposer,
          $$LocalInvitationDraftsTableCreateCompanionBuilder,
          $$LocalInvitationDraftsTableUpdateCompanionBuilder,
          (
            LocalInvitationDraft,
            BaseReferences<
              _$OfflineDatabase,
              $LocalInvitationDraftsTable,
              LocalInvitationDraft
            >,
          ),
          LocalInvitationDraft,
          PrefetchHooks Function()
        > {
  $$LocalInvitationDraftsTableTableManager(
    _$OfflineDatabase db,
    $LocalInvitationDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInvitationDraftsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalInvitationDraftsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalInvitationDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> draftId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInvitationDraftsCompanion(
                userId: userId,
                projectId: projectId,
                draftId: draftId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String projectId,
                required String draftId,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInvitationDraftsCompanion.insert(
                userId: userId,
                projectId: projectId,
                draftId: draftId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalInvitationDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $LocalInvitationDraftsTable,
      LocalInvitationDraft,
      $$LocalInvitationDraftsTableFilterComposer,
      $$LocalInvitationDraftsTableOrderingComposer,
      $$LocalInvitationDraftsTableAnnotationComposer,
      $$LocalInvitationDraftsTableCreateCompanionBuilder,
      $$LocalInvitationDraftsTableUpdateCompanionBuilder,
      (
        LocalInvitationDraft,
        BaseReferences<
          _$OfflineDatabase,
          $LocalInvitationDraftsTable,
          LocalInvitationDraft
        >,
      ),
      LocalInvitationDraft,
      PrefetchHooks Function()
    >;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$LocalAccountsTableTableManager get localAccounts =>
      $$LocalAccountsTableTableManager(_db, _db.localAccounts);
  $$LocalProjectsTableTableManager get localProjects =>
      $$LocalProjectsTableTableManager(_db, _db.localProjects);
  $$LocalRulesTableTableManager get localRules =>
      $$LocalRulesTableTableManager(_db, _db.localRules);
  $$LocalProposalsTableTableManager get localProposals =>
      $$LocalProposalsTableTableManager(_db, _db.localProposals);
  $$LocalOperationsTableTableManager get localOperations =>
      $$LocalOperationsTableTableManager(_db, _db.localOperations);
  $$LocalConflictsTableTableManager get localConflicts =>
      $$LocalConflictsTableTableManager(_db, _db.localConflicts);
  $$LocalManifestsTableTableManager get localManifests =>
      $$LocalManifestsTableTableManager(_db, _db.localManifests);
  $$LocalArtifactsTableTableManager get localArtifacts =>
      $$LocalArtifactsTableTableManager(_db, _db.localArtifacts);
  $$LocalInvitationDraftsTableTableManager get localInvitationDrafts =>
      $$LocalInvitationDraftsTableTableManager(_db, _db.localInvitationDrafts);
}
