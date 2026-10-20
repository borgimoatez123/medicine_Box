import "package:flutter/material.dart";

import "../../controllers/patient_controller.dart";
import "../../controllers/patient_details_controller.dart";
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

class PatientInfoScreen extends StatefulWidget {
  const PatientInfoScreen({super.key, required this.controller});

  final PatientDetailsController controller;

  @override
  State<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  late final PatientController _patientController;

  @override
  void initState() {
    super.initState();
    _patientController = PatientController();
    final Patient? p = widget.controller.patient;
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _patientController.upsertPatientIfAbsent(p);
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
        } else if (existing.avatarUrl != livePatient.avatarUrl ||
            existing.fullName != livePatient.fullName) {
          _patientController.upsertPatient(livePatient);
        }
      }
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        if (widget.controller.patientLoading &&
            widget.controller.patient == null) {
          return const _CenteredIndicator();
        }
        final String? error = widget.controller.patientError;
        if (error != null && widget.controller.patient == null) {
          return _ErrorView(
            error: error,
            onRetry: () => widget.controller.loadPatient(forceRefresh: true),
          );
        }
        final dynamic p = widget.controller.patient;
        if (p == null) {
          return const _EmptyView();
        }
        return _PatientInfoBody(
          patient: p as Patient,
          avatarController: _patientController,
          onEdit: () => _openEdit(p),
        );
      },
    );
  }

  Future<void> _openEdit(Patient patient) async {
    final Patient? result = await Navigator.of(context).push<Patient>(
      MaterialPageRoute<Patient>(
        builder: (_) => UpdatePatientScreen(patient: patient),
      ),
    );
    if (result != null && mounted) {
      widget.controller.setPatient(result);
      _patientController.upsertPatient(result);
    }
  }
}

class _PatientInfoBody extends StatelessWidget {
  const _PatientInfoBody({
    required this.patient,
    required this.avatarController,
    required this.onEdit,
  });

  final Patient patient;
  final PatientController avatarController;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xs,
                    AppSpacing.xl,
                    AppSpacing.xxxl + 100,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      children: <Widget>[
                        Center(
                          child: PatientAvatarButton(
                            controller: avatarController,
                            patient: patient,
                            size: 112,
                            borderWidth: 3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _PatientName(patient: patient),
                        const SizedBox(height: AppSpacing.xl),
                        _InfoCard(
                          title: "Information",
                          rows: <_InfoRow>[
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: "First Name",
                              value: patient.firstname.trim().isEmpty
                                  ? "—"
                                  : patient.firstname.trim(),
                            ),
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: "Last Name",
                              value: patient.lastname.trim().isEmpty
                                  ? "—"
                                  : patient.lastname.trim(),
                            ),
                            if (patient.phone != null &&
                                patient.phone!.trim().isNotEmpty)
                              _InfoRow(
                                icon: Icons.phone_rounded,
                                label: "Phone",
                                value: patient.phone!.trim(),
                              ),
                            if (patient.gender != null &&
                                patient.gender!.trim().isNotEmpty)
                              _InfoRow(
                                icon: Icons.transgender_rounded,
                                label: "Gender",
                                value: patient.gender!.trim(),
                              ),
                            if (patient.birthDate != null)
                              _InfoRow(
                                icon: Icons.calendar_today_rounded,
                                label: "Date of Birth",
                                value: _formatDate(patient.birthDate!),
                              ),
                            if (patient.age != null)
                              _InfoRow(
                                icon: Icons.cake_rounded,
                                label: "Age",
                                value: "${patient.age} yrs",
                              ),
                            if (patient.weight != null)
                              _InfoRow(
                                icon: Icons.monitor_weight_outlined,
                                label: "Weight",
                                value: "${patient.weight} kg",
                              ),
                            if (patient.height != null)
                              _InfoRow(
                                icon: Icons.height_rounded,
                                label: "Height",
                                value: "${patient.height} cm",
                              ),
                            if (patient.bloodGroup != null &&
                                patient.bloodGroup!.trim().isNotEmpty)
                              _InfoRow(
                                icon: Icons.bloodtype_rounded,
                                label: "Blood Group",
                                value: patient.bloodGroup!.trim(),
                              ),
                            if (patient.medicalNotes != null &&
                                patient.medicalNotes!.trim().isNotEmpty)
                              _InfoRow(
                                icon: Icons.notes_rounded,
                                label: "Medical Notes",
                                value: patient.medicalNotes!.trim(),
                                multiline: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.xl,
                bottom: AppSpacing.xxxl,
                child: _EditFab(onPressed: onEdit),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientName extends StatelessWidget {
  const _PatientName({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final String fullName = patient.fullName.isEmpty
        ? "Unnamed patient"
        : patient.fullName;
    return Column(
      children: <Widget>[
        Text(
          fullName,
          style: AppTextStyles.headlineMedium(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (patient.phone != null && patient.phone!.trim().isNotEmpty)
          Text(
            patient.phone!.trim(),
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
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
                fontWeight: FontWeight.w600,
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

class _CenteredIndicator extends StatelessWidget {
  const _CenteredIndicator();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(top: false, child: Center(child: LoadingIndicator()));
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            "No patient selected.",
            style: AppTextStyles.bodyLarge(
              context,
            ).copyWith(color: AppColors.textSecondary),
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
