// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_database.dart';

// ignore_for_file: type=lint
class $ChatConversationRowsTable extends ChatConversationRows
    with TableInfo<$ChatConversationRowsTable, ChatConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatConversationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantIdsMeta = const VerificationMeta(
    'participantIds',
  );
  @override
  late final GeneratedColumn<String> participantIds = GeneratedColumn<String>(
    'participant_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartUserIdMeta = const VerificationMeta(
    'counterpartUserId',
  );
  @override
  late final GeneratedColumn<String> counterpartUserId =
      GeneratedColumn<String>(
        'counterpart_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _counterpartExternalIdMeta =
      const VerificationMeta('counterpartExternalId');
  @override
  late final GeneratedColumn<String> counterpartExternalId =
      GeneratedColumn<String>(
        'counterpart_external_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageAtMsMeta = const VerificationMeta(
    'lastMessageAtMs',
  );
  @override
  late final GeneratedColumn<int> lastMessageAtMs = GeneratedColumn<int>(
    'last_message_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _myUserIdMeta = const VerificationMeta(
    'myUserId',
  );
  @override
  late final GeneratedColumn<String> myUserId = GeneratedColumn<String>(
    'my_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextCursorMeta = const VerificationMeta(
    'nextCursor',
  );
  @override
  late final GeneratedColumn<String> nextCursor = GeneratedColumn<String>(
    'next_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMsMeta = const VerificationMeta(
    'syncedAtMs',
  );
  @override
  late final GeneratedColumn<int> syncedAtMs = GeneratedColumn<int>(
    'synced_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    participantIds,
    counterpartUserId,
    counterpartExternalId,
    createdAtMs,
    lastMessageAtMs,
    myUserId,
    nextCursor,
    syncedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_conversation_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('participant_ids')) {
      context.handle(
        _participantIdsMeta,
        participantIds.isAcceptableOrUnknown(
          data['participant_ids']!,
          _participantIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantIdsMeta);
    }
    if (data.containsKey('counterpart_user_id')) {
      context.handle(
        _counterpartUserIdMeta,
        counterpartUserId.isAcceptableOrUnknown(
          data['counterpart_user_id']!,
          _counterpartUserIdMeta,
        ),
      );
    }
    if (data.containsKey('counterpart_external_id')) {
      context.handle(
        _counterpartExternalIdMeta,
        counterpartExternalId.isAcceptableOrUnknown(
          data['counterpart_external_id']!,
          _counterpartExternalIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('last_message_at_ms')) {
      context.handle(
        _lastMessageAtMsMeta,
        lastMessageAtMs.isAcceptableOrUnknown(
          data['last_message_at_ms']!,
          _lastMessageAtMsMeta,
        ),
      );
    }
    if (data.containsKey('my_user_id')) {
      context.handle(
        _myUserIdMeta,
        myUserId.isAcceptableOrUnknown(data['my_user_id']!, _myUserIdMeta),
      );
    }
    if (data.containsKey('next_cursor')) {
      context.handle(
        _nextCursorMeta,
        nextCursor.isAcceptableOrUnknown(data['next_cursor']!, _nextCursorMeta),
      );
    }
    if (data.containsKey('synced_at_ms')) {
      context.handle(
        _syncedAtMsMeta,
        syncedAtMs.isAcceptableOrUnknown(
          data['synced_at_ms']!,
          _syncedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      participantIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_ids'],
      )!,
      counterpartUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterpart_user_id'],
      ),
      counterpartExternalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterpart_external_id'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      lastMessageAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_at_ms'],
      ),
      myUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}my_user_id'],
      ),
      nextCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_cursor'],
      ),
      syncedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at_ms'],
      )!,
    );
  }

  @override
  $ChatConversationRowsTable createAlias(String alias) {
    return $ChatConversationRowsTable(attachedDatabase, alias);
  }
}

class ChatConversationRow extends DataClass
    implements Insertable<ChatConversationRow> {
  final String id;

  /// JSON-encoded `List<String>` of both participants' internal ids.
  final String participantIds;

  /// Server-computed counterpart (internal id) — present once the list endpoint
  /// has been read for this conversation.
  final String? counterpartUserId;

  /// Counterpart's Firebase uid (the directory key) — null until the backend
  /// has provisioned them.
  final String? counterpartExternalId;
  final int createdAtMs;
  final int? lastMessageAtMs;

  /// The caller's own internal id in this thread, once derived — kept so a cold
  /// re-open renders own/counterpart alignment before the first network round.
  final String? myUserId;

  /// The server cursor for the next **older** history page, as last known.
  /// Lets an online scroll-back continue from where the cache ends.
  final String? nextCursor;

  /// Local wall-clock of the last merge into this row (ms). Cache-invalidation
  /// bookkeeping only; never shown.
  final int syncedAtMs;
  const ChatConversationRow({
    required this.id,
    required this.participantIds,
    this.counterpartUserId,
    this.counterpartExternalId,
    required this.createdAtMs,
    this.lastMessageAtMs,
    this.myUserId,
    this.nextCursor,
    required this.syncedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['participant_ids'] = Variable<String>(participantIds);
    if (!nullToAbsent || counterpartUserId != null) {
      map['counterpart_user_id'] = Variable<String>(counterpartUserId);
    }
    if (!nullToAbsent || counterpartExternalId != null) {
      map['counterpart_external_id'] = Variable<String>(counterpartExternalId);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || lastMessageAtMs != null) {
      map['last_message_at_ms'] = Variable<int>(lastMessageAtMs);
    }
    if (!nullToAbsent || myUserId != null) {
      map['my_user_id'] = Variable<String>(myUserId);
    }
    if (!nullToAbsent || nextCursor != null) {
      map['next_cursor'] = Variable<String>(nextCursor);
    }
    map['synced_at_ms'] = Variable<int>(syncedAtMs);
    return map;
  }

  ChatConversationRowsCompanion toCompanion(bool nullToAbsent) {
    return ChatConversationRowsCompanion(
      id: Value(id),
      participantIds: Value(participantIds),
      counterpartUserId: counterpartUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(counterpartUserId),
      counterpartExternalId: counterpartExternalId == null && nullToAbsent
          ? const Value.absent()
          : Value(counterpartExternalId),
      createdAtMs: Value(createdAtMs),
      lastMessageAtMs: lastMessageAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAtMs),
      myUserId: myUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(myUserId),
      nextCursor: nextCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(nextCursor),
      syncedAtMs: Value(syncedAtMs),
    );
  }

  factory ChatConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatConversationRow(
      id: serializer.fromJson<String>(json['id']),
      participantIds: serializer.fromJson<String>(json['participantIds']),
      counterpartUserId: serializer.fromJson<String?>(
        json['counterpartUserId'],
      ),
      counterpartExternalId: serializer.fromJson<String?>(
        json['counterpartExternalId'],
      ),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      lastMessageAtMs: serializer.fromJson<int?>(json['lastMessageAtMs']),
      myUserId: serializer.fromJson<String?>(json['myUserId']),
      nextCursor: serializer.fromJson<String?>(json['nextCursor']),
      syncedAtMs: serializer.fromJson<int>(json['syncedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'participantIds': serializer.toJson<String>(participantIds),
      'counterpartUserId': serializer.toJson<String?>(counterpartUserId),
      'counterpartExternalId': serializer.toJson<String?>(
        counterpartExternalId,
      ),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'lastMessageAtMs': serializer.toJson<int?>(lastMessageAtMs),
      'myUserId': serializer.toJson<String?>(myUserId),
      'nextCursor': serializer.toJson<String?>(nextCursor),
      'syncedAtMs': serializer.toJson<int>(syncedAtMs),
    };
  }

  ChatConversationRow copyWith({
    String? id,
    String? participantIds,
    Value<String?> counterpartUserId = const Value.absent(),
    Value<String?> counterpartExternalId = const Value.absent(),
    int? createdAtMs,
    Value<int?> lastMessageAtMs = const Value.absent(),
    Value<String?> myUserId = const Value.absent(),
    Value<String?> nextCursor = const Value.absent(),
    int? syncedAtMs,
  }) => ChatConversationRow(
    id: id ?? this.id,
    participantIds: participantIds ?? this.participantIds,
    counterpartUserId: counterpartUserId.present
        ? counterpartUserId.value
        : this.counterpartUserId,
    counterpartExternalId: counterpartExternalId.present
        ? counterpartExternalId.value
        : this.counterpartExternalId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    lastMessageAtMs: lastMessageAtMs.present
        ? lastMessageAtMs.value
        : this.lastMessageAtMs,
    myUserId: myUserId.present ? myUserId.value : this.myUserId,
    nextCursor: nextCursor.present ? nextCursor.value : this.nextCursor,
    syncedAtMs: syncedAtMs ?? this.syncedAtMs,
  );
  ChatConversationRow copyWithCompanion(ChatConversationRowsCompanion data) {
    return ChatConversationRow(
      id: data.id.present ? data.id.value : this.id,
      participantIds: data.participantIds.present
          ? data.participantIds.value
          : this.participantIds,
      counterpartUserId: data.counterpartUserId.present
          ? data.counterpartUserId.value
          : this.counterpartUserId,
      counterpartExternalId: data.counterpartExternalId.present
          ? data.counterpartExternalId.value
          : this.counterpartExternalId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      lastMessageAtMs: data.lastMessageAtMs.present
          ? data.lastMessageAtMs.value
          : this.lastMessageAtMs,
      myUserId: data.myUserId.present ? data.myUserId.value : this.myUserId,
      nextCursor: data.nextCursor.present
          ? data.nextCursor.value
          : this.nextCursor,
      syncedAtMs: data.syncedAtMs.present
          ? data.syncedAtMs.value
          : this.syncedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationRow(')
          ..write('id: $id, ')
          ..write('participantIds: $participantIds, ')
          ..write('counterpartUserId: $counterpartUserId, ')
          ..write('counterpartExternalId: $counterpartExternalId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('lastMessageAtMs: $lastMessageAtMs, ')
          ..write('myUserId: $myUserId, ')
          ..write('nextCursor: $nextCursor, ')
          ..write('syncedAtMs: $syncedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    participantIds,
    counterpartUserId,
    counterpartExternalId,
    createdAtMs,
    lastMessageAtMs,
    myUserId,
    nextCursor,
    syncedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatConversationRow &&
          other.id == this.id &&
          other.participantIds == this.participantIds &&
          other.counterpartUserId == this.counterpartUserId &&
          other.counterpartExternalId == this.counterpartExternalId &&
          other.createdAtMs == this.createdAtMs &&
          other.lastMessageAtMs == this.lastMessageAtMs &&
          other.myUserId == this.myUserId &&
          other.nextCursor == this.nextCursor &&
          other.syncedAtMs == this.syncedAtMs);
}

class ChatConversationRowsCompanion
    extends UpdateCompanion<ChatConversationRow> {
  final Value<String> id;
  final Value<String> participantIds;
  final Value<String?> counterpartUserId;
  final Value<String?> counterpartExternalId;
  final Value<int> createdAtMs;
  final Value<int?> lastMessageAtMs;
  final Value<String?> myUserId;
  final Value<String?> nextCursor;
  final Value<int> syncedAtMs;
  final Value<int> rowid;
  const ChatConversationRowsCompanion({
    this.id = const Value.absent(),
    this.participantIds = const Value.absent(),
    this.counterpartUserId = const Value.absent(),
    this.counterpartExternalId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.lastMessageAtMs = const Value.absent(),
    this.myUserId = const Value.absent(),
    this.nextCursor = const Value.absent(),
    this.syncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatConversationRowsCompanion.insert({
    required String id,
    required String participantIds,
    this.counterpartUserId = const Value.absent(),
    this.counterpartExternalId = const Value.absent(),
    required int createdAtMs,
    this.lastMessageAtMs = const Value.absent(),
    this.myUserId = const Value.absent(),
    this.nextCursor = const Value.absent(),
    this.syncedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       participantIds = Value(participantIds),
       createdAtMs = Value(createdAtMs);
  static Insertable<ChatConversationRow> custom({
    Expression<String>? id,
    Expression<String>? participantIds,
    Expression<String>? counterpartUserId,
    Expression<String>? counterpartExternalId,
    Expression<int>? createdAtMs,
    Expression<int>? lastMessageAtMs,
    Expression<String>? myUserId,
    Expression<String>? nextCursor,
    Expression<int>? syncedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (participantIds != null) 'participant_ids': participantIds,
      if (counterpartUserId != null) 'counterpart_user_id': counterpartUserId,
      if (counterpartExternalId != null)
        'counterpart_external_id': counterpartExternalId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (lastMessageAtMs != null) 'last_message_at_ms': lastMessageAtMs,
      if (myUserId != null) 'my_user_id': myUserId,
      if (nextCursor != null) 'next_cursor': nextCursor,
      if (syncedAtMs != null) 'synced_at_ms': syncedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatConversationRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? participantIds,
    Value<String?>? counterpartUserId,
    Value<String?>? counterpartExternalId,
    Value<int>? createdAtMs,
    Value<int?>? lastMessageAtMs,
    Value<String?>? myUserId,
    Value<String?>? nextCursor,
    Value<int>? syncedAtMs,
    Value<int>? rowid,
  }) {
    return ChatConversationRowsCompanion(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      counterpartUserId: counterpartUserId ?? this.counterpartUserId,
      counterpartExternalId:
          counterpartExternalId ?? this.counterpartExternalId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastMessageAtMs: lastMessageAtMs ?? this.lastMessageAtMs,
      myUserId: myUserId ?? this.myUserId,
      nextCursor: nextCursor ?? this.nextCursor,
      syncedAtMs: syncedAtMs ?? this.syncedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (participantIds.present) {
      map['participant_ids'] = Variable<String>(participantIds.value);
    }
    if (counterpartUserId.present) {
      map['counterpart_user_id'] = Variable<String>(counterpartUserId.value);
    }
    if (counterpartExternalId.present) {
      map['counterpart_external_id'] = Variable<String>(
        counterpartExternalId.value,
      );
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (lastMessageAtMs.present) {
      map['last_message_at_ms'] = Variable<int>(lastMessageAtMs.value);
    }
    if (myUserId.present) {
      map['my_user_id'] = Variable<String>(myUserId.value);
    }
    if (nextCursor.present) {
      map['next_cursor'] = Variable<String>(nextCursor.value);
    }
    if (syncedAtMs.present) {
      map['synced_at_ms'] = Variable<int>(syncedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationRowsCompanion(')
          ..write('id: $id, ')
          ..write('participantIds: $participantIds, ')
          ..write('counterpartUserId: $counterpartUserId, ')
          ..write('counterpartExternalId: $counterpartExternalId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('lastMessageAtMs: $lastMessageAtMs, ')
          ..write('myUserId: $myUserId, ')
          ..write('nextCursor: $nextCursor, ')
          ..write('syncedAtMs: $syncedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessageRowsTable extends ChatMessageRows
    with TableInfo<$ChatMessageRowsTable, ChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedForEveryoneMeta =
      const VerificationMeta('deletedForEveryone');
  @override
  late final GeneratedColumn<bool> deletedForEveryone = GeneratedColumn<bool>(
    'deleted_for_everyone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_for_everyone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentKindMeta = const VerificationMeta(
    'attachmentKind',
  );
  @override
  late final GeneratedColumn<String> attachmentKind = GeneratedColumn<String>(
    'attachment_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentFormatMeta = const VerificationMeta(
    'attachmentFormat',
  );
  @override
  late final GeneratedColumn<String> attachmentFormat = GeneratedColumn<String>(
    'attachment_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentMimeTypeMeta =
      const VerificationMeta('attachmentMimeType');
  @override
  late final GeneratedColumn<String> attachmentMimeType =
      GeneratedColumn<String>(
        'attachment_mime_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentFilenameMeta =
      const VerificationMeta('attachmentFilename');
  @override
  late final GeneratedColumn<String> attachmentFilename =
      GeneratedColumn<String>(
        'attachment_filename',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentByteSizeMeta =
      const VerificationMeta('attachmentByteSize');
  @override
  late final GeneratedColumn<int> attachmentByteSize = GeneratedColumn<int>(
    'attachment_byte_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replySenderIdMeta = const VerificationMeta(
    'replySenderId',
  );
  @override
  late final GeneratedColumn<String> replySenderId = GeneratedColumn<String>(
    'reply_sender_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyTypeMeta = const VerificationMeta(
    'replyType',
  );
  @override
  late final GeneratedColumn<String> replyType = GeneratedColumn<String>(
    'reply_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyBodyMeta = const VerificationMeta(
    'replyBody',
  );
  @override
  late final GeneratedColumn<String> replyBody = GeneratedColumn<String>(
    'reply_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyAttachmentJsonMeta =
      const VerificationMeta('replyAttachmentJson');
  @override
  late final GeneratedColumn<String> replyAttachmentJson =
      GeneratedColumn<String>(
        'reply_attachment_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderId,
    type,
    body,
    seq,
    status,
    createdAtMs,
    deletedForEveryone,
    attachmentId,
    attachmentKind,
    attachmentFormat,
    attachmentMimeType,
    attachmentFilename,
    attachmentByteSize,
    replyToId,
    replySenderId,
    replyType,
    replyBody,
    replyAttachmentJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_message_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('deleted_for_everyone')) {
      context.handle(
        _deletedForEveryoneMeta,
        deletedForEveryone.isAcceptableOrUnknown(
          data['deleted_for_everyone']!,
          _deletedForEveryoneMeta,
        ),
      );
    }
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('attachment_kind')) {
      context.handle(
        _attachmentKindMeta,
        attachmentKind.isAcceptableOrUnknown(
          data['attachment_kind']!,
          _attachmentKindMeta,
        ),
      );
    }
    if (data.containsKey('attachment_format')) {
      context.handle(
        _attachmentFormatMeta,
        attachmentFormat.isAcceptableOrUnknown(
          data['attachment_format']!,
          _attachmentFormatMeta,
        ),
      );
    }
    if (data.containsKey('attachment_mime_type')) {
      context.handle(
        _attachmentMimeTypeMeta,
        attachmentMimeType.isAcceptableOrUnknown(
          data['attachment_mime_type']!,
          _attachmentMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('attachment_filename')) {
      context.handle(
        _attachmentFilenameMeta,
        attachmentFilename.isAcceptableOrUnknown(
          data['attachment_filename']!,
          _attachmentFilenameMeta,
        ),
      );
    }
    if (data.containsKey('attachment_byte_size')) {
      context.handle(
        _attachmentByteSizeMeta,
        attachmentByteSize.isAcceptableOrUnknown(
          data['attachment_byte_size']!,
          _attachmentByteSizeMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('reply_sender_id')) {
      context.handle(
        _replySenderIdMeta,
        replySenderId.isAcceptableOrUnknown(
          data['reply_sender_id']!,
          _replySenderIdMeta,
        ),
      );
    }
    if (data.containsKey('reply_type')) {
      context.handle(
        _replyTypeMeta,
        replyType.isAcceptableOrUnknown(data['reply_type']!, _replyTypeMeta),
      );
    }
    if (data.containsKey('reply_body')) {
      context.handle(
        _replyBodyMeta,
        replyBody.isAcceptableOrUnknown(data['reply_body']!, _replyBodyMeta),
      );
    }
    if (data.containsKey('reply_attachment_json')) {
      context.handle(
        _replyAttachmentJsonMeta,
        replyAttachmentJson.isAcceptableOrUnknown(
          data['reply_attachment_json']!,
          _replyAttachmentJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      deletedForEveryone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_for_everyone'],
      )!,
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
      ),
      attachmentKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_kind'],
      ),
      attachmentFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_format'],
      ),
      attachmentMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_mime_type'],
      ),
      attachmentFilename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_filename'],
      ),
      attachmentByteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attachment_byte_size'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      replySenderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_sender_id'],
      ),
      replyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_type'],
      ),
      replyBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_body'],
      ),
      replyAttachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_attachment_json'],
      ),
    );
  }

  @override
  $ChatMessageRowsTable createAlias(String alias) {
    return $ChatMessageRowsTable(attachedDatabase, alias);
  }
}

class ChatMessageRow extends DataClass implements Insertable<ChatMessageRow> {
  final String id;
  final String conversationId;
  final String senderId;

  /// Raw wire type string (`TEXT`/`IMAGE`/`DOCUMENT`) — kept verbatim so a
  /// newer server value round-trips instead of collapsing to a default.
  final String type;
  final String? body;

  /// Conversation-scoped ordering sequence. 64-bit; stored as INTEGER (exact on
  /// every non-web target this app ships) and rebuilt to [BigInt] on read.
  final int seq;
  final String status;
  final int createdAtMs;
  final bool deletedForEveryone;
  final String? attachmentId;
  final String? attachmentKind;
  final String? attachmentFormat;
  final String? attachmentMimeType;
  final String? attachmentFilename;
  final int? attachmentByteSize;
  final String? replyToId;
  final String? replySenderId;
  final String? replyType;
  final String? replyBody;

  /// The quoted parent's own attachment metadata, JSON-encoded (small, at most
  /// one) — kept inline to avoid a second nullable attachment column set.
  final String? replyAttachmentJson;
  const ChatMessageRow({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    required this.seq,
    required this.status,
    required this.createdAtMs,
    required this.deletedForEveryone,
    this.attachmentId,
    this.attachmentKind,
    this.attachmentFormat,
    this.attachmentMimeType,
    this.attachmentFilename,
    this.attachmentByteSize,
    this.replyToId,
    this.replySenderId,
    this.replyType,
    this.replyBody,
    this.replyAttachmentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['seq'] = Variable<int>(seq);
    map['status'] = Variable<String>(status);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['deleted_for_everyone'] = Variable<bool>(deletedForEveryone);
    if (!nullToAbsent || attachmentId != null) {
      map['attachment_id'] = Variable<String>(attachmentId);
    }
    if (!nullToAbsent || attachmentKind != null) {
      map['attachment_kind'] = Variable<String>(attachmentKind);
    }
    if (!nullToAbsent || attachmentFormat != null) {
      map['attachment_format'] = Variable<String>(attachmentFormat);
    }
    if (!nullToAbsent || attachmentMimeType != null) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType);
    }
    if (!nullToAbsent || attachmentFilename != null) {
      map['attachment_filename'] = Variable<String>(attachmentFilename);
    }
    if (!nullToAbsent || attachmentByteSize != null) {
      map['attachment_byte_size'] = Variable<int>(attachmentByteSize);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    if (!nullToAbsent || replySenderId != null) {
      map['reply_sender_id'] = Variable<String>(replySenderId);
    }
    if (!nullToAbsent || replyType != null) {
      map['reply_type'] = Variable<String>(replyType);
    }
    if (!nullToAbsent || replyBody != null) {
      map['reply_body'] = Variable<String>(replyBody);
    }
    if (!nullToAbsent || replyAttachmentJson != null) {
      map['reply_attachment_json'] = Variable<String>(replyAttachmentJson);
    }
    return map;
  }

  ChatMessageRowsCompanion toCompanion(bool nullToAbsent) {
    return ChatMessageRowsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      type: Value(type),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      seq: Value(seq),
      status: Value(status),
      createdAtMs: Value(createdAtMs),
      deletedForEveryone: Value(deletedForEveryone),
      attachmentId: attachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentId),
      attachmentKind: attachmentKind == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentKind),
      attachmentFormat: attachmentFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentFormat),
      attachmentMimeType: attachmentMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentMimeType),
      attachmentFilename: attachmentFilename == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentFilename),
      attachmentByteSize: attachmentByteSize == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentByteSize),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      replySenderId: replySenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(replySenderId),
      replyType: replyType == null && nullToAbsent
          ? const Value.absent()
          : Value(replyType),
      replyBody: replyBody == null && nullToAbsent
          ? const Value.absent()
          : Value(replyBody),
      replyAttachmentJson: replyAttachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(replyAttachmentJson),
    );
  }

  factory ChatMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      type: serializer.fromJson<String>(json['type']),
      body: serializer.fromJson<String?>(json['body']),
      seq: serializer.fromJson<int>(json['seq']),
      status: serializer.fromJson<String>(json['status']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      deletedForEveryone: serializer.fromJson<bool>(json['deletedForEveryone']),
      attachmentId: serializer.fromJson<String?>(json['attachmentId']),
      attachmentKind: serializer.fromJson<String?>(json['attachmentKind']),
      attachmentFormat: serializer.fromJson<String?>(json['attachmentFormat']),
      attachmentMimeType: serializer.fromJson<String?>(
        json['attachmentMimeType'],
      ),
      attachmentFilename: serializer.fromJson<String?>(
        json['attachmentFilename'],
      ),
      attachmentByteSize: serializer.fromJson<int?>(json['attachmentByteSize']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      replySenderId: serializer.fromJson<String?>(json['replySenderId']),
      replyType: serializer.fromJson<String?>(json['replyType']),
      replyBody: serializer.fromJson<String?>(json['replyBody']),
      replyAttachmentJson: serializer.fromJson<String?>(
        json['replyAttachmentJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'type': serializer.toJson<String>(type),
      'body': serializer.toJson<String?>(body),
      'seq': serializer.toJson<int>(seq),
      'status': serializer.toJson<String>(status),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'deletedForEveryone': serializer.toJson<bool>(deletedForEveryone),
      'attachmentId': serializer.toJson<String?>(attachmentId),
      'attachmentKind': serializer.toJson<String?>(attachmentKind),
      'attachmentFormat': serializer.toJson<String?>(attachmentFormat),
      'attachmentMimeType': serializer.toJson<String?>(attachmentMimeType),
      'attachmentFilename': serializer.toJson<String?>(attachmentFilename),
      'attachmentByteSize': serializer.toJson<int?>(attachmentByteSize),
      'replyToId': serializer.toJson<String?>(replyToId),
      'replySenderId': serializer.toJson<String?>(replySenderId),
      'replyType': serializer.toJson<String?>(replyType),
      'replyBody': serializer.toJson<String?>(replyBody),
      'replyAttachmentJson': serializer.toJson<String?>(replyAttachmentJson),
    };
  }

  ChatMessageRow copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? type,
    Value<String?> body = const Value.absent(),
    int? seq,
    String? status,
    int? createdAtMs,
    bool? deletedForEveryone,
    Value<String?> attachmentId = const Value.absent(),
    Value<String?> attachmentKind = const Value.absent(),
    Value<String?> attachmentFormat = const Value.absent(),
    Value<String?> attachmentMimeType = const Value.absent(),
    Value<String?> attachmentFilename = const Value.absent(),
    Value<int?> attachmentByteSize = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    Value<String?> replySenderId = const Value.absent(),
    Value<String?> replyType = const Value.absent(),
    Value<String?> replyBody = const Value.absent(),
    Value<String?> replyAttachmentJson = const Value.absent(),
  }) => ChatMessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    type: type ?? this.type,
    body: body.present ? body.value : this.body,
    seq: seq ?? this.seq,
    status: status ?? this.status,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
    attachmentId: attachmentId.present ? attachmentId.value : this.attachmentId,
    attachmentKind: attachmentKind.present
        ? attachmentKind.value
        : this.attachmentKind,
    attachmentFormat: attachmentFormat.present
        ? attachmentFormat.value
        : this.attachmentFormat,
    attachmentMimeType: attachmentMimeType.present
        ? attachmentMimeType.value
        : this.attachmentMimeType,
    attachmentFilename: attachmentFilename.present
        ? attachmentFilename.value
        : this.attachmentFilename,
    attachmentByteSize: attachmentByteSize.present
        ? attachmentByteSize.value
        : this.attachmentByteSize,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    replySenderId: replySenderId.present
        ? replySenderId.value
        : this.replySenderId,
    replyType: replyType.present ? replyType.value : this.replyType,
    replyBody: replyBody.present ? replyBody.value : this.replyBody,
    replyAttachmentJson: replyAttachmentJson.present
        ? replyAttachmentJson.value
        : this.replyAttachmentJson,
  );
  ChatMessageRow copyWithCompanion(ChatMessageRowsCompanion data) {
    return ChatMessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      type: data.type.present ? data.type.value : this.type,
      body: data.body.present ? data.body.value : this.body,
      seq: data.seq.present ? data.seq.value : this.seq,
      status: data.status.present ? data.status.value : this.status,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      deletedForEveryone: data.deletedForEveryone.present
          ? data.deletedForEveryone.value
          : this.deletedForEveryone,
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      attachmentKind: data.attachmentKind.present
          ? data.attachmentKind.value
          : this.attachmentKind,
      attachmentFormat: data.attachmentFormat.present
          ? data.attachmentFormat.value
          : this.attachmentFormat,
      attachmentMimeType: data.attachmentMimeType.present
          ? data.attachmentMimeType.value
          : this.attachmentMimeType,
      attachmentFilename: data.attachmentFilename.present
          ? data.attachmentFilename.value
          : this.attachmentFilename,
      attachmentByteSize: data.attachmentByteSize.present
          ? data.attachmentByteSize.value
          : this.attachmentByteSize,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      replySenderId: data.replySenderId.present
          ? data.replySenderId.value
          : this.replySenderId,
      replyType: data.replyType.present ? data.replyType.value : this.replyType,
      replyBody: data.replyBody.present ? data.replyBody.value : this.replyBody,
      replyAttachmentJson: data.replyAttachmentJson.present
          ? data.replyAttachmentJson.value
          : this.replyAttachmentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('seq: $seq, ')
          ..write('status: $status, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('deletedForEveryone: $deletedForEveryone, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentFormat: $attachmentFormat, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('attachmentFilename: $attachmentFilename, ')
          ..write('attachmentByteSize: $attachmentByteSize, ')
          ..write('replyToId: $replyToId, ')
          ..write('replySenderId: $replySenderId, ')
          ..write('replyType: $replyType, ')
          ..write('replyBody: $replyBody, ')
          ..write('replyAttachmentJson: $replyAttachmentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderId,
    type,
    body,
    seq,
    status,
    createdAtMs,
    deletedForEveryone,
    attachmentId,
    attachmentKind,
    attachmentFormat,
    attachmentMimeType,
    attachmentFilename,
    attachmentByteSize,
    replyToId,
    replySenderId,
    replyType,
    replyBody,
    replyAttachmentJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.type == this.type &&
          other.body == this.body &&
          other.seq == this.seq &&
          other.status == this.status &&
          other.createdAtMs == this.createdAtMs &&
          other.deletedForEveryone == this.deletedForEveryone &&
          other.attachmentId == this.attachmentId &&
          other.attachmentKind == this.attachmentKind &&
          other.attachmentFormat == this.attachmentFormat &&
          other.attachmentMimeType == this.attachmentMimeType &&
          other.attachmentFilename == this.attachmentFilename &&
          other.attachmentByteSize == this.attachmentByteSize &&
          other.replyToId == this.replyToId &&
          other.replySenderId == this.replySenderId &&
          other.replyType == this.replyType &&
          other.replyBody == this.replyBody &&
          other.replyAttachmentJson == this.replyAttachmentJson);
}

class ChatMessageRowsCompanion extends UpdateCompanion<ChatMessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> type;
  final Value<String?> body;
  final Value<int> seq;
  final Value<String> status;
  final Value<int> createdAtMs;
  final Value<bool> deletedForEveryone;
  final Value<String?> attachmentId;
  final Value<String?> attachmentKind;
  final Value<String?> attachmentFormat;
  final Value<String?> attachmentMimeType;
  final Value<String?> attachmentFilename;
  final Value<int?> attachmentByteSize;
  final Value<String?> replyToId;
  final Value<String?> replySenderId;
  final Value<String?> replyType;
  final Value<String?> replyBody;
  final Value<String?> replyAttachmentJson;
  final Value<int> rowid;
  const ChatMessageRowsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.seq = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.deletedForEveryone = const Value.absent(),
    this.attachmentId = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentFormat = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.attachmentFilename = const Value.absent(),
    this.attachmentByteSize = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replySenderId = const Value.absent(),
    this.replyType = const Value.absent(),
    this.replyBody = const Value.absent(),
    this.replyAttachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessageRowsCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    required String type,
    this.body = const Value.absent(),
    required int seq,
    required String status,
    required int createdAtMs,
    this.deletedForEveryone = const Value.absent(),
    this.attachmentId = const Value.absent(),
    this.attachmentKind = const Value.absent(),
    this.attachmentFormat = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.attachmentFilename = const Value.absent(),
    this.attachmentByteSize = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replySenderId = const Value.absent(),
    this.replyType = const Value.absent(),
    this.replyBody = const Value.absent(),
    this.replyAttachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderId = Value(senderId),
       type = Value(type),
       seq = Value(seq),
       status = Value(status),
       createdAtMs = Value(createdAtMs);
  static Insertable<ChatMessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? type,
    Expression<String>? body,
    Expression<int>? seq,
    Expression<String>? status,
    Expression<int>? createdAtMs,
    Expression<bool>? deletedForEveryone,
    Expression<String>? attachmentId,
    Expression<String>? attachmentKind,
    Expression<String>? attachmentFormat,
    Expression<String>? attachmentMimeType,
    Expression<String>? attachmentFilename,
    Expression<int>? attachmentByteSize,
    Expression<String>? replyToId,
    Expression<String>? replySenderId,
    Expression<String>? replyType,
    Expression<String>? replyBody,
    Expression<String>? replyAttachmentJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (type != null) 'type': type,
      if (body != null) 'body': body,
      if (seq != null) 'seq': seq,
      if (status != null) 'status': status,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (deletedForEveryone != null)
        'deleted_for_everyone': deletedForEveryone,
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (attachmentKind != null) 'attachment_kind': attachmentKind,
      if (attachmentFormat != null) 'attachment_format': attachmentFormat,
      if (attachmentMimeType != null)
        'attachment_mime_type': attachmentMimeType,
      if (attachmentFilename != null) 'attachment_filename': attachmentFilename,
      if (attachmentByteSize != null)
        'attachment_byte_size': attachmentByteSize,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replySenderId != null) 'reply_sender_id': replySenderId,
      if (replyType != null) 'reply_type': replyType,
      if (replyBody != null) 'reply_body': replyBody,
      if (replyAttachmentJson != null)
        'reply_attachment_json': replyAttachmentJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessageRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderId,
    Value<String>? type,
    Value<String?>? body,
    Value<int>? seq,
    Value<String>? status,
    Value<int>? createdAtMs,
    Value<bool>? deletedForEveryone,
    Value<String?>? attachmentId,
    Value<String?>? attachmentKind,
    Value<String?>? attachmentFormat,
    Value<String?>? attachmentMimeType,
    Value<String?>? attachmentFilename,
    Value<int?>? attachmentByteSize,
    Value<String?>? replyToId,
    Value<String?>? replySenderId,
    Value<String?>? replyType,
    Value<String?>? replyBody,
    Value<String?>? replyAttachmentJson,
    Value<int>? rowid,
  }) {
    return ChatMessageRowsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      body: body ?? this.body,
      seq: seq ?? this.seq,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      attachmentId: attachmentId ?? this.attachmentId,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentFormat: attachmentFormat ?? this.attachmentFormat,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentFilename: attachmentFilename ?? this.attachmentFilename,
      attachmentByteSize: attachmentByteSize ?? this.attachmentByteSize,
      replyToId: replyToId ?? this.replyToId,
      replySenderId: replySenderId ?? this.replySenderId,
      replyType: replyType ?? this.replyType,
      replyBody: replyBody ?? this.replyBody,
      replyAttachmentJson: replyAttachmentJson ?? this.replyAttachmentJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (deletedForEveryone.present) {
      map['deleted_for_everyone'] = Variable<bool>(deletedForEveryone.value);
    }
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
    }
    if (attachmentKind.present) {
      map['attachment_kind'] = Variable<String>(attachmentKind.value);
    }
    if (attachmentFormat.present) {
      map['attachment_format'] = Variable<String>(attachmentFormat.value);
    }
    if (attachmentMimeType.present) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType.value);
    }
    if (attachmentFilename.present) {
      map['attachment_filename'] = Variable<String>(attachmentFilename.value);
    }
    if (attachmentByteSize.present) {
      map['attachment_byte_size'] = Variable<int>(attachmentByteSize.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (replySenderId.present) {
      map['reply_sender_id'] = Variable<String>(replySenderId.value);
    }
    if (replyType.present) {
      map['reply_type'] = Variable<String>(replyType.value);
    }
    if (replyBody.present) {
      map['reply_body'] = Variable<String>(replyBody.value);
    }
    if (replyAttachmentJson.present) {
      map['reply_attachment_json'] = Variable<String>(
        replyAttachmentJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRowsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('seq: $seq, ')
          ..write('status: $status, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('deletedForEveryone: $deletedForEveryone, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('attachmentKind: $attachmentKind, ')
          ..write('attachmentFormat: $attachmentFormat, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('attachmentFilename: $attachmentFilename, ')
          ..write('attachmentByteSize: $attachmentByteSize, ')
          ..write('replyToId: $replyToId, ')
          ..write('replySenderId: $replySenderId, ')
          ..write('replyType: $replyType, ')
          ..write('replyBody: $replyBody, ')
          ..write('replyAttachmentJson: $replyAttachmentJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMessageRowsTable extends PendingMessageRows
    with TableInfo<$PendingMessageRowsTable, PendingMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMessageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    idempotencyKey,
    conversationId,
    content,
    replyToMessageId,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_message_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idempotencyKey};
  @override
  PendingMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMessageRow(
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $PendingMessageRowsTable createAlias(String alias) {
    return $PendingMessageRowsTable(attachedDatabase, alias);
  }
}

class PendingMessageRow extends DataClass
    implements Insertable<PendingMessageRow> {
  final String idempotencyKey;
  final String conversationId;
  final String? content;
  final String? replyToMessageId;
  final int createdAtMs;
  const PendingMessageRow({
    required this.idempotencyKey,
    required this.conversationId,
    this.content,
    this.replyToMessageId,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  PendingMessageRowsCompanion toCompanion(bool nullToAbsent) {
    return PendingMessageRowsCompanion(
      idempotencyKey: Value(idempotencyKey),
      conversationId: Value(conversationId),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory PendingMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMessageRow(
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      content: serializer.fromJson<String?>(json['content']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'conversationId': serializer.toJson<String>(conversationId),
      'content': serializer.toJson<String?>(content),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  PendingMessageRow copyWith({
    String? idempotencyKey,
    String? conversationId,
    Value<String?> content = const Value.absent(),
    Value<String?> replyToMessageId = const Value.absent(),
    int? createdAtMs,
  }) => PendingMessageRow(
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    conversationId: conversationId ?? this.conversationId,
    content: content.present ? content.value : this.content,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  PendingMessageRow copyWithCompanion(PendingMessageRowsCompanion data) {
    return PendingMessageRow(
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      content: data.content.present ? data.content.value : this.content,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMessageRow(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idempotencyKey,
    conversationId,
    content,
    replyToMessageId,
    createdAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMessageRow &&
          other.idempotencyKey == this.idempotencyKey &&
          other.conversationId == this.conversationId &&
          other.content == this.content &&
          other.replyToMessageId == this.replyToMessageId &&
          other.createdAtMs == this.createdAtMs);
}

class PendingMessageRowsCompanion extends UpdateCompanion<PendingMessageRow> {
  final Value<String> idempotencyKey;
  final Value<String> conversationId;
  final Value<String?> content;
  final Value<String?> replyToMessageId;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const PendingMessageRowsCompanion({
    this.idempotencyKey = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.content = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMessageRowsCompanion.insert({
    required String idempotencyKey,
    required String conversationId,
    this.content = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : idempotencyKey = Value(idempotencyKey),
       conversationId = Value(conversationId),
       createdAtMs = Value(createdAtMs);
  static Insertable<PendingMessageRow> custom({
    Expression<String>? idempotencyKey,
    Expression<String>? conversationId,
    Expression<String>? content,
    Expression<String>? replyToMessageId,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (conversationId != null) 'conversation_id': conversationId,
      if (content != null) 'content': content,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMessageRowsCompanion copyWith({
    Value<String>? idempotencyKey,
    Value<String>? conversationId,
    Value<String?>? content,
    Value<String?>? replyToMessageId,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return PendingMessageRowsCompanion(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMessageRowsCompanion(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatDatabase extends GeneratedDatabase {
  _$ChatDatabase(QueryExecutor e) : super(e);
  $ChatDatabaseManager get managers => $ChatDatabaseManager(this);
  late final $ChatConversationRowsTable chatConversationRows =
      $ChatConversationRowsTable(this);
  late final $ChatMessageRowsTable chatMessageRows = $ChatMessageRowsTable(
    this,
  );
  late final $PendingMessageRowsTable pendingMessageRows =
      $PendingMessageRowsTable(this);
  late final Index idxMessageConversationSeq = Index(
    'idx_message_conversation_seq',
    'CREATE INDEX idx_message_conversation_seq ON chat_message_rows (conversation_id, seq)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatConversationRows,
    chatMessageRows,
    pendingMessageRows,
    idxMessageConversationSeq,
  ];
}

typedef $$ChatConversationRowsTableCreateCompanionBuilder =
    ChatConversationRowsCompanion Function({
      required String id,
      required String participantIds,
      Value<String?> counterpartUserId,
      Value<String?> counterpartExternalId,
      required int createdAtMs,
      Value<int?> lastMessageAtMs,
      Value<String?> myUserId,
      Value<String?> nextCursor,
      Value<int> syncedAtMs,
      Value<int> rowid,
    });
typedef $$ChatConversationRowsTableUpdateCompanionBuilder =
    ChatConversationRowsCompanion Function({
      Value<String> id,
      Value<String> participantIds,
      Value<String?> counterpartUserId,
      Value<String?> counterpartExternalId,
      Value<int> createdAtMs,
      Value<int?> lastMessageAtMs,
      Value<String?> myUserId,
      Value<String?> nextCursor,
      Value<int> syncedAtMs,
      Value<int> rowid,
    });

class $$ChatConversationRowsTableFilterComposer
    extends Composer<_$ChatDatabase, $ChatConversationRowsTable> {
  $$ChatConversationRowsTableFilterComposer({
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

  ColumnFilters<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpartUserId => $composableBuilder(
    column: $table.counterpartUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpartExternalId => $composableBuilder(
    column: $table.counterpartExternalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageAtMs => $composableBuilder(
    column: $table.lastMessageAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get myUserId => $composableBuilder(
    column: $table.myUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatConversationRowsTableOrderingComposer
    extends Composer<_$ChatDatabase, $ChatConversationRowsTable> {
  $$ChatConversationRowsTableOrderingComposer({
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

  ColumnOrderings<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpartUserId => $composableBuilder(
    column: $table.counterpartUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpartExternalId => $composableBuilder(
    column: $table.counterpartExternalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageAtMs => $composableBuilder(
    column: $table.lastMessageAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get myUserId => $composableBuilder(
    column: $table.myUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatConversationRowsTableAnnotationComposer
    extends Composer<_$ChatDatabase, $ChatConversationRowsTable> {
  $$ChatConversationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterpartUserId => $composableBuilder(
    column: $table.counterpartUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterpartExternalId => $composableBuilder(
    column: $table.counterpartExternalId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageAtMs => $composableBuilder(
    column: $table.lastMessageAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get myUserId =>
      $composableBuilder(column: $table.myUserId, builder: (column) => column);

  GeneratedColumn<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAtMs => $composableBuilder(
    column: $table.syncedAtMs,
    builder: (column) => column,
  );
}

class $$ChatConversationRowsTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $ChatConversationRowsTable,
          ChatConversationRow,
          $$ChatConversationRowsTableFilterComposer,
          $$ChatConversationRowsTableOrderingComposer,
          $$ChatConversationRowsTableAnnotationComposer,
          $$ChatConversationRowsTableCreateCompanionBuilder,
          $$ChatConversationRowsTableUpdateCompanionBuilder,
          (
            ChatConversationRow,
            BaseReferences<
              _$ChatDatabase,
              $ChatConversationRowsTable,
              ChatConversationRow
            >,
          ),
          ChatConversationRow,
          PrefetchHooks Function()
        > {
  $$ChatConversationRowsTableTableManager(
    _$ChatDatabase db,
    $ChatConversationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatConversationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatConversationRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ChatConversationRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> participantIds = const Value.absent(),
                Value<String?> counterpartUserId = const Value.absent(),
                Value<String?> counterpartExternalId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int?> lastMessageAtMs = const Value.absent(),
                Value<String?> myUserId = const Value.absent(),
                Value<String?> nextCursor = const Value.absent(),
                Value<int> syncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatConversationRowsCompanion(
                id: id,
                participantIds: participantIds,
                counterpartUserId: counterpartUserId,
                counterpartExternalId: counterpartExternalId,
                createdAtMs: createdAtMs,
                lastMessageAtMs: lastMessageAtMs,
                myUserId: myUserId,
                nextCursor: nextCursor,
                syncedAtMs: syncedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String participantIds,
                Value<String?> counterpartUserId = const Value.absent(),
                Value<String?> counterpartExternalId = const Value.absent(),
                required int createdAtMs,
                Value<int?> lastMessageAtMs = const Value.absent(),
                Value<String?> myUserId = const Value.absent(),
                Value<String?> nextCursor = const Value.absent(),
                Value<int> syncedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatConversationRowsCompanion.insert(
                id: id,
                participantIds: participantIds,
                counterpartUserId: counterpartUserId,
                counterpartExternalId: counterpartExternalId,
                createdAtMs: createdAtMs,
                lastMessageAtMs: lastMessageAtMs,
                myUserId: myUserId,
                nextCursor: nextCursor,
                syncedAtMs: syncedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatConversationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $ChatConversationRowsTable,
      ChatConversationRow,
      $$ChatConversationRowsTableFilterComposer,
      $$ChatConversationRowsTableOrderingComposer,
      $$ChatConversationRowsTableAnnotationComposer,
      $$ChatConversationRowsTableCreateCompanionBuilder,
      $$ChatConversationRowsTableUpdateCompanionBuilder,
      (
        ChatConversationRow,
        BaseReferences<
          _$ChatDatabase,
          $ChatConversationRowsTable,
          ChatConversationRow
        >,
      ),
      ChatConversationRow,
      PrefetchHooks Function()
    >;
typedef $$ChatMessageRowsTableCreateCompanionBuilder =
    ChatMessageRowsCompanion Function({
      required String id,
      required String conversationId,
      required String senderId,
      required String type,
      Value<String?> body,
      required int seq,
      required String status,
      required int createdAtMs,
      Value<bool> deletedForEveryone,
      Value<String?> attachmentId,
      Value<String?> attachmentKind,
      Value<String?> attachmentFormat,
      Value<String?> attachmentMimeType,
      Value<String?> attachmentFilename,
      Value<int?> attachmentByteSize,
      Value<String?> replyToId,
      Value<String?> replySenderId,
      Value<String?> replyType,
      Value<String?> replyBody,
      Value<String?> replyAttachmentJson,
      Value<int> rowid,
    });
typedef $$ChatMessageRowsTableUpdateCompanionBuilder =
    ChatMessageRowsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderId,
      Value<String> type,
      Value<String?> body,
      Value<int> seq,
      Value<String> status,
      Value<int> createdAtMs,
      Value<bool> deletedForEveryone,
      Value<String?> attachmentId,
      Value<String?> attachmentKind,
      Value<String?> attachmentFormat,
      Value<String?> attachmentMimeType,
      Value<String?> attachmentFilename,
      Value<int?> attachmentByteSize,
      Value<String?> replyToId,
      Value<String?> replySenderId,
      Value<String?> replyType,
      Value<String?> replyBody,
      Value<String?> replyAttachmentJson,
      Value<int> rowid,
    });

class $$ChatMessageRowsTableFilterComposer
    extends Composer<_$ChatDatabase, $ChatMessageRowsTable> {
  $$ChatMessageRowsTableFilterComposer({
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

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deletedForEveryone => $composableBuilder(
    column: $table.deletedForEveryone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentKind => $composableBuilder(
    column: $table.attachmentKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentFormat => $composableBuilder(
    column: $table.attachmentFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentFilename => $composableBuilder(
    column: $table.attachmentFilename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attachmentByteSize => $composableBuilder(
    column: $table.attachmentByteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replySenderId => $composableBuilder(
    column: $table.replySenderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyType => $composableBuilder(
    column: $table.replyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyBody => $composableBuilder(
    column: $table.replyBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyAttachmentJson => $composableBuilder(
    column: $table.replyAttachmentJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessageRowsTableOrderingComposer
    extends Composer<_$ChatDatabase, $ChatMessageRowsTable> {
  $$ChatMessageRowsTableOrderingComposer({
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

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedForEveryone => $composableBuilder(
    column: $table.deletedForEveryone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentKind => $composableBuilder(
    column: $table.attachmentKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentFormat => $composableBuilder(
    column: $table.attachmentFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentFilename => $composableBuilder(
    column: $table.attachmentFilename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attachmentByteSize => $composableBuilder(
    column: $table.attachmentByteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replySenderId => $composableBuilder(
    column: $table.replySenderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyType => $composableBuilder(
    column: $table.replyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyBody => $composableBuilder(
    column: $table.replyBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyAttachmentJson => $composableBuilder(
    column: $table.replyAttachmentJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessageRowsTableAnnotationComposer
    extends Composer<_$ChatDatabase, $ChatMessageRowsTable> {
  $$ChatMessageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deletedForEveryone => $composableBuilder(
    column: $table.deletedForEveryone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentKind => $composableBuilder(
    column: $table.attachmentKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentFormat => $composableBuilder(
    column: $table.attachmentFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentFilename => $composableBuilder(
    column: $table.attachmentFilename,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attachmentByteSize => $composableBuilder(
    column: $table.attachmentByteSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get replySenderId => $composableBuilder(
    column: $table.replySenderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyType =>
      $composableBuilder(column: $table.replyType, builder: (column) => column);

  GeneratedColumn<String> get replyBody =>
      $composableBuilder(column: $table.replyBody, builder: (column) => column);

  GeneratedColumn<String> get replyAttachmentJson => $composableBuilder(
    column: $table.replyAttachmentJson,
    builder: (column) => column,
  );
}

class $$ChatMessageRowsTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $ChatMessageRowsTable,
          ChatMessageRow,
          $$ChatMessageRowsTableFilterComposer,
          $$ChatMessageRowsTableOrderingComposer,
          $$ChatMessageRowsTableAnnotationComposer,
          $$ChatMessageRowsTableCreateCompanionBuilder,
          $$ChatMessageRowsTableUpdateCompanionBuilder,
          (
            ChatMessageRow,
            BaseReferences<
              _$ChatDatabase,
              $ChatMessageRowsTable,
              ChatMessageRow
            >,
          ),
          ChatMessageRow,
          PrefetchHooks Function()
        > {
  $$ChatMessageRowsTableTableManager(
    _$ChatDatabase db,
    $ChatMessageRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessageRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<bool> deletedForEveryone = const Value.absent(),
                Value<String?> attachmentId = const Value.absent(),
                Value<String?> attachmentKind = const Value.absent(),
                Value<String?> attachmentFormat = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<String?> attachmentFilename = const Value.absent(),
                Value<int?> attachmentByteSize = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> replySenderId = const Value.absent(),
                Value<String?> replyType = const Value.absent(),
                Value<String?> replyBody = const Value.absent(),
                Value<String?> replyAttachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessageRowsCompanion(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                seq: seq,
                status: status,
                createdAtMs: createdAtMs,
                deletedForEveryone: deletedForEveryone,
                attachmentId: attachmentId,
                attachmentKind: attachmentKind,
                attachmentFormat: attachmentFormat,
                attachmentMimeType: attachmentMimeType,
                attachmentFilename: attachmentFilename,
                attachmentByteSize: attachmentByteSize,
                replyToId: replyToId,
                replySenderId: replySenderId,
                replyType: replyType,
                replyBody: replyBody,
                replyAttachmentJson: replyAttachmentJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderId,
                required String type,
                Value<String?> body = const Value.absent(),
                required int seq,
                required String status,
                required int createdAtMs,
                Value<bool> deletedForEveryone = const Value.absent(),
                Value<String?> attachmentId = const Value.absent(),
                Value<String?> attachmentKind = const Value.absent(),
                Value<String?> attachmentFormat = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<String?> attachmentFilename = const Value.absent(),
                Value<int?> attachmentByteSize = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> replySenderId = const Value.absent(),
                Value<String?> replyType = const Value.absent(),
                Value<String?> replyBody = const Value.absent(),
                Value<String?> replyAttachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessageRowsCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                seq: seq,
                status: status,
                createdAtMs: createdAtMs,
                deletedForEveryone: deletedForEveryone,
                attachmentId: attachmentId,
                attachmentKind: attachmentKind,
                attachmentFormat: attachmentFormat,
                attachmentMimeType: attachmentMimeType,
                attachmentFilename: attachmentFilename,
                attachmentByteSize: attachmentByteSize,
                replyToId: replyToId,
                replySenderId: replySenderId,
                replyType: replyType,
                replyBody: replyBody,
                replyAttachmentJson: replyAttachmentJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $ChatMessageRowsTable,
      ChatMessageRow,
      $$ChatMessageRowsTableFilterComposer,
      $$ChatMessageRowsTableOrderingComposer,
      $$ChatMessageRowsTableAnnotationComposer,
      $$ChatMessageRowsTableCreateCompanionBuilder,
      $$ChatMessageRowsTableUpdateCompanionBuilder,
      (
        ChatMessageRow,
        BaseReferences<_$ChatDatabase, $ChatMessageRowsTable, ChatMessageRow>,
      ),
      ChatMessageRow,
      PrefetchHooks Function()
    >;
typedef $$PendingMessageRowsTableCreateCompanionBuilder =
    PendingMessageRowsCompanion Function({
      required String idempotencyKey,
      required String conversationId,
      Value<String?> content,
      Value<String?> replyToMessageId,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$PendingMessageRowsTableUpdateCompanionBuilder =
    PendingMessageRowsCompanion Function({
      Value<String> idempotencyKey,
      Value<String> conversationId,
      Value<String?> content,
      Value<String?> replyToMessageId,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$PendingMessageRowsTableFilterComposer
    extends Composer<_$ChatDatabase, $PendingMessageRowsTable> {
  $$PendingMessageRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMessageRowsTableOrderingComposer
    extends Composer<_$ChatDatabase, $PendingMessageRowsTable> {
  $$PendingMessageRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMessageRowsTableAnnotationComposer
    extends Composer<_$ChatDatabase, $PendingMessageRowsTable> {
  $$PendingMessageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$PendingMessageRowsTableTableManager
    extends
        RootTableManager<
          _$ChatDatabase,
          $PendingMessageRowsTable,
          PendingMessageRow,
          $$PendingMessageRowsTableFilterComposer,
          $$PendingMessageRowsTableOrderingComposer,
          $$PendingMessageRowsTableAnnotationComposer,
          $$PendingMessageRowsTableCreateCompanionBuilder,
          $$PendingMessageRowsTableUpdateCompanionBuilder,
          (
            PendingMessageRow,
            BaseReferences<
              _$ChatDatabase,
              $PendingMessageRowsTable,
              PendingMessageRow
            >,
          ),
          PendingMessageRow,
          PrefetchHooks Function()
        > {
  $$PendingMessageRowsTableTableManager(
    _$ChatDatabase db,
    $PendingMessageRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMessageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMessageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMessageRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMessageRowsCompanion(
                idempotencyKey: idempotencyKey,
                conversationId: conversationId,
                content: content,
                replyToMessageId: replyToMessageId,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String idempotencyKey,
                required String conversationId,
                Value<String?> content = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => PendingMessageRowsCompanion.insert(
                idempotencyKey: idempotencyKey,
                conversationId: conversationId,
                content: content,
                replyToMessageId: replyToMessageId,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMessageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatDatabase,
      $PendingMessageRowsTable,
      PendingMessageRow,
      $$PendingMessageRowsTableFilterComposer,
      $$PendingMessageRowsTableOrderingComposer,
      $$PendingMessageRowsTableAnnotationComposer,
      $$PendingMessageRowsTableCreateCompanionBuilder,
      $$PendingMessageRowsTableUpdateCompanionBuilder,
      (
        PendingMessageRow,
        BaseReferences<
          _$ChatDatabase,
          $PendingMessageRowsTable,
          PendingMessageRow
        >,
      ),
      PendingMessageRow,
      PrefetchHooks Function()
    >;

class $ChatDatabaseManager {
  final _$ChatDatabase _db;
  $ChatDatabaseManager(this._db);
  $$ChatConversationRowsTableTableManager get chatConversationRows =>
      $$ChatConversationRowsTableTableManager(_db, _db.chatConversationRows);
  $$ChatMessageRowsTableTableManager get chatMessageRows =>
      $$ChatMessageRowsTableTableManager(_db, _db.chatMessageRows);
  $$PendingMessageRowsTableTableManager get pendingMessageRows =>
      $$PendingMessageRowsTableTableManager(_db, _db.pendingMessageRows);
}
