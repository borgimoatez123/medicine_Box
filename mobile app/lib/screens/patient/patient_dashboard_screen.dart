import "package:flutter/material.dart";

import "../../controllers/patient_dashboard_controller.dart";
import "../../models/medication_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_shadows.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";

class PatientDashboardView extends StatelessWidget {
  const PatientDashboardView({super.key, required this.controller});

  final PatientDashboardController controller;

  Future<void> _refresh() async {
    await controller.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        if (controller.patientLoading && controller.patient == null) {
          return const SafeArea(
            top: false,
            child: Center(child: LoadingIndicator()),
          );
        }
        final String? error = controller.patientError;
        if (error != null && controller.patient == null) {
          return _ErrorView(
            error: error,
            onRetry: () => controller.loadAll(forceRefresh: true),
          );
        }
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth > 560
                  ? 560
                  : constraints.maxWidth;
              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xxxl + 80,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        children: <Widget>[
                          _WeekCalendar(controller: controller),
                          const SizedBox(height: AppSpacing.lg),
                          _DailyProgress(controller: controller),
                          const SizedBox(height: AppSpacing.xl),
                          _TodayMedicationsHeader(controller: controller),
                          const SizedBox(height: AppSpacing.sm),
                          _TodayMedicationsList(controller: controller),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.controller});

  final PatientDashboardController controller;

  static const List<String> _weekdayLabels = <String>[
    "MON",
    "TUE",
    "WED",
    "THU",
    "FRI",
    "SAT",
    "SUN",
  ];

  @override
  Widget build(BuildContext context) {
    final List<DateTime> days = controller.weekDays;
    final DateTime today = controller.today;
    final DateTime selected = controller.selectedDay;
    final bool isThisWeek = days.first.isAtSameMomentAs(
      DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: today.weekday - DateTime.monday)),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                onTap: controller.goToPreviousWeek,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: AppColors.icon,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _weekRangeLabel(days.first, days.last),
                  style: AppTextStyles.titleLarge(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              InkWell(
                onTap: isThisWeek ? null : controller.goToNextWeek,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: isThisWeek ? AppColors.hintText : AppColors.icon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List<Widget>.generate(days.length, (int i) {
              final DateTime day = days[i];
              final bool isSelected =
                  day.year == selected.year &&
                  day.month == selected.month &&
                  day.day == selected.day;
              final bool isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == days.length - 1 ? 0 : AppSpacing.xxs,
                  ),
                  child: _DayCell(
                    weekday: _weekdayLabels[i],
                    day: day.day,
                    isSelected: isSelected,
                    isToday: isToday,
                    onTap: () => controller.setSelectedDay(day),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _weekRangeLabel(DateTime start, DateTime end) {
    const List<String> months = <String>[
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    if (start.month == end.month) {
      return "${months[start.month - 1]} ${start.day} - ${end.day}, ${start.year}";
    }
    return "${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}";
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekday,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = isSelected ? AppColors.primary : Colors.transparent;
    final Color borderColor = isSelected
        ? AppColors.primary
        : isToday
        ? AppColors.primary.withValues(alpha: 0.5)
        : Colors.transparent;
    final Color textColor = isSelected
        ? Colors.white
        : isToday
        ? AppColors.primary
        : AppColors.textPrimary;
    final Color weekdayColor = isSelected
        ? Colors.white70
        : isToday
        ? AppColors.primary
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 76,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              weekday,
              style: AppTextStyles.label(context).copyWith(
                color: weekdayColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "$day",
              style: AppTextStyles.titleLarge(context).copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyProgress extends StatelessWidget {
  const _DailyProgress({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final int taken = controller.takenToday;
    final int total = controller.totalScheduledToday;
    final double progress = controller.progressToday;
    final DateTime selected = controller.selectedDay;
    final DateTime today = controller.today;
    final bool isToday =
        selected.year == today.year &&
        selected.month == today.month &&
        selected.day == today.day;
    final String label = isToday ? "Today" : _formatDayLabel(selected);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: total > 0 ? progress : 0.0,
                    strokeWidth: 14,
                    backgroundColor: AppColors.secondaryBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppColors.success : AppColors.primary,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          RichText(
                            text: TextSpan(
                              style: AppTextStyles.headlineMedium(context),
                              children: <InlineSpan>[
                                TextSpan(
                                  text: "$taken",
                                  style: TextStyle(
                                    color: progress >= 1.0
                                        ? AppColors.success
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 42,
                                    height: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: " / $total",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            total == 0
                                ? "No meds scheduled"
                                : "${(progress * 100).toStringAsFixed(0)}% complete",
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _StatusChip(
                label: "Taken",
                count: taken,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(
                label: "Pending",
                count: controller.pendingToday,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(
                label: "Missed",
                count: controller.missedToday,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDayLabel(DateTime d) {
    const List<String> weekdays = <String>[
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    const List<String> months = <String>[
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}";
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            "$label $count",
            style: AppTextStyles.label(
              context,
            ).copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TodayMedicationsHeader extends StatelessWidget {
  const _TodayMedicationsHeader({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final int count = controller.totalScheduledToday;
    final DateTime selected = controller.selectedDay;
    final DateTime today = controller.today;
    final bool isToday =
        selected.year == today.year &&
        selected.month == today.month &&
        selected.day == today.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              isToday ? "Today's Medications" : "Scheduled Medications",
              style: AppTextStyles.titleLarge(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "$count ${count == 1 ? "med" : "meds"}",
              style: AppTextStyles.label(
                context,
              ).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMedicationsList extends StatelessWidget {
  const _TodayMedicationsList({required this.controller});

  final PatientDashboardController controller;

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
      return _InlineError(
        error: error,
        onRetry: () => controller.loadMedications(),
      );
    }
    final List<DailyMedicationSlot> slots = controller.todaySlots;
    if (slots.isEmpty) {
      return const _EmptyMeds();
    }
    return Column(
      children: List<Widget>.generate(slots.length, (int i) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: i == slots.length - 1 ? 0 : AppSpacing.sm,
          ),
          child: _DailyMedicationCard(slot: slots[i]),
        );
      }),
    );
  }
}

class _DailyMedicationCard extends StatelessWidget {
  const _DailyMedicationCard({required this.slot});

  final DailyMedicationSlot slot;

  @override
  Widget build(BuildContext context) {
    final MedicationModel m = slot.medication;
    final String name = m.name.trim().isEmpty
        ? "Unnamed medication"
        : m.name.trim();
    final String? dosage = m.dosage;
    final String time = slot.displayTime;
    final MedicationSlotStatus status = slot.status;

    final Color statusColor;
    final IconData statusIcon;
    switch (status) {
      case MedicationSlotStatus.taken:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case MedicationSlotStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = Icons.pending_actions_rounded;
        break;
      case MedicationSlotStatus.missed:
        statusColor = AppColors.error;
        statusIcon = Icons.error_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadius.br12,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge(context).copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(statusIcon, size: 22, color: statusColor),
                  ],
                ),
                if (dosage != null && dosage.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    dosage.trim(),
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              time,
              style: AppTextStyles.label(context).copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMeds extends StatelessWidget {
  const _EmptyMeds();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadius.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 36,
              color: AppColors.icon,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "No medications scheduled",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "There are no medications for the selected day.",
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Unable to load medications",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error,
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 160,
            child: PrimaryButton(label: "Retry", onPressed: onRetry),
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
                  "Unable to load dashboard.",
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
