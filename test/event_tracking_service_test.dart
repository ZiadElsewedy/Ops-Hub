import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/audit/domain/entities/audit_actor.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';
import 'package:opshub/features/audit/domain/repositories/audit_repository.dart';
import 'package:opshub/features/audit/domain/services/event_tracking_service.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// Records what the service asks the repository to persist, and can be told to
/// throw so we can prove tracking is fire-and-forget-safe.
class _FakeAuditRepository implements AuditRepository {
  final List<AuditLogEntry> recorded = [];
  final List<({String id, String by})> softDeleted = [];
  bool throwOnRecord = false;

  @override
  Future<void> record(AuditLogEntry entry) async {
    if (throwOnRecord) throw Exception('boom');
    recorded.add(entry);
  }

  @override
  Future<void> softDelete(String id, {required String deletedBy}) async {
    softDeleted.add((id: id, by: deletedBy));
  }

  // Unused read methods for these write-side tests.
  @override
  Future<List<AuditLogEntry>> recent(
          {int limit = 50, DateTime? before, bool includeDeleted = false}) async =>
      const [];
  @override
  Stream<List<AuditLogEntry>> watchRecent({int limit = 50}) =>
      const Stream.empty();
  @override
  Future<List<AuditLogEntry>> forEntity(AuditEntityType entityType, String entityId,
          {int limit = 50, DateTime? before, bool includeDeleted = false}) async =>
      const [];
  @override
  Future<List<AuditLogEntry>> forActor(String actorId,
          {int limit = 50, DateTime? before, bool includeDeleted = false}) async =>
      const [];
  @override
  Future<List<AuditLogEntry>> forBranch(String branchId,
          {int limit = 50, DateTime? before, bool includeDeleted = false}) async =>
      const [];
  @override
  Future<List<AuditLogEntry>> inDateRange(DateTime from, DateTime to,
          {int limit = 100, bool includeDeleted = false}) async =>
      const [];
}

const _manager = UserEntity(
  uid: 'mgr-1',
  email: 'mgr@drop.app',
  authProvider: 'password',
  displayName: 'Manager Mo',
  role: UserRole.manager,
  branchId: 'branch-A',
);

void main() {
  late _FakeAuditRepository repo;
  late EventTrackingService service;

  setUp(() {
    repo = _FakeAuditRepository();
    service = EventTrackingService(repo);
  });

  test('builds a complete WHO/WHAT/WHICH/WHERE record from the actor', () async {
    await service.trackEvent(
      type: AuditEventType.taskApproved,
      actor: AuditActor.of(_manager),
      entityId: 'task-42',
      metadata: {'priority': 'high'},
    );

    expect(repo.recorded, hasLength(1));
    final e = repo.recorded.single;
    expect(e.eventType, AuditEventType.taskApproved); // WHAT
    expect(e.entityType, AuditEntityType.task); // defaulted from the event
    expect(e.entityId, 'task-42'); // WHICH
    expect(e.actorId, 'mgr-1'); // WHO
    expect(e.actorName, 'Manager Mo');
    expect(e.actorRole, UserRole.manager);
    expect(e.branchId, 'branch-A'); // WHERE (defaulted from the actor)
    expect(e.schemaVersion, kAuditSchemaVersion);
    expect(e.metadata['priority'], 'high');
    // WHEN is stamped server-side, so the built entry leaves it null.
    expect(e.timestamp, isNull);
    expect(e.isDeleted, isFalse);
  });

  test('explicit entityType + branchId override the actor defaults', () async {
    await service.trackEvent(
      type: AuditEventType.broadcastSent,
      actor: AuditActor.of(_manager),
      entityId: 'bc-1',
      entityType: AuditEntityType.broadcast,
      branchId: '', // all-branches marker
    );
    final e = repo.recorded.single;
    expect(e.entityType, AuditEntityType.broadcast);
    expect(e.branchId, '');
  });

  test('drops an event with an empty entityId (never persists a bad record)',
      () async {
    await service.trackEvent(
      type: AuditEventType.taskApproved,
      actor: AuditActor.of(_manager),
      entityId: '',
    );
    expect(repo.recorded, isEmpty);
  });

  test('drops an event with an invalid schemaVersion', () async {
    await service.trackEvent(
      type: AuditEventType.taskApproved,
      actor: AuditActor.of(_manager),
      entityId: 't-1',
      schemaVersion: 0,
    );
    expect(repo.recorded, isEmpty);
  });

  test('strips null + non-serializable metadata values', () async {
    await service.trackEvent(
      type: AuditEventType.taskAssigned,
      actor: AuditActor.of(_manager),
      entityId: 't-1',
      metadata: {
        'keep': 1,
        'gone': null,
        'when': DateTime.utc(2026, 1, 1),
        'bad': Object(),
      },
    );
    final md = repo.recorded.single.metadata;
    expect(md.containsKey('keep'), isTrue);
    expect(md.containsKey('when'), isTrue); // DateTime is allowed
    expect(md.containsKey('gone'), isFalse);
    expect(md.containsKey('bad'), isFalse);
  });

  test('is fire-and-forget: a repository failure never throws', () async {
    repo.throwOnRecord = true;
    // Must complete normally — the business flow must never see an audit error.
    await expectLater(
      service.trackEvent(
        type: AuditEventType.taskApproved,
        actor: AuditActor.of(_manager),
        entityId: 't-1',
      ),
      completes,
    );
    expect(repo.recorded, isEmpty);
  });

  test('softDelete delegates to the repository with the actor id', () async {
    await service.softDelete('rec-1', actor: AuditActor.of(_manager));
    expect(repo.softDeleted.single.id, 'rec-1');
    expect(repo.softDeleted.single.by, 'mgr-1');
  });

  test('AuditActor.of falls back to the email when there is no display name',
      () {
    const noName = UserEntity(
      uid: 'u-1',
      email: 'someone@drop.app',
      authProvider: 'password',
    );
    final actor = AuditActor.of(noName);
    expect(actor.name, 'someone@drop.app');
    expect(actor.isAttributed, isTrue);
  });
}
