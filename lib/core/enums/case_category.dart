import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';

/// The kind of issue a case raises, stored as a string in `cases/{id}.category`.
/// Kept deliberately short so opening a case is fast — cases are conversations,
/// not a taxonomy. Drives the create-flow picker, the list filter, and the
/// smart-routing defaults ([defaultRecipient] + [defaultPrivacy]) that pre-fill
/// the form — always overridable by the filer.
enum CaseCategory {
  sales,
  inventory,
  staff,
  security,
  operations,
  personal;

  String get value => name;

  String get label => switch (this) {
        CaseCategory.sales => 'Sales',
        CaseCategory.inventory => 'Inventory',
        CaseCategory.staff => 'Staff',
        CaseCategory.security => 'Security',
        CaseCategory.operations => 'Operations',
        CaseCategory.personal => 'Personal',
      };

  /// One-line hint shown under the category in the picker.
  String get hint => switch (this) {
        CaseCategory.sales => 'Cash, refunds, discounts, mismatches',
        CaseCategory.inventory => 'Stock, missing or damaged items',
        CaseCategory.staff => 'Behavior, conflicts, complaints',
        CaseCategory.security => 'Theft, suspicious activity, safety',
        CaseCategory.operations => 'Store, equipment, day-to-day issues',
        CaseCategory.personal => 'A private matter — pay, leave, wellbeing',
      };

  /// Smart-routing default — the recipient the create flow pre-selects (the
  /// filer can override). Security and Personal go straight to ownership
  /// (sensitive / private); everything else is a branch matter the manager
  /// handles first.
  CaseRecipient get defaultRecipient =>
      (this == CaseCategory.security || this == CaseCategory.personal)
          ? CaseRecipient.admin
          : CaseRecipient.manager;

  /// Smart-privacy default — a Personal case is confidential by default (only an
  /// admin can see who filed it); everything else defaults to normal. Always
  /// overridable in the create flow.
  CasePrivacy get defaultPrivacy => this == CaseCategory.personal
      ? CasePrivacy.confidential
      : CasePrivacy.normal;

  /// Parses the stored string; unknown/missing → [operations] (the broad
  /// catch-all bucket).
  static CaseCategory fromString(String? raw) {
    for (final c in CaseCategory.values) {
      if (c.name == raw) return c;
    }
    return CaseCategory.operations;
  }
}
