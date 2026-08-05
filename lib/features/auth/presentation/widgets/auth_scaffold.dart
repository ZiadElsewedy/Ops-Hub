import 'package:flutter/material.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';

/// Responsive chrome for the standalone auth/onboarding pages that live
/// **outside** the app shell (forgot password, forced password change, profile
/// completion).
///
/// * **Mobile / tablet** → the familiar transparent [AppBar] (optional back
///   button + optional actions), exactly like before.
/// * **Desktop / macOS** → no stretched-mobile body. The page content is centred
///   in a comfortable [maxWidth] column on the dark canvas (matching the Login
///   desktop panel), with a slim top utility row carrying the back button (left)
///   and any [actions] (right).
///
/// The [child] keeps its own scrolling — pass the page's existing
/// `SingleChildScrollView`; this only owns the chrome + centring.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.actions = const [],
    this.maxWidth = 440,
  });

  final Widget child;

  /// Show a back affordance (true for Forgot Password; false for the gate pages
  /// that the user must complete before continuing).
  final bool showBack;

  /// Trailing controls (e.g. a "Sign out" button on the gate pages).
  final List<Widget> actions;

  /// Comfortable column width on desktop.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          automaticallyImplyLeading: showBack,
          leading: showBack
              ? const BackButton(color: AppColors.textPrimary)
              : null,
          actions: actions,
        ),
        body: child,
      );
    }

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(
              children: [
                if (showBack && canPop)
                  _BackButton(onTap: () => Navigator.of(context).maybePop()),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.darkSurfaceElevated
                : AppColors.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              size: 19, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
