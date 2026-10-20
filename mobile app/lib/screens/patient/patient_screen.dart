import "package:flutter/material.dart";

import "../../controllers/patient_controller.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/appbars/custom_app_bar.dart";
import "../../widgets/empty_patient_widget.dart";
import "../../widgets/loading/loading_indicator.dart";
import "../../widgets/patient_card.dart";
import "add_patient_screen.dart";
import "patient_dashboard_shell.dart";

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  late final PatientController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _nextPageRequested = false;

  @override
  void initState() {
    super.initState();
    _controller = PatientController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadPatients();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final double current = _scrollController.position.pixels;
    if (max - current <= 220) {
      _maybeLoadNextPage();
    }
  }

  Future<void> _maybeLoadNextPage() async {
    if (_nextPageRequested) return;
    if (_controller.isLoading) return;
    final int? tp = _controller.totalPages;
    if (tp != null && _controller.currentPage >= tp) return;
    _nextPageRequested = true;
    try {
      await _controller.loadNextPage();
    } catch (_) {
    } finally {
      _nextPageRequested = false;
    }
  }

  Future<void> _openAddPatient() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AddPatientScreen()),
    );
    if (created == true) {
      await _controller.refresh();
    }
  }

  void _openDetails(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDashboardScreen(patient: patient),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Patient patient) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
          backgroundColor: AppColors.cardBackground,
          title: Text(
            "Delete Patient?",
            style: AppTextStyles.titleLarge(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          content: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.textSecondary, height: 1.45),
              children: <TextSpan>[
                const TextSpan(
                  text: "Are you sure you want to permanently delete ",
                ),
                TextSpan(
                  text: patient.fullName.trim().isEmpty
                      ? "this patient"
                      : patient.fullName.trim(),
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: "?\n\n"),
                const TextSpan(
                  text: "This action cannot be undone.",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                textStyle: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool?> _confirmDismiss(Patient patient) async {
    final bool confirmed = await _showDeleteConfirmation(patient);
    if (!confirmed) return false;
    try {
      await _controller.deletePatient(patient);
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
                      "Patient deleted successfully.",
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
        final String message = e is PatientControllerException
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
                      message.isEmpty ? "Failed to delete patient." : message,
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
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final bool showFab =
            !_controller.isLoading &&
            _controller.error == null &&
            _controller.patients.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CustomAppBar(title: "Patients"),
          floatingActionButton: showFab
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: _openAddPatient,
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                  ),
                )
              : null,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildBody(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(
        key: ValueKey<String>("loading"),
        child: LoadingIndicator(size: 36, strokeWidth: 3),
      );
    }

    if (_controller.error != null) {
      return _ErrorState(
        key: const ValueKey<String>("error"),
        message: _controller.error!,
        onRetry: _controller.loadPatients,
      );
    }

    if (_controller.patients.isEmpty) {
      return EmptyPatientWidget(
        key: const ValueKey<String>("empty"),
        onAddPatient: _openAddPatient,
      );
    }

    return RefreshIndicator(
      key: const ValueKey<String>("list"),
      onRefresh: _controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxxl + 60,
        ),
        itemCount: _controller.patients.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          if (index == _controller.patients.length) {
            return _PaginationFooter(controller: _controller);
          }
          final Patient patient = _controller.patients[index];
          final String keyId = patient.id.trim().isEmpty
              ? "patient-$index"
              : patient.id;
          return Dismissible(
            key: ValueKey<String>(keyId),
            direction: DismissDirection.horizontal,
            dismissThresholds: const <DismissDirection, double>{
              DismissDirection.startToEnd: 0.45,
              DismissDirection.endToStart: 0.45,
            },
            movementDuration: const Duration(milliseconds: 260),
            resizeDuration: const Duration(milliseconds: 260),
            confirmDismiss: (_) => _confirmDismiss(patient),
            background: const _DismissDeleteBackground(
              alignment: Alignment.centerLeft,
            ),
            secondaryBackground: const _DismissDeleteBackground(
              alignment: Alignment.centerRight,
            ),
            child: PatientCard(
              patient: patient,
              onTap: () => _openDetails(patient),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Please check your connection and try again.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text("Retry"),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.controller});

  final PatientController controller;

  @override
  Widget build(BuildContext context) {
    final PatientPaginationMeta? meta = controller.meta;
    final int shown = controller.patients.length;
    final int? total = meta?.total;
    final int? tp = meta?.totalPages;
    final int cp = controller.currentPage;
    final bool loadingMore = controller.isLoading && cp > 1;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LoadingIndicator(size: 22, strokeWidth: 2.2),
            ),
          if (meta != null)
            Text(
              total == null
                  ? "Page $cp"
                  : "Showing $shown of $total total patient${total == 1 ? "" : "s"}  •  Page $cp of $tp",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
        ],
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
              "Delete Patient",
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
