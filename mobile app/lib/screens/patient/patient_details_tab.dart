import "package:flutter/material.dart";

import "../../controllers/patient_controller.dart";
import "../../controllers/patient_dashboard_controller.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_shadows.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";
import "../../widgets/patient_avatar_button.dart";
import "update_patient_screen.dart";

class PatientDetailsTab extends StatefulWidget {
  const PatientDetailsTab({super.key, required this.controller});

  final PatientDashboardController controller;

  @override
  State<PatientDetailsTab> createState() => _PatientDetailsTabState();
}

class _PatientDetailsTabState extends State<PatientDetailsTab> {
  late final PatientController _patientController;

  @override
  void initState() {
    super.initState();
    _patientController = PatientController();
    final Patient? p = widget.controller.patient;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final Set<String> existing = _patientController.patients
            .map((Patient p) => p.id)
            .where((String s) => s.isNotEmpty)
            .toSet();
        if (!existing.contains(p.id.trim())) {
          _patientController.upsertPatient(p);
        }
      });
    }
  }

  @override
  void dispose() {
    _patientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Patient? livePatient = widget.controller.patient;
    if (livePatient != null) {
      final String id = livePatient.id.trim();
      if (id.isNotEmpty) {
        final Patient? existing = _patientController.findById(id);
        if (existing == null) {
          _patientController.upsertPatientIfAbsent(livePatient);
        } else {
          if (existing.avatarUrl != livePatient.avatarUrl ||
              existing.fullName != livePatient.fullName) {
            _patientController.upsertPatient(livePatient);
          }
        }
      }
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        if (widget.controller.patientLoading &&
            widget.controller.patient == null) {
          return const SafeArea(
            top: false,
            child: Center(child: LoadingIndicator()),
          );
        }
        final String? error = widget.controller.patientError;
        if (error != null && widget.controller.patient == null) {
          return _ErrorView(
            error: error,
            onRetry: () => widget.controller.loadPatient(forceRefresh: true),
          );
        }
        final Patient? p = widget.controller.patient;
        if (p == null) {
          return const SafeArea(
            top: false,
            child: Center(child: Text("No patient selected.")),
          );
        }
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth > 520
                  ? 520
                  : constraints.maxWidth;
              return Stack(
                children: <Widget>[
                  Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xxxl + 140,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: <Widget>[
                            _PatientHeader(
                              patient: p,
                              controller: _patientController,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SectionCard(
                              title: "Personal Information",
                              rows: <_InfoRow>[
                                _InfoRow(
                                  icon: Icons.person_outline_rounded,
                                  label: "First Name",
                                  value: p.firstname.trim().isEmpty
                                      ? "—"
                                      : p.firstname.trim(),
                                ),
                                _InfoRow(
                                  icon: Icons.person_outline_rounded,
                                  label: "Last Name",
                                  value: p.lastname.trim().isEmpty
                                      ? "—"
                                      : p.lastname.trim(),
                                ),
                                if (p.phone != null &&
                                    p.phone!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.phone_rounded,
                                    label: "Phone",
                                    value: p.phone!.trim(),
                                  ),
                                if (p.gender != null &&
                                    p.gender!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.transgender_rounded,
                                    label: "Gender",
                                    value: p.gender!.trim(),
                                  ),
                                if (p.birthDate != null)
                                  _InfoRow(
                                    icon: Icons.calendar_today_rounded,
                                    label: "Date of Birth",
                                    value: _formatDate(p.birthDate!),
                                  ),
                                if (p.age != null)
                                  _InfoRow(
                                    icon: Icons.cake_rounded,
                                    label: "Age",
                                    value: "${p.age} yrs",
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _SectionCard(
                              title: "Medical Information",
                              rows: <_InfoRow>[
                                if (p.weight != null)
                                  _InfoRow(
                                    icon: Icons.monitor_weight_outlined,
                                    label: "Weight",
                                    value: "${p.weight} kg",
                                  ),
                                if (p.height != null)
                                  _InfoRow(
                                    icon: Icons.height_rounded,
                                    label: "Height",
                                    value: "${p.height} cm",
                                  ),
                                if (p.bloodGroup != null &&
                                    p.bloodGroup!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.bloodtype_rounded,
                                    label: "Blood Group",
                                    value: p.bloodGroup!.trim(),
                                  ),
                                if (p.medicalNotes != null &&
                                    p.medicalNotes!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.notes_rounded,
                                    label: "Medical Notes",
                                    value: p.medicalNotes!.trim(),
                                    multiline: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.xxxl,
                    child: _EditFab(onPressed: () => _openEdit(p)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEdit(Patient patient) async {
    final Patient? result = await Navigator.of(context).push<Patient>(
      MaterialPageRoute<Patient>(
        builder: (_) => UpdatePatientScreen(
          patient: patient,
          dashboardController: widget.controller,
        ),
      ),
    );
    if (result != null && mounted) {
      widget.controller.setPatient(result);
      _patientController.upsertPatient(result);
    }
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient, required this.controller});

  final Patient patient;
  final PatientController controller;

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 104;
    final String fullName = patient.fullName.trim().isEmpty
        ? "Unnamed patient"
        : patient.fullName.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Center(
            child: PatientAvatarButton(
              controller: controller,
              patient: patient,
              size: avatarSize,
              borderWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            fullName,
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          if (patient.phone != null &&
              patient.phone!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              patient.phone!.trim(),
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              title,
              style: AppTextStyles.titleLarge(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.br12,
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.br12,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.iconPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.label(context).copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: multiline ? 8 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  "Unable to load patient information.",
                  style: AppTextStyles.titleLarge(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  error,
                  style: AppTextStyles.bodyMedium(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(label: "Retry", onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final String day = date.day.toString().padLeft(2, "0");
  final String month = date.month.toString().padLeft(2, "0");
  final String year = date.year.toString();
  return "$year-$month-$day";
}

class _EditFab extends StatelessWidget {
  const _EditFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.edit_rounded, size: 20),
      label: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          "Edit",
          style: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
