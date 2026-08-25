import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_viewer.dart';
import 'package:opshub/features/task/presentation/widgets/video_thumbnail_image.dart';

/// A premium thumbnail gallery of task media — images show a poster, videos a
/// real cached frame with a play overlay (and duration in grid mode). Tapping a
/// tile opens the fullscreen viewer (swipeable, zoomable images, inline video).
/// The single media-rendering surface, reused by the timeline summary's
/// "Submitted work", the review sheet, and the Submission Details sheet.
///
/// Two layouts:
/// - **compact** (default): a wrap of small square tiles ([tileSize]).
/// - **grid**: pass [columns] (e.g. 2) for the deep-review layout — larger
///   rectangular cells with video duration pills.
class AttachmentGallery extends StatelessWidget {
  const AttachmentGallery({
    super.key,
    required this.attachments,
    this.tileSize = 76,
    this.showCaption = true,
    this.columns,
    this.showDuration = false,
  });

  final List<TaskAttachment> attachments;
  final double tileSize;
  final bool showCaption;

  /// When set, render a fixed-column grid instead of the compact wrap.
  final int? columns;

  /// Show a duration pill on video tiles (grid/review layout).
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        columns == null ? _wrap(context) : _grid(context, columns!),
        if (showCaption) ...[
          const SizedBox(height: AppSpacing.sm),
          _caption(),
        ],
      ],
    );
  }

  Widget _wrap(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < attachments.length; i++)
          _Tile(
            attachment: attachments[i],
            width: tileSize,
            height: tileSize,
            showDuration: false,
            onTap: () => _open(context, i),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, int cols) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final cellH = cellW * 0.72;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < attachments.length; i++)
              _Tile(
                attachment: attachments[i],
                width: cellW,
                height: cellH,
                showDuration: showDuration,
                onTap: () => _open(context, i),
              ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, int index) => showAttachmentViewer(
        context,
        attachments: attachments,
        initialIndex: index,
      );

  Widget _caption() {
    final first = attachments.first;
    final uploader = first.uploadedByName;
    final who = (uploader != null && uploader.isNotEmpty)
        ? 'Uploaded by $uploader'
        : attachmentSummary(attachments);
    return Row(
      children: [
        Icon(
          attachments.any((a) => a.type.isVideo)
              ? Icons.perm_media_outlined
              : Icons.photo_library_outlined,
          size: 13,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$who · ${attachmentTimestamp(first.uploadedAt)}',
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.attachment,
    required this.width,
    required this.height,
    required this.showDuration,
    required this.onTap,
  });

  final TaskAttachment attachment;
  final double width;
  final double height;
  final bool showDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.type.isVideo;
    final durationLabel =
        showDuration && isVideo ? formatVideoDuration(attachment.duration) : null;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo)
                VideoThumbnailImage(source: attachment.url)
              else
                _imageThumb(),
              if (isVideo)
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(130),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              if (durationLabel != null)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(durationLabel,
                        style: AppTypography.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageThumb() {
    return Image.network(
      attachment.url,
      fit: BoxFit.cover,
      cacheWidth: 480,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: AppColors.darkBg,
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (_, _, _) => Container(
        color: AppColors.darkBg,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            size: 18, color: AppColors.textTertiary),
      ),
    );
  }
}
