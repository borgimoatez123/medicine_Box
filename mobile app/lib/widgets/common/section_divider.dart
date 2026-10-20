import "package:flutter/material.dart";

import "../../utils/app_colors.dart";
import "../../utils/app_palette.dart";
import "../../utils/app_spacing.dart";

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(label, style: style),
        ),
        Expanded(child: Divider(color: palette.divider)),
      ],
    );
  }
}
