import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/platform_capabilities.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';
import 'package:drop/core/media/media_processing.dart';
import 'package:drop/core/media/picked_attachment.dart';
import 'package:drop/features/task/presentation/widgets/video_thumbnail_image.dart';

/// Media picker (Phase 10) — attach multiple images (and, when [allowVideo],
/// videos) from gallery or camera. Two roles share this one widget:
/// - **employee submission** (default): photos + videos as task *proof*.
/// - **manager/admin reference images** ([allowVideo] = false + [existing] +
///   [onRemoveExisting]): images-only "what good looks like" attached on
///   create/edit; already-uploaded [existing] refs render as removable tiles
///   alongside the newly-picked ones.
///
/// Shows the selection as removable thumbnails and enforces the count / size
/// limits in [AttachmentLimits]. Parent owns the [attachments] list (new picks)
/// and calls [onChanged] with the new selection.
class AttachmentPickerField extends StatelessWidget {
  const AttachmentPickerField({
    super.key,
    required this.attachments,
    required this.onChanged,
    this.allowVideo = true,
    this.title = 'Attachments',
    this.hint,
    this.existing = const [],
    this.onRemoveExisting,
  });

  final List<PickedAttachment> attachments;
  final ValueChanged<List<PickedAttachment>> onChanged;

  /// When false, the picker is **images only** (no video menu rows / counter) —
  /// used for manager reference images.
  final bool allowVideo;

  /// Section title (e.g. 'Attachments' vs 'Reference images').
  final String title;

  /// Optional hint override; null uses the default proof-media hint.
  final String? hint;

  /// Already-uploaded attachments to show as removable tiles (edit mode for
  /// reference images). Removing one calls [onRemoveExisting].
  final List<TaskAttachment> existing;
  final ValueChanged<TaskAttachment>? onRemoveExisting;

  /// Images already used = previously uploaded + newly picked, so the cap spans
  /// both groups.
  int get _existingImages => existing.where((a) => a.type.isImage).length;
  int get _images =>
      _existingImages + attachments.where((a) => a.type.isImage).length;
  int get _videos => attachments.where((a) => a.type.isVideo).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(allowVideo ? Icons.attachment_rounded : Icons.image_outlined,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              // Flexible so the row can never overflow on narrow widths or
              // large accessibility text — the title truncates, the counts stay.
              Expanded(
                child: Text(title,
                    style: AppTypography.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                allowVideo
                    ? 'Photos $_images/${AttachmentLimits.maxImages} · '
                        'Videos $_videos/${AttachmentLimits.maxVideos}'
                    : 'Photos $_images/${AttachmentLimits.maxImages}',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in existing)
                _ExistingTile(
                  attachment: a,
                  onRemove: onRemoveExisting == null
                      ? null
                      : () => onRemoveExisting!(a),
                ),
              for (var i = 0; i < attachments.length; i++)
                _SelectedTile(
                  attachment: attachments[i],
                  onRemove: () => _removeAt(i),
                  onEdit: (attachments[i].type.isImage && supportsImageEditing)
                      ? () => _editAt(context, i)
                      : null,
                ),
              _AddTile(onTap: () => _openMenu(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint ??
                'Add photos (≤${AttachmentLimits.maxImageMb} MB) or videos '
                    '(≤${AttachmentLimits.maxVideoMb} MB) as proof. Photos are '
                    'compressed before upload.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  void _removeAt(int i) {
    final next = [...attachments]..removeAt(i);
    onChanged(next);
  }

  // ── Add menu ─────────────────────────────────────────────────────
  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MenuRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose photos',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickPhotos(context);
              },
            ),
            if (allowVideo)
              _MenuRow(
                icon: Icons.video_library_outlined,
                label: 'Choose a video',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickVideo(context, ImageSource.gallery);
                },
              ),
            if (supportsCameraCapture)
              _MenuRow(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _takePhoto(context);
                },
              ),
            if (allowVideo && supportsCameraCapture)
              _MenuRow(
                icon: Icons.videocam_outlined,
                label: 'Record a video',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickVideo(context, ImageSource.camera);
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────
  // Photos are resized + recompressed by image_picker before upload (the
  // pre-upload optimization), per AttachmentLimits. On mobile the user can then
  // crop/rotate each one — automatically after a camera capture, or by tapping a
  // thumbnail.
  Future<void> _pickPhotos(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: AttachmentLimits.imageQuality,
        maxWidth: AttachmentLimits.imageMaxWidth,
      );
      if (picked.isEmpty) return;
      final reason = await _commit([
        for (final x in picked) (File(x.path), AttachmentType.image, null, null)
      ]);
      if (reason != null && context.mounted) {
        AppSnackbar.error(context, reason);
      }
    } catch (e, st) {
      AppLog.error('attachments', 'gallery pick failed', e, st);
      if (context.mounted) {
        AppSnackbar.error(
            context, _pickErrorMessage(e, 'Could not add photos.'));
      }
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: AttachmentLimits.imageQuality,
        maxWidth: AttachmentLimits.imageMaxWidth,
      );
      if (x == null) return; // user backed out of the camera
      // Offer the editor immediately after capture — the natural moment to
      // straighten/crop proof before it's added. A cancel keeps the original.
      var file = File(x.path);
      if (supportsImageEditing) {
        final edited = await MediaProcessing.editImage(file);
        if (edited != null) file = edited;
      }
      // The commit runs whether or not this widget survived the camera round
      // trip — see `_commit`. Only the message needs a live context.
      final reason = await _commit([(file, AttachmentType.image, null, null)]);
      if (reason != null && context.mounted) {
        AppSnackbar.error(context, reason);
      }
    } catch (e, st) {
      // Never swallow this one: a camera failure is a permission problem, an
      // unavailable camera (simulator), or a plugin fault, and each wants a
      // different fix. Log the real cause and say which it was.
      AppLog.error('attachments', 'camera capture failed', e, st);
      if (context.mounted) {
        AppSnackbar.error(context,
            _pickErrorMessage(e, 'Could not take a photo. Please try again.'));
      }
    }
  }

  /// Turns a pick failure into something the user can act on. `image_picker`
  /// reports the actionable ones as `PlatformException` codes; anything else
  /// falls back to [fallback] (and the real cause is in the log).
  String _pickErrorMessage(Object error, String fallback) {
    final code = error is PlatformException ? error.code : '';
    switch (code) {
      case 'camera_access_denied':
        return 'Camera access is off. Enable it for DROP in Settings.';
      case 'photo_access_denied':
        return 'Photo access is off. Enable it for DROP in Settings.';
      case 'no_available_camera':
        return 'No camera on this device — choose a photo instead.';
      default:
        return fallback;
    }
  }

  Future<void> _pickVideo(BuildContext context, ImageSource source) async {
    try {
      final x = await ImagePicker().pickVideo(
          source: source, maxDuration: AttachmentLimits.maxVideoDuration);
      if (x == null) return;
      final durationMs = await _videoDurationMs(x.path); // no context use
      var file = File(x.path);
      int? originalBytes;
      // Transcode to a much smaller file before upload (mobile only). A failure
      // falls back to the original; an explicit user cancel aborts adding it.
      if (supportsVideoCompression) {
        originalBytes = await file.length(); // pre-compression size (for ratio)
        if (!context.mounted) return;
        final out = await _compressVideoWithProgress(context, file);
        if (out == null) return; // user cancelled compression
        file = out;
      }
      final reason = await _commit(
          [(file, AttachmentType.video, durationMs, originalBytes)]);
      if (reason != null && context.mounted) {
        AppSnackbar.error(context, reason);
      }
    } catch (e, st) {
      AppLog.error('attachments', 'video pick failed', e, st);
      if (context.mounted) {
        AppSnackbar.error(
            context, _pickErrorMessage(e, 'Could not add the video.'));
      }
    }
  }

  /// Best-effort video length (ms) read locally via a throwaway controller. Null
  /// on any failure — duration is a nice-to-have, never blocks the attachment.
  Future<int?> _videoDurationMs(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final ms = controller.value.duration.inMilliseconds;
      return ms > 0 ? ms : null;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Re-opens the editor for an already-picked image at [i] and replaces it with
  /// the edited version (a cancel/failure leaves it unchanged). Images only.
  Future<void> _editAt(BuildContext context, int i) async {
    if (i < 0 || i >= attachments.length) return;
    final a = attachments[i];
    if (!a.type.isImage) return;
    final edited = await MediaProcessing.editImage(a.file);
    if (edited == null) return;
    final next = [...attachments];
    next[i] = PickedAttachment(edited, a.type, durationMs: a.durationMs);
    onChanged(next);
  }

  /// Runs [file] through video compression behind a cancellable progress dialog.
  /// Returns the compressed file, the original on a (silent) compression
  /// failure, or null if the user cancelled (→ don't add the video).
  Future<File?> _compressVideoWithProgress(BuildContext context, File file) =>
      showDialog<File?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VideoCompressDialog(source: file),
      );

  /// Validates each picked file against the count + size limits, appends the
  /// accepted ones via [onChanged], and returns the first rejection reason (or
  /// null when everything was accepted).
  ///
  /// **Deliberately free of [BuildContext].** The parent owns the list, so the
  /// commit must not be conditional on this widget still being mounted — the
  /// native camera and (on Android) the cropper run in their own activity, and
  /// coming back can rebuild the tree underneath. Gating the commit on
  /// `context.mounted` silently threw away a photo the user had already taken,
  /// which is indistinguishable from the camera doing nothing. Showing the
  /// reason is the caller's job, where a `mounted` check belongs.
  Future<String?> _commit(
      List<(File, AttachmentType, int?, int?)> incoming) async {
    final next = [...attachments];
    String? reason;
    for (final (file, type, durationMs, originalBytes) in incoming) {
      final r = await _rejectReason(next, file, type);
      if (r != null) {
        reason ??= r;
        continue;
      }
      next.add(PickedAttachment(file, type,
          durationMs: durationMs, originalBytes: originalBytes));
    }
    onChanged(next);
    if (reason != null) {
      AppLog.warning('attachments', 'pick rejected', meta: {'reason': reason});
    }
    return reason;
  }

  /// Why a picked file can't be added (count / per-type size), or null if it's
  /// fine. Pure of [BuildContext] so it never crosses an async gap with the UI.
  /// Size is checked on the final (edited / compressed) file.
  Future<String?> _rejectReason(
      List<PickedAttachment> current, File file, AttachmentType type) async {
    // Count already-uploaded refs too so the cap spans both groups.
    final images =
        _existingImages + current.where((a) => a.type.isImage).length;
    final videos = current.where((a) => a.type.isVideo).length;
    if (type.isImage && images >= AttachmentLimits.maxImages) {
      return 'Up to ${AttachmentLimits.maxImages} photos.';
    }
    if (type.isVideo && videos >= AttachmentLimits.maxVideos) {
      return 'Up to ${AttachmentLimits.maxVideos} videos.';
    }
    // A file that can't be stat'd is gone (a temp the OS reclaimed, or a bad
    // path back from the cropper). Report it as a rejection rather than letting
    // it throw — one unreadable pick must not take the whole batch down, and a
    // silent loss here is what makes a capture look like it "did nothing".
    final int size;
    try {
      size = await file.length();
    } catch (e) {
      AppLog.error('attachments', 'picked file unreadable: ${file.path}', e);
      return 'That file could not be read. Please try again.';
    }
    if (size > AttachmentLimits.maxBytesFor(type)) {
      final what = type.isVideo ? 'video' : 'photo';
      return 'Each $what must be under ${AttachmentLimits.maxMbFor(type)} MB.';
    }
    return null;
  }
}

class _SelectedTile extends StatelessWidget {
  const _SelectedTile({
    required this.attachment,
    required this.onRemove,
    this.onEdit,
  });
  final PickedAttachment attachment;
  final VoidCallback onRemove;

  /// Tapping the tile opens the editor. Non-null only for editable (image) tiles
  /// on a platform that supports editing; a small pencil badge advertises it.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onEdit, // no-op for videos / when editing is unsupported
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: SizedBox(
                width: size,
                height: size,
                // cacheWidth caps decode memory — a 1600px pick rendered at 72px
                // must not decode at full resolution.
                child: attachment.type.isImage
                    ? Image.file(attachment.file,
                        fit: BoxFit.cover, cacheWidth: 216)
                    : VideoThumbnailImage(source: attachment.file.path),
              ),
            ),
          ),
          if (attachment.type.isVideo)
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white70, size: 26),
              ),
            ),
          if (onEdit != null)
            const Positioned(
              left: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child:
                      Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An already-uploaded attachment (network URL) shown in the picker — used for
/// reference images in edit mode, with an optional remove affordance.
class _ExistingTile extends StatelessWidget {
  const _ExistingTile({required this.attachment, this.onRemove});
  final TaskAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: SizedBox(
              width: size,
              height: size,
              child: attachment.type.isVideo
                  ? VideoThumbnailImage(source: attachment.url)
                  : Image.network(
                      attachment.url,
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.darkBg,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 18, color: AppColors.textTertiary),
                      ),
                    ),
            ),
          ),
          if (attachment.type.isVideo)
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white70, size: 26),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: AppColors.textSecondary),
            SizedBox(height: 2),
            Text('Add', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: AppTypography.label),
      onTap: onTap,
    );
  }
}

/// Cancellable progress dialog shown while a picked video is transcoded. Owns
/// the compression lifecycle and pops with the result: the compressed file, the
/// original on a compression failure (so the pick is never lost), or null when
/// the user cancels (→ the video isn't added).
class _VideoCompressDialog extends StatefulWidget {
  const _VideoCompressDialog({required this.source});
  final File source;

  @override
  State<_VideoCompressDialog> createState() => _VideoCompressDialogState();
}

class _VideoCompressDialogState extends State<_VideoCompressDialog> {
  double _progress = 0;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = await MediaProcessing.compressVideo(
      widget.source,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    // Cancel → don't add (null). Failure (null, not cancelled) → keep original.
    Navigator.of(context).pop(_cancelled ? null : (result ?? widget.source));
  }

  void _cancel() {
    setState(() => _cancelled = true);
    MediaProcessing.cancelVideoCompression();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.darkSurfaceElevated,
        title: const Text('Compressing video', style: AppTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _progress > 0 ? (_progress / 100).clamp(0.0, 1.0) : null,
                minHeight: 6,
                backgroundColor: AppColors.darkBg,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _cancelled ? 'Cancelling…' : '${_progress.round()}%',
              style: AppTypography.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelled ? null : _cancel,
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
