import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';
import 'package:opshub/features/communications/domain/repositories/broadcast_repository.dart';

/// Sends a broadcast (manager / admin) and returns it with its generated id.
///
/// [targetUserIds] carries the recipient list for a `custom` (multi-recipient)
/// send; [roleFilter] (''/`all` = none) restricts a branch/all send to a single
/// role. Both are send-time intents resolved by the Cloud Function — they are not
/// stored on the [BroadcastEntity].
class SendBroadcast {
  final BroadcastRepository _repository;
  const SendBroadcast(this._repository);

  Future<BroadcastEntity> call(
    BroadcastEntity broadcast, {
    List<String> targetUserIds = const [],
    String roleFilter = '',
  }) =>
      _repository.sendBroadcast(
        broadcast,
        targetUserIds: targetUserIds,
        roleFilter: roleFilter,
      );
}
