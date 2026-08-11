import 'package:flutter/widgets.dart';

/// App-wide "tap outside a field to lower the keyboard".
///
/// Wraps the router's Navigator once (in `MaterialApp.router`'s `builder`), so
/// **every** screen — plus every modal sheet and dialog pushed onto that
/// Navigator — inherits the behaviour without each form re-implementing it. The
/// old state was that only a few auth pages called `unfocus()` by hand, so on
/// the rest of the app the soft keyboard would stay up after a text field lost
/// interest (typing a task title, a chat message, a sales note, …).
///
/// Why this is safe over the whole tree:
/// * `HitTestBehavior.translucent` + a bare `onTap` claims **only** the tap
///   gesture. Scroll/drag gestures use different recognizers, so lists, sliders
///   and the schedule strips still scroll normally.
/// * In the gesture arena the **deepest** widget wins a tap, so buttons,
///   `InkWell`s, list rows and inner `GestureDetector`s keep working — this
///   ancestor only fires when the tap lands on otherwise-dead space (the
///   background, padding, a sheet's empty area), which is exactly when we want
///   to dismiss.
///
/// Uses `FocusManager.instance.primaryFocus` rather than
/// `FocusScope.of(context)` so it lowers the keyboard regardless of which focus
/// subtree currently holds it (a modal route installs its own `FocusScope`).
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        final focus = FocusManager.instance.primaryFocus;
        if (focus != null && focus.hasFocus) focus.unfocus();
      },
      child: child,
    );
  }
}
