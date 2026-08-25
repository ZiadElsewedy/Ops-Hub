import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/sales/domain/sales_branch_scope.dart';
import 'package:flutter_test/flutter_test.dart';

BranchEntity _branch(
  String id,
  String name, {
  bool enabled = true,
  DateTime? deletedAt,
}) => BranchEntity(
  id: id,
  name: name,
  salesTargetEnabled: enabled,
  deletedAt: deletedAt,
);

void main() {
  test('only branches that opted in are in scope', () {
    final scope = salesEnabledBranches([
      _branch('b1', 'Arkan'),
      _branch('b2', 'Zamalek', enabled: false),
      _branch('b3', 'Maadi'),
    ]);

    expect(scope.map((b) => b.id), ['b1', 'b3']);
  });

  test('an opted-out estate yields an empty scope, never a partial one', () {
    expect(
      salesEnabledBranches([
        _branch('b1', 'Arkan', enabled: false),
        _branch('b2', 'Maadi', enabled: false),
      ]),
      isEmpty,
    );
    expect(salesEnabledBranches(const []), isEmpty);
  });

  test('a closed branch drops out even while its flag is still on', () {
    final scope = salesEnabledBranches([
      _branch('b1', 'Arkan'),
      _branch('b2', 'Old Town', deletedAt: DateTime(2026, 7, 1)),
    ]);

    expect(scope.map((b) => b.id), ['b1']);
  });

  test('scope is ordered by name, case-insensitively', () {
    final scope = salesEnabledBranches([
      _branch('b1', 'zamalek'),
      _branch('b2', 'Arkan'),
      _branch('b3', 'maadi'),
    ]);

    expect(scope.map((b) => b.name), ['Arkan', 'maadi', 'zamalek']);
  });

  test('the input collection is not mutated', () {
    final input = [
      _branch('b1', 'Zamalek'),
      _branch('b2', 'Arkan'),
    ];
    salesEnabledBranches(input);
    expect(input.map((b) => b.id), ['b1', 'b2']);
  });
}
