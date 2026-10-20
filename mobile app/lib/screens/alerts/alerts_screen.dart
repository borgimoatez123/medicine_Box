import "package:flutter/material.dart";

import "../../controllers/alerts_controller.dart";
import "../../models/medication_event_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../widgets/loading/loading_indicator.dart";

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AlertsController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadEvents();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    await _controller.loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, _) {
            final bool isLoading = _controller.isLoading && _controller.events.isEmpty;
            final bool isError = _controller.error != null && _controller.events.isEmpty;
            final bool isEmpty = _controller.isEmpty;

            return RefreshIndicator(
              onRefresh: () => _controller.refresh(),
              color: Theme.of(context).colorScheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "Medication Alerts",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            "Medication activity and alerts for your patients.",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_controller.events.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: _SummaryCard(events: _controller.sortedEvents),
                      ),
                    ),
                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: LoadingIndicator(size: 36)),
                    )
                  else if (isError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        message: _controller.error!,
                        onRetry: _retry,
                      ),
                    )
                  else if (isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else ...<Widget>[
                    _EventSection(
                      title: "Active Alerts",
                      events: _controller.sortedEvents
                          .where((MedicationEventModel e) => e.isAlert)
                          .toList(),
                      nameResolver: _controller.medicationName,
                      emptyLabel: "No active alerts.",
                      isHistory: false,
                    ),
                    _EventSection(
                      title: "Medication History",
                      events: _controller.sortedEvents
                          .where((MedicationEventModel e) => !e.isAlert)
                          .toList(),
                      nameResolver: _controller.medicationName,
                      emptyLabel: "No medication history available yet.",
                      isHistory: true,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.events});

  final List<MedicationEventModel> events;

  @override
  Widget build(BuildContext context) {
    final int taken = events.where((MedicationEventModel e) => e.isTaken).length;
    final int missed =
        events.where((MedicationEventModel e) => e.isMissed).length;
    final int pending = events
        .where((MedicationEventModel e) =>
            e.eventStatus == MedicationEventStatus.pending)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _SummaryStat(
            label: "Taken",
            value: taken,
            color: AppColors.success,
            icon: Icons.check_circle_outline_rounded,
          ),
          _SummaryStat(
            label: "Pending",
            value: pending,
            color: AppColors.info,
            icon: Icons.schedule_rounded,
          ),
          _SummaryStat(
            label: "Missed",
            value: missed,
            color: AppColors.error,
            icon: Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.events,
    required this.nameResolver,
    required this.emptyLabel,
    required this.isHistory,
  });

  final String title;
  final List<MedicationEventModel> events;
  final String Function(String?) nameResolver;
  final String emptyLabel;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  emptyLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.hintText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final MedicationEventModel event = events[index];
              return _EventCard(
                event: event,
                medicationName: nameResolver(event.medicationId),
                isHistory: isHistory,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.medicationName,
    required this.isHistory,
  });

  final MedicationEventModel event;
  final String medicationName;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final MedicationEventStatus status = event.eventStatus;
    final Color statusColor = status.color ?? AppColors.hintText;
    final bool isTaken = event.isTaken;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isTaken
            ? AppColors.success.withOpacity(0.05)
            : status.isAlert
                ? AppColors.error.withOpacity(0.05)
                : AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(
          color: isTaken
              ? AppColors.success.withOpacity(0.25)
              : status.isAlert
                  ? AppColors.error.withOpacity(0.25)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: AppRadius.br12,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isTaken
                      ? Icons.check_circle_outline_rounded
                      : status.isAlert
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      medicationName.isEmpty ? "Medication" : medicationName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: AppRadius.br999,
                ),
                child: Text(
                  event.status.isEmpty ? "—" : event.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _EventDetailRow(
            icon: Icons.schedule_rounded,
            label: "Scheduled",
            value: _formatDateTime(event.scheduledAt),
          ),
          if (event.completedAt != null)
            _EventDetailRow(
              icon: Icons.task_alt_rounded,
              label: "Completed",
              value: _formatDateTime(event.completedAt),
            ),
          if (event.quantityTaken != null)
            _EventDetailRow(
              icon: Icons.medication_rounded,
              label: "Quantity taken",
              value: "${event.quantityTaken}",
            ),
          if (event.quantityAfter != null)
            _EventDetailRow(
              icon: Icons.inventory_2_rounded,
              label: "Remaining",
              value: "${event.quantityAfter}",
            ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return "—";
    final DateTime local = dt.toLocal();
    final String y = local.year.toString().padLeft(4, "0");
    final String m = local.month.toString().padLeft(2, "0");
    final String d = local.day.toString().padLeft(2, "0");
    final String h = local.hour.toString().padLeft(2, "0");
    final String min = local.minute.toString().padLeft(2, "0");
    return "$y-$m-$d  $h:$min";
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_note_rounded,
              size: 56,
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "No medication events available yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "When medication events are recorded, they will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                "Retry",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
