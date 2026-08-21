import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/cases/domain/case_participation.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';

void main() {
  group('CaseCategory (6 categories) smart routing', () {
    test('has six categories incl. Personal', () {
      expect(CaseCategory.values.length, 6);
      expect(CaseCategory.values.contains(CaseCategory.personal), isTrue);
    });

    test('security & personal default to the admin; the rest to the manager', () {
      expect(CaseCategory.security.defaultRecipient, CaseRecipient.admin);
      expect(CaseCategory.personal.defaultRecipient, CaseRecipient.admin);
      expect(CaseCategory.sales.defaultRecipient, CaseRecipient.manager);
      expect(CaseCategory.inventory.defaultRecipient, CaseRecipient.manager);
      expect(CaseCategory.staff.defaultRecipient, CaseRecipient.manager);
      expect(CaseCategory.operations.defaultRecipient, CaseRecipient.manager);
    });

    test('personal defaults to confidential; the rest to normal', () {
      expect(CaseCategory.personal.defaultPrivacy, CasePrivacy.confidential);
      for (final cat in CaseCategory.values.where((c) => c != CaseCategory.personal)) {
        expect(cat.defaultPrivacy, CasePrivacy.normal, reason: cat.name);
      }
    });
  });

  group('CaseRecipient manager visibility', () {
    test('an admin-routed case is hidden from the manager', () {
      expect(CaseRecipient.admin.includesManager, isFalse);
      expect(CaseRecipient.manager.includesManager, isTrue);
      expect(CaseRecipient.both.includesManager, isTrue);
    });

    test('includesAdmin covers admin + both, never manager-only', () {
      expect(CaseRecipient.admin.includesAdmin, isTrue);
      expect(CaseRecipient.both.includesAdmin, isTrue);
      expect(CaseRecipient.manager.includesAdmin, isFalse);
    });
  });

  group('CaseEntity.visibleToManager derives from recipient', () {
    CaseEntity withRecipient(CaseRecipient r) =>
        CaseEntity(id: 'c', subject: 's', recipient: r);
    test('mirrors includesManager', () {
      expect(withRecipient(CaseRecipient.manager).visibleToManager, isTrue);
      expect(withRecipient(CaseRecipient.both).visibleToManager, isTrue);
      expect(withRecipient(CaseRecipient.admin).visibleToManager, isFalse);
    });
  });

  group('viewer participation', () {
    final branchCase =
        CaseEntity(id: 'c', subject: 's', recipient: CaseRecipient.manager);
    final adminRoutedCase =
        CaseEntity(id: 'c', subject: 's', recipient: CaseRecipient.admin);

    test('an employee is always the reporter', () {
      expect(viewerIsReporter(UserRole.employee, branchCase), isTrue);
      expect(viewerCanControlStatus(UserRole.employee, branchCase), isFalse);
    });

    test('an admin is always a recipient (controls status)', () {
      expect(viewerIsReporter(UserRole.admin, branchCase), isFalse);
      expect(viewerCanControlStatus(UserRole.admin, branchCase), isTrue);
    });

    test('a manager is the recipient of a branch case', () {
      expect(viewerIsReporter(UserRole.manager, branchCase), isFalse);
      expect(viewerCanControlStatus(UserRole.manager, branchCase), isTrue);
    });

    test('a manager is the reporter of an admin-routed case they filed', () {
      expect(viewerIsReporter(UserRole.manager, adminRoutedCase), isTrue);
      expect(viewerCanControlStatus(UserRole.manager, adminRoutedCase), isFalse);
    });
  });
}
