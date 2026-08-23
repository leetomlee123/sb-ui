import 'package:flutter/material.dart';

class DoubleBezelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry outerPadding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isInteractive;

  const DoubleBezelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.outerPadding = EdgeInsets.zero,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.isSelected = false,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultOuterBg = isDark
        ? const Color(0xFF131B2E).withValues(alpha: 0.6)
        : const Color(0xFFE2E8F0).withValues(alpha: 0.6);

    final defaultInnerBg = backgroundColor ??
        (isDark ? const Color(0xFF0C1220) : Colors.white);

    final activeBorder = isSelected
        ? const Color(0xFF6366F1)
        : (borderColor ??
            (isDark
                ? const Color(0xFF243049).withValues(alpha: 0.7)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.8)));

    Widget content = Container(
      margin: outerPadding,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6366F1).withValues(alpha: 0.25)
            : defaultOuterBg,
        borderRadius: BorderRadius.circular(borderRadius + 1.5),
        border: Border.all(color: activeBorder, width: isSelected ? 1.5 : 1),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: defaultInnerBg,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: child,
      ),
    );

    if (onTap != null || isInteractive) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius + 1.5),
        splashColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: content,
      );
    }

    return content;
  }
}
