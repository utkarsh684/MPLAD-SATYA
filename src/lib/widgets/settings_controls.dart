import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// A labelled settings group with a card body.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.footnote,
  });

  final String title;
  final IconData? icon;
  final String? footnote;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                ],
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                footnote!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A segmented control. Replaces stacked radio rows, which cost three taps'
/// worth of vertical space to express one choice.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _Segment(
                  option: option,
                  selected: option.value == value,
                  onTap: () => onChanged(option.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      selected: selected,
      button: true,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.govBlue : AppColors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 15,
                  color: selected
                      ? (isDark ? Colors.white : AppColors.govBlue)
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (isDark ? Colors.white : AppColors.govBlue)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with a consistent 56 dp touch target.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.sublabel,
    this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: iconColor ?? AppColors.govBlue),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (sublabel != null) ...[
                        const SizedBox(height: 2),
                        Text(sublabel!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textTertiary)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ] else if (onTap != null)
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: icon != null ? 48 : 14,
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
      ],
    );
  }
}
