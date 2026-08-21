import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/features/branch/data/models/branch_model.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';

void main() {
  group('BranchModel media fields (§8)', () {
    test('fromMap reads logoUrl/coverUrl', () {
      final m = BranchModel.fromMap(
        {'name': 'DROP Arkan', 'logoUrl': 'l.jpg', 'coverUrl': 'c.jpg'},
        id: 'b1',
      );
      expect(m.logoUrl, 'l.jpg');
      expect(m.coverUrl, 'c.jpg');
      expect(m.toEntity().logoUrl, 'l.jpg');
      expect(m.toEntity().coverUrl, 'c.jpg');
    });

    test('toMap EXCLUDES media (so an edit-form save never clobbers a logo)', () {
      final m = BranchModel.fromEntity(const BranchEntity(
        id: 'b1',
        name: 'X',
        logoUrl: 'l.jpg',
        coverUrl: 'c.jpg',
      ));
      expect(m.toMap().containsKey('logoUrl'), isFalse);
      expect(m.toMap().containsKey('coverUrl'), isFalse);
    });

    test('fromEntity + copyWithId carry the media through', () {
      const e = BranchEntity(id: '', name: 'X', logoUrl: 'l', coverUrl: 'c');
      final m = BranchModel.fromEntity(e).copyWithId('b9');
      expect(m.id, 'b9');
      expect(m.logoUrl, 'l');
      expect(m.coverUrl, 'c');
    });

    test('missing media defaults to null', () {
      final m = BranchModel.fromMap({'name': 'X'}, id: 'b1');
      expect(m.logoUrl, isNull);
      expect(m.coverUrl, isNull);
    });
  });

  group('BranchAvatar', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows initials from the name when there is no logo',
        (tester) async {
      await tester.pumpWidget(host(const BranchAvatar(name: 'DROP Arkan')));
      expect(find.text('DA'), findsOneWidget);
    });

    testWidgets('renders an Image when a logo url is set', (tester) async {
      await tester.pumpWidget(
        host(const BranchAvatar(logoUrl: 'https://x/y.jpg', name: 'DROP Arkan')),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('falls back to a store glyph when the name is empty',
        (tester) async {
      await tester.pumpWidget(host(const BranchAvatar(name: '')));
      expect(find.byIcon(Icons.store_mall_directory_outlined), findsOneWidget);
    });
  });
}
