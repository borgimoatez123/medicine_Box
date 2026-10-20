import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../controllers/patient_controller.dart";
import "../../controllers/schedule_controller.dart";
import "../../models/medication_model.dart";
import "../../models/patient.dart";
import "../../models/schedule_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";
import "../schedules/create_schedule_screen.dart";
import "../schedules/edit_schedule_screen.dart";

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  late final ScheduleController _scheduleController;
  late final PatientController _patientController;
  late final MedicationController _medicationController;
  late final TextEditingController _searchController;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _scheduleController = ScheduleController();
    _patientController = PatientController();
    _medicationController = MedicationController();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _patientController.loadPatients(limit: 100).ignore();
      _loadSchedules();
    });
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    _patientController.dispose();
    _medicationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    return _scheduleController.loadSchedules(page: 1, limit: 100);
  }

  List<ScheduleModel> get _filtered {
    final List<ScheduleModel> all = _scheduleController.schedules;
    if (_search.isEmpty) return all;
    return all
        .where((ScheduleModel s) {
          final String med = (s.medicationName ?? "").toLowerCase();
          final String dosage = s.dosage.toLowerCase();
          final String notes = (s.notes ?? "").toLowerCase();
          final String status = s.status.displayLabel.toLowerCase();
          return med.contains(_search) ||
              dosage.contains(_search) ||
              notes.contains(_search) ||
              status.contains(_search);
        })
        .toList(growable: false);
  }

  Future<void> _openAddSchedule() async {
    if (!_patientController.isLoading && _patientController.patients.isEmpty) {
      await _patientController.loadPatients(limit: 100);
    }
    if (!mounted) return;
    final List<Patient> patients = List<Patient>.from(
      _patientController.patients,
    );
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Add a patient and a medication before creating a schedule.",
          ),
        ),
      );
      return;
    }

    Patient pickedPatient;
    if (patients.length == 1) {
      pickedPatient = patients.first;
    } else {
      if (!mounted) return;
      final Patient? picked = await showModalBottomSheet<Patient>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext ctx) {
          return _PatientPickerSheet(patients: patients);
        },
      );
      if (picked == null || !mounted) return;
      pickedPatient = picked;
    }

    if (!mounted) return;
    String medicationId;
    MedicationModel? medication;
    List<MedicationModel> meds = <MedicationModel>[];
    try {
      final List<MedicationModel> loaded = await _medicationController
          .loadMedicationsThenReturn(
            patientId: pickedPatient.id.trim(),
            limit: 100,
          );
      meds = loaded;
    } catch (_) {
      meds = <MedicationModel>[];
    }
    if (!mounted) return;
    if (meds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This patient has no medications. Add one first then return here.",
          ),
        ),
      );
      return;
    }
    if (meds.length == 1) {
      medicationId = meds.first.id;
      medication = meds.first;
    } else {
      if (!mounted) return;
      final MedicationModel? chosen =
          await showModalBottomSheet<MedicationModel>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (BuildContext ctx) {
              return _MedicationPickerSheet(medications: meds);
            },
          );
      if (chosen == null || !mounted) return;
      medicationId = chosen.id;
      medication = chosen;
    }

    if (!mounted) return;
    final String mId = medicationId.trim();
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateScheduleScreen(
          medicationId: mId,
          medication: medication,
          patient: pickedPatient,
          patientId: pickedPatient.id.trim(),
        ),
      ),
    );
    if (created == true && mounted) {
      await _loadSchedules();
    }
  }

  Future<void> _openEditSchedule(ScheduleModel schedule) async {
    Patient? patientFor;
    try {
      patientFor = await _patientForMed(schedule.medicationId);
    } catch (_) {
      patientFor = null;
    }
    if (!mounted) return;
    final String? pid = patientFor != null ? patientFor.id.trim() : null;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditScheduleScreen(
          schedule: schedule,
          patient: patientFor,
          patientId: (pid == null || pid.isEmpty) ? null : pid,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _loadSchedules();
    }
  }

  Future<Patient?> _patientForMed(String medicationId) async {
    try {
      final MedicationModel m = await _medicationController.getMedication(
        medicationId.trim(),
      );
      final List<Patient> list = List<Patient>.from(
        _patientController.patients,
      );
      for (final Patient p in list) {
        if (p.id.trim() == m.patientId.trim()) return p;
      }
    } catch (_) {}
    return null;
  }

  Future<bool?> _confirmDelete(ScheduleModel schedule) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br20),
          title: const Text("Delete Schedule?"),
          content: const Text(
            "This will permanently remove this schedule. Reminders and alerts tied to the schedule may also be removed.",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDismiss(ScheduleModel schedule) async {
    final bool? ok = await _confirmDelete(schedule);
    if (ok != true) return false;
    try {
      await _scheduleController.deleteSchedule(schedule);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Schedule deleted.")));
      }
      return true;
    } on ScheduleControllerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scheduleController,
      builder: (BuildContext ctx, Widget? _) {
        return AnimatedBuilder(
          animation: _patientController,
          builder: (BuildContext ctx, Widget? _) {
            return _buildScaffold();
          },
        );
      },
    );
  }

  Widget _buildScaffold() {
    final ScheduleController c = _scheduleController;
    final List<ScheduleModel> items = _filtered;
    final bool loading = c.isLoading && c.schedules.isEmpty;
    final String? err = c.error;
    final int total = c.schedules.length;
    final int expiring = c.schedules.where((ScheduleModel s) {
      final DateTime? end = s.endDate;
      if (end == null) return false;
      final DateTime now = DateTime.now();
      final Duration diff = end.difference(now);
      return diff.inDays <= 30 && diff.inDays >= 0;
    }).length;
    final int inactive = c.schedules
        .where(
          (ScheduleModel s) => !s.isActive || s.status != ScheduleStatus.active,
        )
        .length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _Header(
                        total: total,
                        expiringSoon: expiring,
                        inactive: inactive,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: _SearchField(
                          controller: _searchController,
                          onClear: () => _searchController.clear(),
                        ),
                      ),
                    ),
                    if (loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: LoadingIndicator()),
                      )
                    else if (err != null && c.schedules.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorView(
                          message: err,
                          onRetry: _loadSchedules,
                        ),
                      )
                    else if (c.schedules.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyView(onAdd: _openAddSchedule),
                      )
                    else if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptySearchView(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          40,
                        ),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (BuildContext ctx, int i) {
                            final ScheduleModel s = items[i];
                            return Dismissible(
                              key: ValueKey<String>("sch-gen-${s.id}"),
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
                              confirmDismiss: (DismissDirection _) =>
                                  _confirmDismiss(s),
                              background: _DismissDeleteBackground(
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground: _DismissDeleteBackground(
                                alignment: Alignment.centerRight,
                              ),
                              child: _ScheduleCard(
                                schedule: s,
                                onTap: () => _openEditSchedule(s),
                              ),
                            );
                          },
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 260)),
                  ],
                ),
                Positioned(
                  right: AppSpacing.xl,
                  bottom: 172,
                  child: _FloatingAddButton(
                    onPressed: _openAddSchedule,
                    isLoading: _scheduleController.isCreating,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

extension _MedicationControllerX on MedicationController {
  Future<List<MedicationModel>> loadMedicationsThenReturn({
    String? patientId,
    int? limit,
  }) async {
    try {
      await loadMedications(patientId: patientId, page: 1, limit: limit);
    } catch (_) {}
    return List<MedicationModel>.from(medications);
  }
}

class _Header extends StatelessWidget {
  _Header({
    required this.total,
    required this.expiringSoon,
    required this.inactive,
  });

  final int total;
  final int expiringSoon;
  final int inactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withOpacity(0.95),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: AppRadius.br12,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.event_available_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Schedules",
                        style: AppTextStyles.headlineLarge(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Tap a schedule to edit · swipe to delete",
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(color: Colors.white.withOpacity(0.86)),
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
                    label: "Total",
                    value: total,
                    color: Colors.white,
                    bg: Colors.white.withOpacity(0.16),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatPill(
                    label: "Expiring ≤30d",
                    value: expiringSoon,
                    color: Colors.amber.shade100,
                    bg: Colors.amber.withOpacity(0.18),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatPill(
                    label: "Inactive",
                    value: inactive,
                    bg: Colors.redAccent.withOpacity(0.18),
                    color: Colors.red.shade50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final String label;
  final int value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.br16),
      child: Column(
        children: <Widget>[
          Text(
            "$value",
            style: AppTextStyles.headlineMedium(
              context,
            ).copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label(context).copyWith(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  _SearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowSoft.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext ctx, Widget? _) {
          final bool hasText = controller.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: AppRadius.br16,
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.br16,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.br16,
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              suffixIcon: hasText
                  ? InkWell(
                      borderRadius: AppRadius.br12,
                      onTap: onClear,
                      child: Icon(
                        Icons.cancel_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    )
                  : null,
              hintText: "Search schedules by medication, notes, status…",
              hintStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.cardBackground,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  _ScheduleCard({required this.schedule, required this.onTap});

  final ScheduleModel schedule;
  final VoidCallback onTap;

  static const List<String> _dayLabels = <String>[
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  @override
  Widget build(BuildContext context) {
    final String? medName = schedule.medicationName;
    final String dosage = schedule.dosage;
    final String timesLine = schedule.times.isEmpty
        ? "${schedule.timesPerDay}x / day"
        : schedule.times.join(" • ");
    final List<int> dow =
        schedule.daysOfWeek.isEmpty
              ? <int>[1, 2, 3, 4, 5, 6, 7]
              : schedule.daysOfWeek.toList()
          ..sort();
    final String daysLine = dow.length >= 7
        ? "Every day"
        : dow.map((int d) => _dayLabels[d - 1]).join(" • ");
    final String startDate = _formatDate(schedule.startDate);
    final String? endDate = schedule.endDate == null
        ? null
        : _formatDate(schedule.endDate!);
    final String dateRange = endDate == null
        ? "From $startDate"
        : "$startDate → $endDate";
    final bool active = schedule.isActive;
    final bool refill = schedule.refillReminder;
    final Color statusColor = _statusColor(schedule.status);
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.br20,
      child: InkWell(
        borderRadius: AppRadius.br20,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: AppRadius.br20,
            border: Border.all(
              color: active
                  ? AppColors.border
                  : AppColors.border.withOpacity(0.6),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.shadowSoft.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.primaryLight,
                          AppColors.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.br16,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                medName ?? "Medication Schedule",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleLarge(context)
                                    .copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: AppRadius.brMax,
                              ),
                              child: Text(
                                schedule.status.displayLabel,
                                style: AppTextStyles.label(context).copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dosage,
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (active && schedule.status == ScheduleStatus.active)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Active",
                                style: AppTextStyles.label(context).copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else ...<Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Paused / Inactive",
                                style: AppTextStyles.label(context).copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                runSpacing: 6,
                spacing: 6,
                children: <Widget>[
                  _MiniChip(
                    text: timesLine,
                    icon: Icons.schedule_rounded,
                    color: AppColors.primary,
                  ),
                  _MiniChip(
                    text: daysLine,
                    icon: Icons.date_range_rounded,
                    color: AppColors.accent,
                  ),
                  _MiniChip(
                    text: dateRange,
                    icon: Icons.event_available_rounded,
                    color: AppColors.textSecondary,
                  ),
                  if (refill)
                    _MiniChip(
                      text: "Refill reminder",
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.active:
        return AppColors.primary;
      case ScheduleStatus.paused:
        return AppColors.warning;
      case ScheduleStatus.completed:
        return AppColors.success;
      case ScheduleStatus.archived:
        return AppColors.textSecondary;
    }
  }

  static String _formatDate(DateTime d) {
    return "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
  }
}

class _MiniChip extends StatelessWidget {
  _MiniChip({required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppRadius.brMax,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  _EmptyView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Icon(
                    Icons.event_available_rounded,
                    size: 76,
                    color: AppColors.primary,
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.primaryLight,
                          AppColors.primary,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "No schedules yet",
            style: AppTextStyles.headlineMedium(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              "Create a schedule for any patient's medication here. You'll pick a patient, a medication, then set up dose times & days.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: "Add Schedule",
            onPressed: onAdd,
            leading: Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 260),
        ],
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  _EmptySearchView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 68,
            color: AppColors.textSecondary.withOpacity(0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "No schedules match your search",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try a different keyword.",
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Unable to load schedules",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: "Try again", onPressed: onRetry),
        ],
      ),
    );
  }
}

class _DismissDeleteBackground extends StatelessWidget {
  _DismissDeleteBackground({required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final bool isLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppRadius.br20,
      ),
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? AppSpacing.lg : 0,
        right: !isLeft ? AppSpacing.lg : 0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            "Delete",
            style: AppTextStyles.label(
              context,
            ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  _FloatingAddButton({required this.onPressed, required this.isLoading});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        borderRadius: AppRadius.brMax,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.brMax,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(0.16),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: AppRadius.brMax,
            onTap: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    "Add Schedule",
                    style: AppTextStyles.titleLarge(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientPickerSheet extends StatelessWidget {
  _PatientPickerSheet({required this.patients});

  final List<Patient> patients;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.only(top: 40),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.brMax,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        "Select patient",
                        style: AppTextStyles.headlineMedium(context).copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext ctx, int i) {
                      final Patient p = patients[i];
                      return Material(
                        color: AppColors.cardBackground,
                        borderRadius: AppRadius.br16,
                        child: InkWell(
                          borderRadius: AppRadius.br16,
                          onTap: () => Navigator.of(context).pop(p),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: AppRadius.br12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      p.initialsDisplay,
                                      style: AppTextStyles.titleLarge(ctx)
                                          .copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        p.fullNameDisplay,
                                        style: AppTextStyles.bodyMedium(ctx)
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
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
      ),
    );
  }
}

class _MedicationPickerSheet extends StatelessWidget {
  _MedicationPickerSheet({required this.medications});

  final List<MedicationModel> medications;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.only(top: 40),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.brMax,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        "Select medication",
                        style: AppTextStyles.headlineMedium(context).copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: medications.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext ctx, int i) {
                      final MedicationModel m = medications[i];
                      return Material(
                        color: AppColors.cardBackground,
                        borderRadius: AppRadius.br16,
                        child: InkWell(
                          borderRadius: AppRadius.br16,
                          onTap: () => Navigator.of(context).pop(m),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        AppColors.primaryLight,
                                        AppColors.primary,
                                      ],
                                    ),
                                    borderRadius: AppRadius.br12,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.medication_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        m.name,
                                        style: AppTextStyles.bodyMedium(ctx)
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        m.dosage,
                                        style: AppTextStyles.label(ctx)
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
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
      ),
    );
  }
}
