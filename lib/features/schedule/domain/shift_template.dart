import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';

/// A named, reusable shift-hours definition for a branch (Schedule V2 · Pillar
/// 5) — e.g. *Morning 08:30 → 16:30*, *Weekday night 15:00 → 23:00*, *Weekend
/// night 16:00 → 00:00*. Lives in `shift_templates/{id}` (branch-scoped) and is
/// the **editable** source the week's [ShiftPlan] snapshot is built from.
///
/// [hours] reuses the overnight-aware [ShiftHours] value object, so a template
/// crossing midnight (`end > 1440`) needs no new time logic.
class ShiftTemplate {
  const ShiftTemplate({
    required this.id,
    required this.branchId,
    required this.name,
    required this.role,
    required this.hours,
  });

  final String id;
  final String branchId;
  final String name;
  final ShiftTemplateRole role;
  final ShiftHours hours;

  ShiftTemplate copyWith({
    String? id,
    String? branchId,
    String? name,
    ShiftTemplateRole? role,
    ShiftHours? hours,
  }) =>
      ShiftTemplate(
        id: id ?? this.id,
        branchId: branchId ?? this.branchId,
        name: name ?? this.name,
        role: role ?? this.role,
        hours: hours ?? this.hours,
      );

  @override
  bool operator ==(Object other) =>
      other is ShiftTemplate &&
      other.id == id &&
      other.branchId == branchId &&
      other.name == name &&
      other.role == role &&
      other.hours == hours;

  @override
  int get hashCode => Object.hash(id, branchId, name, role, hours);
}

/// Why a template edit was rejected — surfaced to the manager, never thrown.
enum ShiftTemplateError { emptyName, duplicateName, invalidRange }

extension ShiftTemplateErrorX on ShiftTemplateError {
  String get message => switch (this) {
        ShiftTemplateError.emptyName => 'Give the template a name.',
        ShiftTemplateError.duplicateName =>
          'Another template already uses that name.',
        ShiftTemplateError.invalidRange =>
          'The end time must be after the start (overnight is allowed).',
      };
}

/// A branch's whole template library (Schedule V2 · Pillar 5). Pure derivation
/// over the loaded [templates] — resolves the standing [ShiftPlan], seeds the
/// defaults, and runs the validation the UI needs.
class ShiftTemplateSet {
  const ShiftTemplateSet(this.templates);

  final List<ShiftTemplate> templates;

  bool get isEmpty => templates.isEmpty;

  /// The template filling a standing [role], or null when the branch hasn't
  /// defined one.
  ShiftTemplate? forRole(ShiftTemplateRole role) {
    for (final t in templates) {
      if (t.role == role) return t;
    }
    return null;
  }

  /// The resolved plan a new week snapshots — each standing role's hours, or the
  /// [ShiftPlan.standard] value when the branch hasn't defined that role.
  ShiftPlan get plan {
    final std = ShiftPlan.standard();
    return ShiftPlan(
      morning: forRole(ShiftTemplateRole.morning)?.hours ?? std.morning,
      weekdayNight: forRole(ShiftTemplateRole.weekdayNight)?.hours ??
          std.weekdayNight,
      weekendNight: forRole(ShiftTemplateRole.weekendNight)?.hours ??
          std.weekendNight,
    );
  }

  /// True when [name] collides (case-insensitively) with another template.
  bool hasDuplicateName(String name, {String? excludingId}) {
    final needle = name.trim().toLowerCase();
    for (final t in templates) {
      if (t.id == excludingId) continue;
      if (t.name.trim().toLowerCase() == needle) return true;
    }
    return false;
  }

  /// Validates a rename/create; null = OK.
  ShiftTemplateError? validate(String name, {String? excludingId}) {
    if (name.trim().isEmpty) return ShiftTemplateError.emptyName;
    if (hasDuplicateName(name, excludingId: excludingId)) {
      return ShiftTemplateError.duplicateName;
    }
    return null;
  }

  /// The three standing templates a branch is seeded with — matching the
  /// historical `ShiftHours.standard`, so seeding changes nothing until a
  /// manager edits one. [idFor] mints a stable id per role.
  static List<ShiftTemplate> defaultsFor(
    String branchId, {
    required String Function(ShiftTemplateRole role) idFor,
  }) {
    final std = ShiftPlan.standard();
    return [
      ShiftTemplate(
        id: idFor(ShiftTemplateRole.morning),
        branchId: branchId,
        name: 'Morning',
        role: ShiftTemplateRole.morning,
        hours: std.morning,
      ),
      ShiftTemplate(
        id: idFor(ShiftTemplateRole.weekdayNight),
        branchId: branchId,
        name: 'Weekday night',
        role: ShiftTemplateRole.weekdayNight,
        hours: std.weekdayNight,
      ),
      ShiftTemplate(
        id: idFor(ShiftTemplateRole.weekendNight),
        branchId: branchId,
        name: 'Weekend night',
        role: ShiftTemplateRole.weekendNight,
        hours: std.weekendNight,
      ),
    ];
  }
}
