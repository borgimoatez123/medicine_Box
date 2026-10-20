import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../controllers/patient_dashboard_controller.dart";
import "../../models/medication_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_shadows.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";
import "../medications/add_medication_screen.dart";
import "../medications/edit_medication_screen.dart";

class PatientMedicationsTab extends StatefulWidget {
  const PatientMedicationsTab({super.key, required this.controller});

  final PatientDashboardController controller;

  @override
  State<PatientMedicationsTab> createState() => _PatientMedicationsTabState();
}

class _PatientMedicationsTabState extends State<PatientMedicationsTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.medicationsSearch,
    );
    _searchController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.controller.setMedicationsSearch(_searchController.text);
  }

  Future<void> _refresh() async {
    if (widget.controller.patient == null) {
      await widget.controller.loadPatient();
    }
    await widget.controller.loadMedications();
  }

  Future<void> _openAddMedication() async {
    final patient = widget.controller.patient;
    final String pid = (patient?.id ?? "").trim();
    if (pid.isEmpty) return;
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddMedicationScreen(patient: patient, patientId: pid),
      ),
    );
    if (created == true && mounted) {
      await widget.controller.loadMedications();
    }
  }

  Future<void> _openEditMedication(MedicationModel medication) async {
    final patient = widget.controller.patient;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditMedicationScreen(medication: medication, patient: patient),
      ),
    );
    if (saved == true && mounted) {
      await widget.controller.loadMedications();
    }
  }

  Future<bool> _showDeleteConfirmation(MedicationModel medication) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
          title: Row(
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  "Delete medication?",
                  style: AppTextStyles.titleLarge(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                  children: <TextSpan>[
                    const TextSpan(text: "Are you sure you want to delete "),
                    TextSpan(
                      text: medication.name.trim().isEmpty
                          ? "this medication"
                          : medication.name.trim(),
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: "?"),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "This will also remove its schedules and drawer assignment.",
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                "Cancel",
                style: AppTextStyles.label(context).copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool> _confirmDismiss(MedicationModel medication) async {
    final bool confirmed = await _showDeleteConfirmation(medication);
    if (!confirmed) return false;
    try {
      await widget.controller.deleteMedication(medication);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
              content: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "Medication deleted successfully.",
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
      }
      return true;
    } catch (e) {
      if (mounted) {
        final String message = e is MedicationControllerException
            ? e.message
            : e.toString();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
              content: Row(
                children: <Widget>[
                  const Icon(Icons.error_rounded, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message.isEmpty
                          ? "Failed to delete medication."
                          : message,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double maxWidth = constraints.maxWidth > 560
                        ? 560
                        : constraints.maxWidth;
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.xs,
                                  AppSpacing.md,
                                  AppSpacing.xs,
                                ),
                                child: _SearchField(
                                  controller: _searchController,
                                  onClear: () {
                                    _searchController.text = "";
                                    widget.controller.setMedicationsSearch("");
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.xs),
                        ),
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: _Body(
                                controller: widget.controller,
                                onAdd: _openAddMedication,
                                onTapMedication: _openEditMedication,
                                confirmDismiss: _confirmDismiss,
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.xxxl + 110),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                right: 24,
                bottom: 132,
                child: _FloatingAddButton(
                  onPressed: _openAddMedication,
                  label: "Add Medicine",
                  icon: Icons.add_rounded,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br14,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: TextField(
        controller: controller,
        style: AppTextStyles.bodyMedium(
          context,
        ).copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: "Search medications...",
          hintStyle: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: AppColors.hintText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.icon,
            size: 22,
          ),
          suffixIcon: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? _) {
              final bool show = controller.text.trim().isNotEmpty;
              return show
                  ? InkWell(
                      onTap: onClear,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: AppColors.icon,
                          size: 20,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    this.onAdd,
    required this.onTapMedication,
    required this.confirmDismiss,
  });

  final PatientDashboardController controller;
  final VoidCallback? onAdd;
  final Future<void> Function(MedicationModel medication) onTapMedication;
  final Future<bool> Function(MedicationModel medication) confirmDismiss;

  @override
  Widget build(BuildContext context) {
    if (controller.medicationsLoading && controller.medications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: LoadingIndicator()),
      );
    }
    final String? error = controller.medicationsError;
    if (error != null && controller.medications.isEmpty) {
      return _ErrorListView(
        error: error,
        onRetry: () => controller.loadMedications(),
      );
    }
    final List<MedicationModel> list = controller.filteredMedications;
    if (list.isEmpty) {
      return controller.medicationsSearch.trim().isNotEmpty
          ? _EmptySearchView(query: controller.medicationsSearch)
          : _EmptyListView(onAdd: onAdd);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: List<Widget>.generate(list.length, (int i) {
          final MedicationModel m = list[i];
          final String keyId = m.id.trim().isEmpty
              ? "med-tab-$i-${m.name}"
              : m.id;
          return Padding(
            padding: EdgeInsets.only(
              bottom: i == list.length - 1 ? 0 : AppSpacing.md,
            ),
            child: Dismissible(
              key: ValueKey<String>(keyId),
              direction: DismissDirection.horizontal,
              dismissThresholds: const <DismissDirection, double>{
                DismissDirection.startToEnd: 0.45,
                DismissDirection.endToStart: 0.45,
              },
              movementDuration: const Duration(milliseconds: 260),
              resizeDuration: const Duration(milliseconds: 260),
              confirmDismiss: (_) => confirmDismiss(m),
              background: const _DismissDeleteBackground(
                alignment: Alignment.centerLeft,
              ),
              secondaryBackground: const _DismissDeleteBackground(
                alignment: Alignment.centerRight,
              ),
              child: _MedicationCard(
                medication: m,
                onTap: () => onTapMedication(m),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication, this.onTap});

  final MedicationModel medication;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color? statusColor = medication.status.medicationStatusColor;
    final String rawStatus = medication.status ?? "Active";
    final String statusLabel = rawStatus.trim().isEmpty
        ? "Active"
        : rawStatus.trim();

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.br16,
      child: InkWell(
        borderRadius: AppRadius.br16,
        onTap: onTap,
        child: Container(
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
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: AppRadius.br12,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          medication.name.trim().isEmpty
                              ? "Unnamed medication"
                              : medication.name.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLarge(context).copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (medication.dosage.trim().isNotEmpty)
                          Text(
                            "Dosage: ${medication.dosage.trim()}",
                            style: AppTextStyles.bodyMedium(
                              context,
                            ).copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (statusColor ?? AppColors.secondaryBackground)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (statusColor ?? AppColors.border).withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.label(context).copyWith(
                        color: statusColor ?? AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                runSpacing: AppSpacing.xxs,
                spacing: AppSpacing.xs,
                children: <Widget>[
                  _MetaChip(
                    icon: Icons.inventory_2_rounded,
                    label: medication.quantity.toString(),
                  ),
                  _MetaChip(
                    icon: Icons.category_rounded,
                    label: medication.form.backendValue.toUpperCase(),
                  ),
                  if (medication.expiryDate != null)
                    _MetaChip(
                      icon: Icons.event_rounded,
                      label: "Expires ${_formatDate(medication.expiryDate!)}",
                    ),
                  if (medication.frequency != null &&
                      medication.frequency!.trim().isNotEmpty)
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: medication.frequency!.trim(),
                    ),
                  if (medication.startDate != null)
                    _MetaChip(
                      icon: Icons.event_available_rounded,
                      label: "Start ${_formatDate(medication.startDate!)}",
                    ),
                  if (medication.endDate != null)
                    _MetaChip(
                      icon: Icons.event_busy_rounded,
                      label: "End ${_formatDate(medication.endDate!)}",
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.icon),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(context).copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListView extends StatelessWidget {
  const _EmptyListView({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadius.br16,
              boxShadow: AppShadows.softCard,
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "No medications found",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Medications for this patient will appear here.",
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: PrimaryButton(
              label: "Add Medicine",
              onPressed: onAdd,
              leading: const Icon(Icons.add_rounded, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl * 2),
        ],
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadius.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.icon,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "No results for \"$query\"",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Try a different search term.",
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 2),
        ],
      ),
    );
  }
}

class _ErrorListView extends StatelessWidget {
  const _ErrorListView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.lg),
            Icon(Icons.error_outline_rounded, size: 72, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Unable to load medications.",
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
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _DismissDeleteBackground extends StatelessWidget {
  const _DismissDeleteBackground({required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final bool isLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppRadius.br16,
      ),
      alignment: alignment,
      padding: EdgeInsets.symmetric(
        horizontal: isLeft ? AppSpacing.lg + AppSpacing.xs : AppSpacing.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isLeft) const SizedBox(width: 8),
          const Icon(
            Icons.delete_forever_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              "Delete",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (isLeft) const SizedBox(width: 8),
        ],
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

class _FloatingAddButton extends StatelessWidget {
  const _FloatingAddButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.titleLarge(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
