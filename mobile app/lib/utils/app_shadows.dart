import "package:flutter/material.dart";

import "app_colors.dart";

class AppShadows {
  static List<BoxShadow> get softCard => <BoxShadow>[
        BoxShadow(
          color: AppColors.shadowSoft,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softBorder => <BoxShadow>[
        BoxShadow(
          color: AppColors.border,
          blurRadius: 0,
          offset: const Offset(0, 0),
        ),
      ];
}
