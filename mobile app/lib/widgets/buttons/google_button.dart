import "package:flutter/material.dart";

import "../../utils/app_spacing.dart";

class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          leading ?? const Icon(Icons.g_mobiledata_rounded),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
