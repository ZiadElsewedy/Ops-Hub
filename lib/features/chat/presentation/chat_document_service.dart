import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drop/core/utils/app_logger.dart';

/// The outcome of opening (or saving) a chat document.
enum ChatDocOutcome {
  /// Opened / saved successfully.
  ok,

  /// Downloaded fine, but no installed app can open this type.
  noApp,

  /// The brokered URL couldn't be resolved or fetched.
  downloadFailed,

  /// Everything else (open error, write error, …).
  failed,
}

/// Result of a document operation, with a user-facing [message] on failure.
class ChatDocResult {
  const ChatDocResult(this.outcome, [this.message]);
  final ChatDocOutcome outcome;
  final String? message;

  bool get ok => outcome == ChatDocOutcome.ok;
}

/// Downloads chat document attachments to a local cache and opens them with the
/// platform's default application (an in-app PDF viewer could be layered on
/// later behind [open] without changing callers).
///
/// **Caching / no duplicate downloads:** each attachment is cached on disk keyed
/// by its immutable `attachmentId`; a second open reuses the cached file and
/// never re-fetches. The brokered URL (short-lived) is only resolved on a cache
/// miss. Bytes live in the OS temp/cache directory — never in the Drift cache
/// (that stays metadata-only).
class ChatDocumentService {
  /// Opens [attachmentId]'s document, downloading + caching it first if needed.
  /// [urlLoader] resolves the fresh brokered URL (only called on a cache miss).
  Future<ChatDocResult> open({
    required String attachmentId,
    required String filename,
    required Future<String?> Function() urlLoader,
  }) async {
    final File file;
    try {
      file = await _cachedFile(attachmentId, filename, urlLoader);
    } on _DownloadException catch (e) {
      return ChatDocResult(ChatDocOutcome.downloadFailed, e.message);
    } catch (e) {
      AppLog.warning('chat', 'document cache failed: $e');
      return const ChatDocResult(
          ChatDocOutcome.downloadFailed, 'Could not download the file.');
    }
    return _openFile(file);
  }

  /// Saves [attachmentId]'s document to the user's Downloads directory (desktop)
  /// or the app documents directory (mobile, where there is no shared
  /// Downloads), returning the destination path on success.
  Future<({ChatDocResult result, String? path})> saveToDownloads({
    required String attachmentId,
    required String filename,
    required Future<String?> Function() urlLoader,
  }) async {
    try {
      final cached = await _cachedFile(attachmentId, filename, urlLoader);
      final dir = await _downloadsDir();
      final dest = File(p.join(dir.path, _safeName(filename)));
      await cached.copy(dest.path);
      return (result: const ChatDocResult(ChatDocOutcome.ok), path: dest.path);
    } on _DownloadException catch (e) {
      return (
        result: ChatDocResult(ChatDocOutcome.downloadFailed, e.message),
        path: null
      );
    } catch (e) {
      AppLog.warning('chat', 'document save failed: $e');
      return (
        result: const ChatDocResult(
            ChatDocOutcome.failed, 'Could not save the file.'),
        path: null
      );
    }
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  Future<File> _cachedFile(
    String attachmentId,
    String filename,
    Future<String?> Function() urlLoader,
  ) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'chat_docs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${attachmentId}_${_safeName(filename)}'));

    // Dedup: a non-empty cached copy is reused verbatim — no second download.
    if (await file.exists() && await file.length() > 0) return file;

    final url = await urlLoader();
    if (url == null || url.isEmpty) {
      throw const _DownloadException('The file is no longer available.');
    }
    await _download(url, file);
    return file;
  }

  Future<void> _download(String url, File dest) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw _DownloadException(
            'Download failed (HTTP ${response.statusCode}).');
      }
      final sink = dest.openWrite();
      await response.pipe(sink);
      // `pipe` closes the sink on success.
    } finally {
      client.close();
    }
  }

  Future<ChatDocResult> _openFile(File file) async {
    try {
      // open_filex covers mobile; desktop uses the OS opener directly.
      if (Platform.isAndroid || Platform.isIOS) {
        final result = await OpenFilex.open(file.path);
        return switch (result.type) {
          ResultType.done => const ChatDocResult(ChatDocOutcome.ok),
          ResultType.noAppToOpen => const ChatDocResult(
              ChatDocOutcome.noApp, 'No app can open this file type.'),
          _ => ChatDocResult(ChatDocOutcome.failed,
              result.message.isEmpty ? 'Could not open the file.' : result.message),
        };
      }
      return _openDesktop(file);
    } catch (e) {
      AppLog.warning('chat', 'document open failed: $e');
      return const ChatDocResult(
          ChatDocOutcome.failed, 'Could not open the file.');
    }
  }

  Future<ChatDocResult> _openDesktop(File file) async {
    final (cmd, args) = Platform.isMacOS
        ? ('open', [file.path])
        : Platform.isWindows
            ? ('cmd', ['/c', 'start', '', file.path])
            : ('xdg-open', [file.path]);
    final result = await Process.run(cmd, args);
    return result.exitCode == 0
        ? const ChatDocResult(ChatDocOutcome.ok)
        : const ChatDocResult(ChatDocOutcome.failed, 'Could not open the file.');
  }

  Future<Directory> _downloadsDir() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Strips path separators from a filename so it can't escape the cache dir.
  static String _safeName(String filename) =>
      filename.replaceAll(RegExp(r'[\\/]+'), '_');
}

class _DownloadException implements Exception {
  const _DownloadException(this.message);
  final String message;
}
