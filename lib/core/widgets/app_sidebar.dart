import 'package:flutter/material.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/drop_logo.dart';

/// A single navigable destination in the [AppSidebar].
class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.trailingBuilder,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  /// Optional live trailing widget (e.g. an unread badge). Built per-frame so it
  /// can react to a cubit. Kept generic so `core/` never hardcodes a feature.
  final WidgetBuilder? trailingBuilder;
}

/// An optionally-titled group of destinations.
class SidebarSection {
  const SidebarSection({this.title, required this.items});
  final String? title;
  final List<SidebarItem> items;
}

/// The premium, persistent left navigation for the desktop / macOS layout.
///
/// Mounted once by [AppShell] and kept alive across route changes, so it never
/// re-animates or flickers as the user moves between screens — the hallmark of a
/// native desktop app vs. a stretched mobile one. Strictly monochrome, with the
/// white [AppColors.accent] reserved for the single active destination.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.sections,
    required this.location,
    required this.onSelect,
    this.footer,
    this.onCollapse,
  });

  final List<SidebarSection> sections;

  /// The current router location, used to resolve the active destination.
  final String location;

  final ValueChanged<String> onSelect;
  final Widget? footer;

  /// When set, a subtle collapse control appears in the header — tapping it
  /// hides the sidebar (focus mode). Null hides the control entirely.
  final VoidCallback? onCollapse;

  /// The route of the best-matching destination for [location] — the longest
  /// route that is a prefix of (or equal to) the current location.
  String? get _activeRoute {
    String? best;
    for (final section in sections) {
      for (final item in section.items) {
        final isMatch =
            location == item.route || location.startsWith('${item.route}/');
        if (isMatch && (best == null || item.route.length > best.length)) {
          best = item.route;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeRoute;
    // Flat destination order — matches the AppShell ⌘1…⌘9 shortcut bindings,
    // so each row can hint its own shortcut on hover.
    final flat = [for (final s in sections) ...s.items];
    return Container(
      width: Breakpoints.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(right: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand header — the real DROP artwork. Keep persistent desktop
            // chrome static so idle navigation never burns the UI thread.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const DropLogo(height: 30),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'OPERATIONS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  if (onCollapse != null) ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: _SidebarCollapseButton(onTap: onCollapse!),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final section in sections) ...[
                    if (section.title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                        child: Text(
                          section.title!.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    for (final item in section.items)
                      _SidebarRow(
                        item: item,
                        selected: item.route == active,
                        shortcutHint: flat.indexOf(item) < 9
                            ? '⌘${flat.indexOf(item) + 1}'
                            : null,
                        onTap: () => onSelect(item.route),
                      ),
                  ],
                ],
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1, color: AppColors.darkBorder),
              Padding(padding: const EdgeInsets.all(12), child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.shortcutHint,
  });

  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Keyboard shortcut label (e.g. "⌘1"), revealed on hover.
  final String? shortcutHint;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color fg = selected
        ? AppColors.textPrimary
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);
    final Color bg = selected
        ? AppColors.accentSurface
        : (_hovered ? const Color(0x12FFFFFF) : AppColors.transparent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.accentBorder : AppColors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: selected ? 18 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? widget.item.activeIcon : widget.item.icon,
                  size: 19,
                  color: selected ? AppColors.accent : fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.item.trailingBuilder != null)
                  widget.item.trailingBuilder!(context),
                if (widget.shortcutHint != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _hovered ? 1 : 0,
                    child: Text(
                      widget.shortcutHint!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The header collapse control — hides the sidebar into focus mode. Monochrome,
/// hover-lit; the ⌘\ shortcut is surfaced in its tooltip.
class _SidebarCollapseButton extends StatefulWidget {
  const _SidebarCollapseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SidebarCollapseButton> createState() => _SidebarCollapseButtonState();
}

class _SidebarCollapseButtonState extends State<_SidebarCollapseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hide sidebar',
      child: Tooltip(
        message: 'Hide sidebar   ⌘\\',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered ? const Color(0x12FFFFFF) : AppColors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.menu_open_rounded,
                size: 18,
                color: _hovered ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
