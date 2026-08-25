import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';

/// A media file the user has picked (and possibly edited / compressed) but not
/// yet uploaded — the input to every upload flow (task submission, case reply,
/// request comment). Lives in `core` because it is a plain cross-feature DTO;
/// features must not reach into another feature's cubit to obtain it.
///
/// [durationMs] is the captured video length (best-effort; null for images).
/// [originalBytes] is the pre-compression size (videos only, when compression
/// ran) — used to report a compression ratio in upload analytics; null when
/// unknown.
class PickedAttachment {
  const PickedAttachment(
    this.file,
    this.type, {
    this.durationMs,
    this.originalBytes,
  });
  final File file;
  final AttachmentType type;
  final int? durationMs;
  final int? originalBytes;
}
