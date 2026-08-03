import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// `image_picker`'s camera capture (`ImageSource.camera`) is only implemented
/// on Android/iOS — desktop (macOS/Windows/Linux) and web throw at pick time
/// (macOS/Windows throw `StateError`, web has no camera source at all). Gate
/// any "Take a photo" / "Record a video" affordance on this so it never offers
/// a control that's guaranteed to fail.
bool get supportsCameraCapture =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Whether the in-app image editor (crop / rotate / flip / aspect) can run.
/// Backed by `image_cropper`, which has no desktop (macOS/Windows/Linux)
/// implementation — calling it there throws `MissingPluginException`. Gate every
/// editor affordance on this so desktop simply uploads the picked image
/// unedited. Kept mobile-only (web isn't a target and needs extra JS setup).
bool get supportsImageEditing =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Whether client-side video transcoding can run before upload. Backed by
/// `video_compress`, which is Android/iOS only — desktop/web fall back to
/// uploading the original video untouched.
bool get supportsVideoCompression =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Whether this build can actually complete FCM push registration. Push is
/// mobile-only today: the macOS Runner has **no `aps-environment` (Push
/// Notifications) entitlement**, so the APNS token never arrives and every
/// `getToken()` call logs "APNS token has not been set yet…" and fails. Gate
/// `NotificationService` on this so desktop never requests notification
/// permission or attempts registration it can't finish. If macOS push is ever
/// configured (entitlement + APNs key), add `Platform.isMacOS` here.
bool get supportsPushNotifications =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Apple platforms hand FCM the APNS token asynchronously after launch —
/// `getToken()` before it arrives is the "APNS token not available" failure.
/// Callers on these platforms must check `getAPNSToken()` first.
bool get requiresApnsToken => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

/// Whether chat's in-app socket banner must stand down for the OS banner.
///
/// Chat is the only route delivered by **two** independent paths — the chat
/// socket and an FCM push from the chat backend — so both can fire for one
/// message while the app is open. Apple platforms draw a foreground banner for
/// every push (`setForegroundNotificationPresentationOptions`), so there the OS
/// banner is the notification and the in-app one would be a duplicate. Android
/// draws nothing in the foreground, so it keeps the in-app banner.
bool get suppressesInAppChatBanner => requiresApnsToken;
