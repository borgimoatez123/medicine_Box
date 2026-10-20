import "package:flutter/material.dart";

import "../models/patient.dart";
import "../utils/app_colors.dart";
import "../utils/app_palette.dart";
import "../utils/app_radius.dart";
import "../utils/app_shadows.dart";
import "../utils/app_spacing.dart";
import "../utils/app_text_styles.dart";

class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.patient, this.onTap});

  final Patient patient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.br16,
        child: Ink(
          decoration: BoxDecoration(
            color: palette.cardBackground,
            borderRadius: AppRadius.br16,
            border: Border.all(color: palette.border),
            boxShadow: palette.isDark ? const <BoxShadow>[] : AppShadows.softCard,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                _Avatar(url: patient.profileImage),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              patient.fullName.isEmpty
                                  ? "Unnamed patient"
                                  : patient.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleLarge(
                                context,
                              ).copyWith(color: palette.textPrimary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const _StatusDot(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        patient.phone?.trim().isNotEmpty == true
                            ? patient.phone!.trim()
                            : "No phone",
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          if (patient.gender?.trim().isNotEmpty == true)
                            _MetaChip(text: patient.gender!.trim()),
                          if (patient.age != null)
                            _MetaChip(text: "${patient.age} yrs"),
                          if (patient.medicationsCount != null)
                            _MetaChip(text: "${patient.medicationsCount} meds"),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: palette.icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    final String? u = url?.trim();
    final Widget placeholder = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: palette.secondaryBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, color: palette.icon),
    );

    if (u == null || u.isEmpty) return placeholder;

    final Uri? uri = Uri.tryParse(u);
    final bool isRemote =
        uri != null && (uri.isScheme("http") || uri.isScheme("https"));

    if (!isRemote) return placeholder;

    return ClipOval(
      child: Image.network(
        u,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          return placeholder;
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondaryBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: AppTextStyles.label(
          context,
        ).copyWith(color: palette.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success,
      ),
    );
  }
}
