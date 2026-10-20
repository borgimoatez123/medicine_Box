import "package:flutter/material.dart";

import "../../controllers/patient_dashboard_controller.dart";
import "../../controllers/schedule_controller.dart";
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

class PatientSchedulesTab extends StatefulWidget {
  const PatientSchedulesTab({super.key, required this.controller});

  final PatientDashboardController controller;

  @override
  State<PatientSchedulesTab> createState() => _PatientSchedulesTabState();
}

class _PatientSchedulesTabState extends State<PatientSchedulesTab> {
  late final ScheduleController _scheduleController;
  late final TextEditingController _searchController;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _scheduleController = ScheduleController();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedules());
    widget.controller.addListener(_onDashboardChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDashboardChanged);
    _scheduleController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDashboardChanged() {
    if (!mounted) return;
    final Patient? p = widget.controller.patient;
    final String pid = (p?.id ?? "").trim();
    final ScheduleController c = _scheduleController;
    if (c.schedules.isEmpty && !c.isLoading && pid.isNotEmpty) {
      _loadSchedules();
    }
    setState(() {});
  }

  void _onSearchChanged() {
    setState(() => _search = _searchController.text.trim().toLowerCase());
  }

  Patient? get _patient => widget.controller.patient;
  String get _patientId =>
      (_patient?.id ?? widget.controller.patientId ?? "").trim();

  Future<void> _loadSchedules() async {
    if (_patientId.isEmpty) return;
    await _scheduleController.loadSchedules(
      patientId: _patientId,
      page: 1,
      limit: 100,
    );
  }

  List<ScheduleModel> get _filtered {
    final List<ScheduleModel> all = _scheduleController.schedules;
    if (_search.isEmpty) return all;
    return all
        .where((ScheduleModel s) {
          final String med = (s.medicationName ?? "").toLowerCase();
          final String dosage = s.dosage.toLowerCase();
          final String notes = (s.notes ?? "").toLowerCase();
          return med.contains(_search) ||
              dosage.contains(_search) ||
              notes.contains(_search);
        })
        .toList(growable: false);
  }

  Future<void> _openCreateSchedule() async {
    final Patient? p = _patient;
    final String pid = _patientId;
    if (pid.isEmpty) return;
    if (widget.controller.medications.isEmpty) {
      await widget.controller.loadMedications();
    }
    final List<dynamic> meds = widget.controller.medications;
    if (meds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Add a medication first before creating a schedule."),
        ),
      );
      return;
    }
    final dynamic firstMed = meds.first;
    final String? mid = firstMed?.id?.toString();
    if (mid == null || mid.trim().isEmpty) return;
    if (!mounted) return;
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateScheduleScreen(
          medicationId: mid.trim(),
          medication: firstMed,
          patient: p,
          patientId: pid,
        ),
      ),
    );
    if (created == true && mounted) {
      await _loadSchedules();
    }
  }

  Future<void> _openEditSchedule(ScheduleModel schedule) async {
    final Patient? p = _patient;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditScheduleScreen(
          schedule: schedule,
          patient: p,
          patientId: _patientId.isEmpty ? null : _patientId,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _loadSchedules();
    }
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
      animation: widget.controller,
      builder: (BuildContext ctx, Widget? _) {
        return AnimatedBuilder(
          animation: _scheduleController,
          builder: (BuildContext ctx, Widget? _) {
            return _buildBody();
          },
        );
      },
    );
  }

  Widget _buildBody() {
    final ScheduleController c = _scheduleController;
    final List<ScheduleModel> items = _filtered;
    final bool loading = c.isLoading && c.schedules.isEmpty;
    final String? err = c.error;
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              CustomScrollView(
                key: const PageStorageKey<String>("patient_schedules_tab"),
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  "Schedules",
                                  style: AppTextStyles.headlineMedium(context)
                                      .copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              if (c.schedules.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: AppRadius.brMax,
                                  ),
                                  child: Text(
                                    "${c.schedules.length}",
                                    style: AppTextStyles.label(context)
                                        .copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tap a schedule to edit · swipe to delete",
                            style: AppTextStyles.bodyMedium(
                              context,
                            ).copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SearchField(
                            controller: _searchController,
                            onClear: () {
                              _searchController.clear();
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
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
                      child: _ErrorView(message: err, onRetry: _loadSchedules),
                    )
                  else if (c.schedules.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyView(onAdd: _openCreateSchedule),
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
                            key: ValueKey<String>("sch-${s.id}"),
                            direction: DismissDirection.horizontal,
                            dismissThresholds: const <DismissDirection, double>{
                              DismissDirection.startToEnd: 0.45,
                              DismissDirection.endToStart: 0.45,
                            },
                            movementDuration: const Duration(milliseconds: 260),
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
                bottom: 132,
                child: _FloatingAddButton(
                  onPressed: _openCreateSchedule,
                  isLoading: _scheduleController.isCreating,
                ),
              ),
            ],
          );
        },
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
              hintText: "Search schedules by medication, notes…",
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
                  if (!active)
                    _MiniChip(
                      text: "Inactive",
                      icon: Icons.pause_circle_outline_rounded,
                      color: AppColors.error,
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
              "Create a medication first, then set up reminders and dosing times for each patient here.",
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
