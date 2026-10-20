import "package:flutter/material.dart";

import "../../utils/app_colors.dart";
import "../../utils/app_palette.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
  });

  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title == null ? null : Text(title!),
      actions: actions,
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: _BackButton(
                onPressed:
                    onBackPressed ?? () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Material(
      color: palette.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br12,
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.br12,
        onTap: onPressed,
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: palette.icon,
          ),
        ),
      ),
    );
  }
}
