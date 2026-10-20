import "package:flutter/material.dart";

import "../../controllers/patient_dashboard_controller.dart";
import "../../models/alert_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_shadows.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/loading/loading_indicator.dart";

class PatientAlertsTab extends StatelessWidget {
  const PatientAlertsTab({super.key, required this.controller});

  final PatientDashboardController controller;

  Future<void> _refresh() async {
    if (controller.patient == null) {
      await controller.loadPatient();
    }
    await controller.loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double maxWidth = constraints.maxWidth > 560
                    ? 560
                    : constraints.maxWidth;
                return SingleChildScrollView(
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
                      child: _Body(controller: controller),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final PatientDashboardController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.alertsLoading && controller.alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: LoadingIndicator()),
      );
    }
    final String? error = controller.alertsError;
    if (error != null && controller.alerts.isEmpty) {
      return _ErrorListView(
        error: error,
        onRetry: () => controller.loadAlerts(),
      );
    }
    final List<AlertModel> alerts = controller.alerts;
    if (alerts.isEmpty) {
      return const _EmptyListView();
    }
    final List<AlertModel> sorted = List<AlertModel>.from(alerts)
      ..sort((AlertModel a, AlertModel b) {
        final DateTime? da = a.date ?? a.createdAt;
        final DateTime? db = b.date ?? b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    return Column(
      children: List<Widget>.generate(sorted.length, (int i) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: i == sorted.length - 1 ? 0 : AppSpacing.md,
          ),
          child: _AlertCard(alert: sorted[i]),
        );
      }),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final AlertModel alert;

  @override
  Widget build(BuildContext context) {
    final Color? priorityColor = alert.priorityColor;
    final AlertStatus status = alert.alertStatus;
    final bool isUnread =
        status == AlertStatus.unread || status == AlertStatus.pending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(
          color: isUnread && priorityColor != null
              ? priorityColor.withValues(alpha: 0.28)
              : AppColors.border,
        ),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (priorityColor ?? AppColors.secondaryBackground)
                  .withValues(alpha: 0.14),
              borderRadius: AppRadius.br12,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: priorityColor ?? AppColors.primary,
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
                    Expanded(
                      child: Text(
                        alert.title.trim().isEmpty
                            ? "Alert"
                            : alert.title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge(context).copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (priorityColor != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      _PriorityDot(color: priorityColor),
                    ],
                  ],
                ),
                if (alert.description != null &&
                    alert.description!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    alert.description!.trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  runSpacing: AppSpacing.xxs,
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    if (alert.date != null)
                      _MetaChip(
                        icon: Icons.calendar_month_rounded,
                        label: _formatDate(alert.date!),
                      ),
                    if (alert.time != null && alert.time!.trim().isNotEmpty)
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: alert.time!.trim(),
                      )
                    else if (alert.date != null)
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: _formatTime(alert.date!),
                      ),
                    if (alert.status != null && alert.status!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isUnread
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          alert.status!.trim(),
                          style: AppTextStyles.label(context).copyWith(
                            fontSize: 12,
                            color: isUnread
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (alert.priority != null &&
                        alert.priority!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (priorityColor ?? AppColors.border).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (priorityColor ?? AppColors.border)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          alert.priority!.trim(),
                          style: AppTextStyles.label(context).copyWith(
                            fontSize: 12,
                            color: priorityColor ?? AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
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
  const _EmptyListView();

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
              Icons.notifications_active_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "No alerts found",
            style: AppTextStyles.titleLarge(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Alerts and reminders for this patient will appear here.",
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
              "Unable to load alerts.",
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

String _formatDate(DateTime date) {
  final String day = date.day.toString().padLeft(2, "0");
  final String month = date.month.toString().padLeft(2, "0");
  final String year = date.year.toString();
  return "$year-$month-$day";
}

String _formatTime(DateTime date) {
  final String h = date.hour.toString().padLeft(2, "0");
  final String m = date.minute.toString().padLeft(2, "0");
  return "$h:$m";
}
