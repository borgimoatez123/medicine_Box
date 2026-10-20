import "package:flutter/material.dart";

import "../../utils/app_spacing.dart";

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          );
    final TextStyle style = compact
        ? Theme.of(context).elevatedButtonTheme.style?.textStyle?.resolve(
                  <WidgetState>{WidgetState.selected},
                ) ??
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)
        : const TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding,
        textStyle: style,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (isLoading) ...<Widget>[
            const SizedBox(width: 12),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ] else if (trailing != null) ...<Widget>[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}