import 'package:opshub/features/task/domain/work_types/definitions/general_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inspection_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/purchase_errand_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';

/// Resolves a [WorkTypeDefinition] by its persisted [WorkTypeDefinition.id]
/// (Registry / Factory). This is the single indirection every screen goes
/// through to get a task's behaviour, which is why:
///
///  * **adding a work type is one line here** (plus its definition file) — no
///    other file in the app changes, and there is no `switch` to keep in sync;
///  * an unknown / missing / rolled-back id degrades to [general] instead of
///    crashing, so a new type can ship (or be reverted) with no data migration.
///
/// Instantiable so tests can inject a bespoke set; a default [instance] holds the
/// built-in definitions for the app.
class WorkTypeRegistry {
  final List<WorkTypeDefinition> _defs;
  final Map<String, WorkTypeDefinition> _byId;

  WorkTypeRegistry(List<WorkTypeDefinition> definitions)
      : _defs = List.unmodifiable(definitions),
        _byId = {for (final d in definitions) d.id: d} {
    assert(
      _byId.length == definitions.length,
      'WorkTypeRegistry has duplicate work-type ids.',
    );
    assert(
      _byId.containsKey(general.id),
      'WorkTypeRegistry requires the "${general.id}" fallback definition.',
    );
  }

  /// The mandatory fallback definition (also the default for a brand-new task).
  static const GeneralWorkType general = GeneralWorkType();

  /// The app's built-in registry. **This list is the one place adding a new
  /// operational work type touches** — append the definition and it is
  /// immediately available to the picker, the create form, the detail screen and
  /// analytics.
  static final WorkTypeRegistry instance = WorkTypeRegistry(const [
    general,
    TransferWorkType(),
    PurchaseErrandWorkType(),
    InventoryCountWorkType(),
    InspectionWorkType(),
  ]);

  /// Every registered definition, in declaration order (drives the type picker).
  List<WorkTypeDefinition> get all => _defs;

  /// Resolve by persisted id; unknown / legacy / null → [general].
  WorkTypeDefinition byId(String? id) => _byId[id] ?? general;

  bool isKnown(String? id) => id != null && _byId.containsKey(id);
}
