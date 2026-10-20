import "package:flutter/material.dart";

import "../utils/app_colors.dart";
import "../utils/app_palette.dart";
import "../utils/app_spacing.dart";
import "../utils/app_text_styles.dart";

class EmptyPatientWidget extends StatelessWidget {
  const EmptyPatientWidget({super.key, required this.onAddPatient});

  final VoidCallback onAddPatient;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset(
            "assets/images/empty_patient.png",
            height: 240,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return SizedBox(
                    height: 240,
                    child: Center(
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 80,
                        color: palette.border,
                      ),
                    ),
                  );
                },
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            "No patients yet",
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium(context).copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Add your first patient to start managing medications, reminders and monitoring.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddPatient,
              icon: const Icon(Icons.add_rounded, size: 20),
              style: ElevatedButton.styleFrom(
                foregroundColor: palette.isDark
                    ? const Color(0xFF2A120A)
                    : palette.textPrimary,
                backgroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              label: Text(
                "Add Patient",
                style: AppTextStyles.button(context).copyWith(
                  color: palette.isDark
                      ? const Color(0xFF2A120A)
                      : palette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
