import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/features/audit/data/datasources/audit_remote_datasource.dart';
import 'package:opshub/features/audit/data/models/audit_log_model.dart';
import 'package:opshub/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';

AuditLogModel _model(String id, {bool deleted = false}) => AuditLogModel(
      id: id,
      eventType: AuditEventType.taskApproved,
      entityType: AuditEntityType.task,
      entityId: 't-$id',
      actorId: 'u-1',
      branchId: 'branch-A',
      timestamp: DateTime.utc(2026, 7, 10),
      isDeleted: deleted,
    );

/// Fake datasource: returns a fixed page and records the arguments it was called
/// with, so we can assert the repository's delegation + filtering.
class _FakeDataSource implements AuditRemoteDataSource {
  List<AuditLogModel> page = [];
  final List<AuditLogEntry> recorded = [];
  final List<({String id, String by})> softDeleted = [];

  ({String type, String id, int limit, DateTime? before})? lastEntityCall;
  ({String actor, int limit, DateTime? before})? lastActorCall;
  ({String branch, int limit, DateTime? before})? lastBranchCall;
  ({int limit, DateTime? before})? lastRecentCall;
  ({DateTime from, DateTime to, int limit})? lastRangeCall;

  @override
  Future<void> record(AuditLogModel model) async =>
      recorded.add(model.toEntity());

  @override
  Stream<List<AuditLogModel>> watchRecent({int limit = 50}) =>
      Stream.value(page);

  @override
  Future<List<AuditLogModel>> recent({int limit = 50, DateTime? before}) async {
    lastRecentCall = (limit: limit, before: before);
    return page;
  }

  @override
  Future<List<AuditLogModel>> forEntity(String entityType, String entityId,
      {int limit = 50, DateTime? before}) async {
    lastEntityCall =
        (type: entityType, id: entityId, limit: limit, before: before);
    return page;
  }

  @override
  Future<List<AuditLogModel>> forActor(String actorId,
      {int limit = 50, DateTime? before}) async {
    lastActorCall = (actor: actorId, limit: limit, before: before);
    return page;
  }

  @override
  Future<List<AuditLogModel>> forBranch(String branchId,
      {int limit = 50, DateTime? before}) async {
    lastBranchCall = (branch: branchId, limit: limit, before: before);
    return page;
  }

  @override
  Future<List<AuditLogModel>> inDateRange(DateTime from, DateTime to,
      {int limit = 100}) async {
    lastRangeCall = (from: from, to: to, limit: limit);
    return page;
  }

  @override
  Future<void> softDelete(String id, {required String deletedBy}) async =>
      softDeleted.add((id: id, by: deletedBy));
}

void main() {
  late _FakeDataSource ds;
  late AuditRepositoryImpl repo;

  setUp(() {
    ds = _FakeDataSource();
    repo = AuditRepositoryImpl(ds);
  });

  group('soft-delete filtering', () {
    test('recent() excludes soft-deleted records by default', () async {
      ds.page = [_model('a'), _model('b', deleted: true), _model('c')];
      final out = await repo.recent();
      expect(out.map((e) => e.id), ['a', 'c']);
    });

    test('includeDeleted: true keeps them (audit-of-the-audit)', () async {
      ds.page = [_model('a'), _model('b', deleted: true)];
      final out = await repo.recent(includeDeleted: true);
      expect(out.map((e) => e.id), ['a', 'b']);
    });

    test('watchRecent never surfaces soft-deleted records', () async {
      ds.page = [_model('a', deleted: true), _model('b')];
      final out = await repo.watchRecent().first;
      expect(out.map((e) => e.id), ['b']);
    });

    test('forEntity also filters deleted by default', () async {
      ds.page = [_model('a', deleted: true), _model('b')];
      final out = await repo.forEntity(AuditEntityType.task, 't-b');
      expect(out.map((e) => e.id), ['b']);
    });
  });

  group('mapping + delegation', () {
    test('maps models to domain entities', () async {
      ds.page = [_model('a')];
      final out = await repo.recent();
      expect(out.single, isA<AuditLogEntry>());
      expect(out.single.eventType, AuditEventType.taskApproved);
      expect(out.single.entityId, 't-a');
    });

    test('recent() passes the paging cursor through', () async {
      final before = DateTime.utc(2026, 7, 1);
      await repo.recent(limit: 10, before: before);
      expect(ds.lastRecentCall!.limit, 10);
      expect(ds.lastRecentCall!.before, before);
    });

    test('forEntity passes the entity type value + id', () async {
      await repo.forEntity(AuditEntityType.request, 'req-9', limit: 5);
      expect(ds.lastEntityCall!.type, 'request');
      expect(ds.lastEntityCall!.id, 'req-9');
      expect(ds.lastEntityCall!.limit, 5);
    });

    test('forActor / forBranch / inDateRange delegate correctly', () async {
      final from = DateTime.utc(2026, 1, 1);
      final to = DateTime.utc(2026, 12, 31);
      await repo.forActor('u-7');
      await repo.forBranch('branch-Z');
      await repo.inDateRange(from, to, limit: 200);
      expect(ds.lastActorCall!.actor, 'u-7');
      expect(ds.lastBranchCall!.branch, 'branch-Z');
      expect(ds.lastRangeCall!.from, from);
      expect(ds.lastRangeCall!.to, to);
      expect(ds.lastRangeCall!.limit, 200);
    });

    test('record() maps the entity to a model and delegates', () async {
      const entry = AuditLogEntry(
        id: '',
        eventType: AuditEventType.taskStarted,
        entityType: AuditEntityType.task,
        entityId: 't-1',
        actorId: 'u-1',
      );
      await repo.record(entry);
      expect(ds.recorded.single.entityId, 't-1');
      expect(ds.recorded.single.eventType, AuditEventType.taskStarted);
    });

    test('softDelete delegates the id + deletedBy', () async {
      await repo.softDelete('rec-1', deletedBy: 'admin-1');
      expect(ds.softDeleted.single.id, 'rec-1');
      expect(ds.softDeleted.single.by, 'admin-1');
    });
  });
}
