import 'package:flutter/material.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/opshub_lockup.dart';

/// A scaffold that adapts its chrome to the platform width.
///
/// * **Mobile / tablet** → the familiar [AppBar] (title + actions + automatic
///   back button). On iOS the native left-edge swipe-back works **in addition**
///   to the button (see `core/routes/app_page_route.dart`).
/// * **Desktop / macOS** → no mobile app bar. Instead a calm, generously-spaced
///   in-body **page header** (large title, optional subtitle, right-aligned
///   actions, hairline divider) sits beside the persistent [AppShell] sidebar,
///   and the body is centred in a comfortable max-width column.
///
/// This is the drop-in used to migrate a screen off the "stretched mobile"
/// look: replace `Scaffold(appBar: AppBar(title: …, actions: …), body: …)` with
/// `AdaptiveScaffold(title: …, actions: …, body: …)`.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.titleWidget,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.bottom,
    this.bottomBar,
    this.constrainContent = true,
    this.contentMaxWidth,
    this.scrollableHeaderActions = false,
    this.showBrandMark = true,
    this.compactDesktopHeader = false,
  });

  final String title;
  final String? subtitle;

  /// Optional custom title lockup (e.g. a branch avatar + name) that replaces
  /// the plain [title]/[subtitle] text in both the mobile app bar and the
  /// desktop page header. [title] is still used as the accessible/window label.
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;

  /// Optional custom leading control (e.g. a sub-view back toggle). When null,
  /// the desktop header auto-shows a back button if the route can pop, and the
  /// mobile app bar uses its automatic back button.
  final Widget? leading;
  final Widget? floatingActionButton;

  /// Optional widget pinned under the header on desktop / under the app bar on
  /// mobile (e.g. a [TabBar] or a filter row).
  final PreferredSizeWidget? bottom;

  /// Optional bar pinned to the very bottom of the screen (e.g. a send / submit
  /// action bar). Maps to [Scaffold.bottomNavigationBar] on both tiers.
  final Widget? bottomBar;

  /// Centre the body in a comfortable max-width column on wide windows.
  final bool constrainContent;

  /// Overrides the centred column width when [constrainContent] is true. Useful
  /// for forms, which read best in a narrow (~560) column rather than the wide
  /// default dashboard width. Null → the default [Breakpoints.contentMaxWidth].
  final double? contentMaxWidth;

  /// When true the header actions sit in a scrollable row (avoids overflow when
  /// a screen has many actions on a narrow desktop window).
  final bool scrollableHeaderActions;

  /// Quiet OpsHub brand mark at the trailing edge of the **mobile** app bar
  /// (desktop is already branded by the persistent [AppSidebar] lockup).
  /// Non-interactive and tinted tertiary so it never competes with actions.
  final bool showBrandMark;

  /// Opts this page into a more compact desktop header. It is intentionally
  /// opt-in so established desktop surfaces keep their approved hierarchy.
  final bool compactDesktopHeader;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          elevation: 0,
          title: titleWidget ?? Text(title, style: AppTypography.h3),
          leading: leading,
          actions: [...actions, if (showBrandMark) const _AppBarBrandMark()],
          bottom: bottom,
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomBar,
      );
    }

    final canPop = Navigator.of(context).canPop();
    final content = constrainContent
        ? ContentConstraint(
            maxWidth: contentMaxWidth ?? Breakpoints.contentMaxWidth,
            child: body,
          )
        : body;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopPageHeader(
            title: title,
            subtitle: subtitle,
            titleWidget: titleWidget,
            actions: actions,
            leading: leading,
            scrollableActions: scrollableHeaderActions,
            compact: compactDesktopHeader,
            onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          if (bottom != null) ...[
            bottom!,
            const Divider(height: 1, color: AppColors.darkBorder),
          ],
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// The quiet OpsHub brand lockup (mark + name) closing every mobile app bar —
/// brand presence on all migrated screens without competing with the actionable
/// icons beside it. Capped and scale-down-fitted so a crowded bar shrinks the
/// lockup as one unit rather than ever truncating the name.
class _AppBarBrandMark extends StatelessWidget {
  const _AppBarBrandMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: OpsHubLockup(
                height: 16, color: AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _DesktopPageHeader extends StatelessWidget {
  const _DesktopPageHeader({
    required this.title,
    required this.subtitle,
    required this.titleWidget,
    required this.actions,
    required this.leading,
    required this.scrollableActions,
    required this.compact,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget? leading;
  final bool scrollableActions;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final headerVerticalPadding = compact ? AppSpacing.sm : 22.0;
    final actionRow = actions.isEmpty
        ? const SizedBox.shrink()
        : Row(mainAxisSize: MainAxisSize.min, children: actions);

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 68 : 76),
      color: AppColors.darkBg,
      padding: EdgeInsets.fromLTRB(
        40,
        headerVerticalPadding,
        40,
        headerVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 14),
          ] else if (onBack != null) ...[
            _HeaderBackButton(onTap: onBack!),
            const SizedBox(width: 14),
          ],
          Expanded(
            child:
                titleWidget ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: compact ? AppTypography.h2 : AppTypography.h1,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: compact
                            ? AppTypography.bodySmall
                            : AppTypography.body,
                      ),
                    ],
                  ],
                ),
          ),
          const SizedBox(width: 16),
          if (scrollableActions)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: actionRow,
              ),
            )
          else
            actionRow,
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatefulWidget {
  const _HeaderBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HeaderBackButton> createState() => _HeaderBackButtonState();
}

class _HeaderBackButtonState extends State<_HeaderBackButton> {
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
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
