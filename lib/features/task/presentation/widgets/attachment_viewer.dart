import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';

/// Opens the fullscreen media viewer at [initialIndex] — swipe between an event's
/// attachments. Images support pinch/double-tap zoom (built-in [InteractiveViewer]);
/// videos play inline with a real player. Each page shows the uploader + time.
Future<void> showAttachmentViewer(
  BuildContext context, {
  required List<TaskAttachment> attachments,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) =>
          _AttachmentViewer(attachments: attachments, initialIndex: initialIndex),
    ),
  );
}

class _AttachmentViewer extends StatefulWidget {
  const _AttachmentViewer({required this.attachments, required this.initialIndex});
  final List<TaskAttachment> attachments;
  final int initialIndex;

  @override
  State<_AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<_AttachmentViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.attachments;
    final current = items[_index.clamp(0, items.length - 1)];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final a = items[i];
                return a.type.isVideo
                    ? _VideoPage(url: a.url)
                    : _ImagePage(url: a.url);
              },
            ),
            // Top bar — counter + close.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (items.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('${_index + 1} / ${items.length}',
                            style: AppTypography.caption
                                .copyWith(color: Colors.white)),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            // Bottom caption — uploader + time.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Caption(attachment: current),
            ),
          ],
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.attachment});
  final TaskAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final name = attachment.uploadedByName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withAlpha(180), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (name != null && name.isNotEmpty)
            Text('Uploaded by $name',
                style:
                    AppTypography.label.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(attachmentTimestamp(attachment.uploadedAt),
              style: AppTypography.caption.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    // Cap decode resolution so an oversized (legacy / reference) image can't blow
    // memory, while keeping ~2x headroom so pinch-zoom stays crisp. cacheWidth
    // only ever downscales, so a normal (≤1600px) upload is unaffected.
    final mq = MediaQuery.of(context);
    final decodeWidth = (mq.size.width * mq.devicePixelRatio * 2).round();
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          cacheWidth: decodeWidth,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }
}

/// A single video page with a real player: tap to play/pause, scrubbable
/// progress bar, and a poster play button while paused.
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.url});
  final String url;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
    // Rebuild ONLY when play/pause flips. The scrubber (VideoProgressIndicator)
    // listens to the controller itself, so rebuilding the whole page on every
    // playback tick (~60fps) was pure waste — this drops it to one rebuild per
    // play/pause.
    _controller.addListener(_onPlayingChanged);
  }

  void _onPlayingChanged() {
    final playing = _controller.value.isPlaying;
    if (playing != _playing && mounted) {
      setState(() => _playing = playing);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayingChanged);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    // play()/pause() notify synchronously → _onPlayingChanged updates the overlay.
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48),
      );
    }
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    final playing = _playing;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!playing)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 40),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 64,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
