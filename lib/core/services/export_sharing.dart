/// The single seam for delivering an exported artifact — the attendance PDF/CSV,
/// the schedule PNG/PDF/XLSX — to the user: write it somewhere findable, then hand
/// it to the OS **share sheet**. Both the attendance report and the schedule Final
/// View export through here, so an export lands and is sent the same way across
/// the app.
///
/// **Why `share_plus` and not `open_filex`.** Owner-approved exception to OpsHub's
/// dependency-light stance (2026-08-07). `open_filex` could only open a local
/// viewer, so *sending* an export took an extra hop through Quick Look;
/// `share_plus` raises the real share sheet (WhatsApp · Mail · AirDrop · Files) on
/// iOS/Android/macOS — OpsHub's three targets. This file is the only place
/// `share_plus` is imported.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Write [write] to [filename] in a user-findable directory and return the file:
/// the **Downloads** folder on desktop, the app **documents** sandbox on mobile
/// (from which [shareExportedFile] raises the share sheet — the sandbox is not
/// otherwise reachable, which is exactly why the share sheet matters there).
///
/// Mobile never uses `getDownloadsDirectory()`: on iOS it can hand back an
/// uncreated `.../Downloads` sandbox path rather than null, so the `?? documents`
/// fallback never fires and the write throws "cannot open file" — the old "Could
/// not save" bug. Phones go straight to the always-present documents directory;
/// `create(recursive: true)` is a belt-and-braces guard for the desktop path.
Future<File> writeExportFile(
  String filename,
  Future<void> Function(File) write,
) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;
  final directory = isMobile
      ? await getApplicationDocumentsDirectory()
      : (await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory());
  await directory.create(recursive: true);
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await write(file);
  return file;
}

/// Hand [file] to the OS share sheet, anchored — for the iPad / macOS popover — to
/// [context]'s render box (share_plus throws on iPad without an origin). Pass a
/// [subject] for the mail/message subject line.
///
/// Best-effort by contract: the file is already written to a findable location, so
/// a dismissed or failed share is never surfaced as an export failure. The caller
/// shows its own "Saved / Shared" confirmation around this.
Future<void> shareExportedFile(
  BuildContext context,
  File file, {
  String? subject,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = (box != null && box.hasSize)
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: subject,
      sharePositionOrigin: origin,
    ),
  );
}
