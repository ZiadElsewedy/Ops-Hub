import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';

/// The **general task** — exact parity with today's generic task: a title, an
/// optional description, an optional checklist, always reviewed, no extra
/// captured data, no milestones. It is the registry's mandatory fallback, so any
/// task with a missing / unknown / rolled-back `workType` resolves here and
/// behaves exactly as tasks do now (zero-migration back-compat).
///
/// It overrides nothing — every behaviour comes from [BaseWorkType]. That it can
/// be this small is the point: the general case *is* the default, and
/// specialised types pay only for what they change.
class GeneralWorkType extends BaseWorkType {
  const GeneralWorkType();

  @override
  String get id => 'general';

  @override
  String get label => 'General Task';

  @override
  String get blurb => 'A standard task with an optional checklist.';
}
