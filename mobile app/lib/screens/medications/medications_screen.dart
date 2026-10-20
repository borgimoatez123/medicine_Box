import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../controllers/patient_controller.dart";
import "../../models/medication_model.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_shadows.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";
import "../medications/add_medication_screen.dart";
import "../medications/edit_medication_screen.dart";

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  static const String _logoAssetPath = "lib/assets/icons/pills_logo.png";

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final MedicationController _medController;
  late final PatientController _patientController;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  String _search = "";
  bool _isAdding = false;

  List<MedicationModel> get _filtered {
    final String q = _search.trim().toLowerCase();
    final List<MedicationModel> list = _medController.medications;
    if (q.isEmpty) return list;
    return list
        .where((MedicationModel m) {
          final String name = m.name.trim().toLowerCase();
          final String dosage = m.dosage.trim().toLowerCase();
          final String form = m.form.backendValue.toLowerCase();
          return name.contains(q) || dosage.contains(q) || form.contains(q);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _medController = MedicationController()..addListener(_onMed);
    _patientController = PatientController()..addListener(_onPatient);
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() => _search = _searchController.text);
        }
      });
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _medController.removeListener(_onMed);
    _patientController.removeListener(_onPatient);
    _medController.dispose();
    _patientController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMed() {
    if (mounted) setState(() {});
  }

  void _onPatient() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await Future.wait(<Future<void>>[
      _medController.loadMedications(),
      _patientController.loadPatients(limit: 50),
    ]);
  }

  Future<void> _refresh() async {
    await Future.wait(<Future<void>>[
      _medController.refresh(),
      _patientController.refresh(limit: 50),
    ]);
  }

  Future<void> _openEditMedication(MedicationModel medication) async {
    final Patient? patient = _patientById(medication.patientId);
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditMedicationScreen(
          medication: medication,
          patient: patient,
          patientName: patient?.fullNameDisplay,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _medController.refresh();
    }
  }

  Future<bool> _showDeleteConfirmation(MedicationModel medication) async {
    final Patient? patient = _patientById(medication.patientId);
    final String displayName = patient?.fullNameDisplay ?? "this patient";
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
                  ).copyWith(color: AppColors.textSecondary, height: 1.4),
                  children: <TextSpan>[
                    const TextSpan(text: "Are you sure you want to delete "),
                    TextSpan(
                      text: medication.name.trim().isEmpty
                          ? "this medication"
                          : medication.name.trim(),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: " for "),
                    TextSpan(
                      text: displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text:
                          "? This will also remove its schedules and drawer assignment.",
                    ),
                  ],
                ),
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
                  horizontal: AppSpacing.lg,
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
      await _medController.deleteMedication(medication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.br14),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            content: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    "Medication deleted",
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.br14),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            content: Row(
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    e is MedicationControllerException
                        ? e.message
                        : "Unable to delete medication.",
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return false;
    }
  }

  Patient? _patientById(String? patientId) {
    final String key = (patientId ?? "").trim();
    if (key.isEmpty) return null;
    for (final Patient p in _patientController.patients) {
      if (p.id.trim() == key) return p;
    }
    return null;
  }

  Future<void> _openAddMedication() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      if (_patientController.isLoading && _patientController.patients.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      List<Patient> patients = _patientController.patients;
      if (patients.isEmpty) {
        try {
          await _patientController.refresh(limit: 50);
        } catch (_) {}
        patients = _patientController.patients;
      }
      if (!mounted) return;
      if (patients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.br14),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            content: Row(
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    "Add a patient first before creating medications.",
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
      final Patient? selected;
      if (patients.length == 1) {
        selected = patients.single;
      } else {
        if (!mounted) return;
        selected = await showModalBottomSheet<Patient>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (BuildContext bc) {
            return _PatientPickerSheet(patients: patients);
          },
        );
      }
      if (selected == null) return;
      if (!mounted) return;
      final Patient chosen = selected;
      final bool? created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              AddMedicationScreen(patient: chosen, patientId: chosen.id.trim()),
        ),
      );
      if (created == true && mounted) {
        await _medController.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.br14),
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              content: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      "Medication added",
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalMeds = _medController.medications.length;
    final int expiring = _medController.medications
        .where((MedicationModel m) => _isExpiringSoon(m.expiryDate))
        .length;
    final int lowStock = _medController.medications
        .where((MedicationModel m) => m.quantity > 0 && m.quantity <= 10)
        .length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _Header(
                        totalMeds: totalMeds,
                        expiringSoon: expiring,
                        lowStock: lowStock,
                        logoAssetPath: MedicationsScreen._logoAssetPath,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        child: _SearchField(
                          controller: _searchController,
                          onClear: () => _searchController.clear(),
                        ),
                      ),
                    ),
                    if (_medController.isLoading &&
                        _medController.medications.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.xxxl,
                          ),
                          child: Center(child: LoadingIndicator()),
                        ),
                      )
                    else if (_medController.error != null &&
                        _medController.medications.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xxxl,
                          ),
                          child: _ErrorView(
                            error: _medController.error!,
                            onRetry: _refresh,
                          ),
                        ),
                      )
                    else if (_filtered.isEmpty &&
                        _medController.medications.isNotEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxxl,
                            horizontal: AppSpacing.xl,
                          ),
                          child: _EmptySearchView(query: _search),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyListView(
                          onAdd: _openAddMedication,
                          patientsCount: _patientController.patients.length,
                        ),
                      )
                    else ...<Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        sliver: SliverList.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int index) {
                            final MedicationModel m = _filtered[index];
                            final Patient? patient = _patientById(m.patientId);
                            final String keyId = "med_${m.id}_$index";
                            return Dismissible(
                              key: ValueKey<String>(keyId),
                              direction: DismissDirection.horizontal,
                              dismissThresholds:
                                  const <DismissDirection, double>{
                                    DismissDirection.startToEnd: 0.45,
                                    DismissDirection.endToStart: 0.45,
                                  },
                              movementDuration: const Duration(
                                milliseconds: 260,
                              ),
                              resizeDuration: const Duration(milliseconds: 260),
                              confirmDismiss: (_) => _confirmDismiss(m),
                              background: const _DismissDeleteBackground(
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground:
                                  const _DismissDeleteBackground(
                                    alignment: Alignment.centerRight,
                                  ),
                              child: _MedicationCard(
                                medication: m,
                                patientName: patient?.fullNameDisplay,
                                onTap: () => _openEditMedication(m),
                              ),
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 260)),
                    ],
                  ],
                ),
                Positioned(
                  right: AppSpacing.xl,
                  bottom: 172,
                  child: _FloatingAddButton(
                    onPressed: _openAddMedication,
                    label: "Add Medicine",
                    icon: Icons.add_rounded,
                    isLoading: _isAdding,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _isExpiringSoon(DateTime? date) {
    if (date == null) return false;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime expiry = DateTime(date.year, date.month, date.day);
    final int days = expiry.difference(today).inDays;
    return days >= 0 && days <= 30;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalMeds,
    required this.expiringSoon,
    required this.lowStock,
    required this.logoAssetPath,
  });

  final int totalMeds;
  final int expiringSoon;
  final int lowStock;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final Color primary = AppColors.primary;
    final Color primaryDark = AppColors.primaryDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            primary.withValues(alpha: 0.92),
            primaryDark.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: primary.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.br14,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.medication_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Medications",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tap a card to edit · swipe to delete",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatPill(
                  value: totalMeds,
                  label: "Total",
                  icon: Icons.inventory_2_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatPill(
                  value: expiringSoon,
                  label: "Expiring",
                  icon: Icons.event_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatPill(
                  value: lowStock,
                  label: "Low Stock",
                  icon: Icons.inventory_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.br16,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 18),
              const Spacer(),
              Text(
                value.toString(),
                style: AppTextStyles.headlineMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label(context).copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    this.patientName,
    this.onTap,
  });

  final MedicationModel medication;
  final String? patientName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color? statusColor = medication.status.medicationStatusColor;
    final String statusLabel = (medication.status ?? "Active").trim().isEmpty
        ? "Active"
        : (medication.status ?? "Active").trim();
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AppColors.primaryLight,
                          AppColors.primary,
                        ],
                      ),
                      borderRadius: AppRadius.br12,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.medication_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                medication.name.trim().isEmpty
                                    ? "Unnamed medication"
                                    : medication.name.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleLarge(context)
                                    .copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (medication.dosage.trim().isNotEmpty)
                          Text(
                            "Dosage: ${medication.dosage.trim()}",
                            style: AppTextStyles.bodyMedium(
                              context,
                            ).copyWith(color: AppColors.textSecondary),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        if (patientName != null &&
                            patientName!.trim().isNotEmpty)
                          _MiniChip(
                            icon: Icons.person_outline_rounded,
                            label: patientName!.trim(),
                            background: AppColors.primary.withValues(
                              alpha: 0.10,
                            ),
                            foreground: AppColors.primary,
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
                  _MiniChip(
                    icon: Icons.inventory_2_rounded,
                    label: medication.quantity.toString(),
                  ),
                  _MiniChip(
                    icon: Icons.category_rounded,
                    label: medication.form.backendValue.toUpperCase(),
                  ),
                  if (medication.expiryDate != null)
                    _MiniChip(
                      icon: Icons.event_rounded,
                      label: "Expires ${_formatDate(medication.expiryDate!)}",
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final Color bg = background ?? AppColors.background;
    final Color fg = foreground ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                context,
              ).copyWith(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListView extends StatelessWidget {
  const _EmptyListView({this.onAdd, required this.patientsCount});

  final VoidCallback? onAdd;
  final int patientsCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(height: MediaQuery.of(context).size.height * 0.10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.secondaryBackground,
                        AppColors.cardBackground,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.softCard,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.medication_rounded,
                        size: 74,
                        color: AppColors.primary.withValues(alpha: 0.85),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 14,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  "Your cabinet is empty",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  patientsCount <= 0
                      ? "Add your first patient, then start adding their medications."
                      : "Add your first medication to start tracking doses, schedules, and refills.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium(
                    context,
                  ).copyWith(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: PrimaryButton(
                    label: "Add Medicine",
                    onPressed: onAdd,
                    leading: const Icon(Icons.add_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 300),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.br16,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.search_off_rounded,
            size: 46,
            color: AppColors.icon,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          "No matches",
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "No medications match “${query.trim()}”.",
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 300),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: AppRadius.br16,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          "Couldn't load medications",
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          error,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: 220,
          height: 52,
          child: PrimaryButton(
            label: "Try again",
            onPressed: onRetry,
            leading: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ),
      ],
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

class _FloatingAddButton extends StatelessWidget {
  const _FloatingAddButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.primaryLight, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
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
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 9),
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

class _PatientPickerSheet extends StatelessWidget {
  const _PatientPickerSheet({required this.patients});

  final List<Patient> patients;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.72;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppShadows.softCard,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            10,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    "Select patient",
                    style: AppTextStyles.titleLarge(context).copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Medications belong to a patient. Choose who this medication is for.",
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: patients.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (BuildContext context, int index) {
                    final Patient p = patients[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: AppRadius.br16,
                        onTap: () => Navigator.of(context).pop(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadius.br16,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: AppRadius.br12,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  p.initialsDisplay,
                                  style: AppTextStyles.label(context).copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      p.fullNameDisplay,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleLarge(context)
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (p.dateOfBirth != null)
                                      Text(
                                        "DOB: ${_formatDate(p.dateOfBirth!)}",
                                        style: AppTextStyles.bodyMedium(context)
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.icon,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
