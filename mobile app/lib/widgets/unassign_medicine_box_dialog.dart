import "package:flutter/material.dart";

import "../controllers/smart_box_controller.dart";
import "../models/medicine_box_model.dart";
import "../utils/app_colors.dart";
import "../utils/app_radius.dart";
import "../utils/app_spacing.dart";

class UnassignMedicineBoxDialog extends StatefulWidget {
  const UnassignMedicineBoxDialog({
    super.key,
    required this.box,
    required this.controller,
  });

  final MedicineBoxModel box;
  final SmartBoxController controller;

  @override
  State<UnassignMedicineBoxDialog> createState() =>
      _UnassignMedicineBoxDialogState();
}

class _UnassignMedicineBoxDialogState extends State<UnassignMedicineBoxDialog> {
  static const String _confirmText = "UNASSIGN";

  final TextEditingController _confirmController = TextEditingController();
  String _error = "";
  bool _submitting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_submitting) return false;
    return _confirmController.text.trim() == _confirmText;
  }

  Future<void> _submit() async {
    if (!_canConfirm) return;
    final String id = widget.box.id.trim();
    if (id.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = "";
    });
    try {
      await widget.controller.unassignBox(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicine box unassigned successfully.")),
      );
      Navigator.of(context).pop(true);
    } on SmartBoxControllerException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              "Unable to unassign the medicine box. No changes were applied.";
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MedicineBoxModel b = widget.box;
    final String deviceId = b.deviceId.trim().isEmpty ? "—" : b.deviceId.trim();
    final String statusLabel = b.status.displayLabel;
    final int drawers = b.numberOfDrawers > 0 ? b.numberOfDrawers : 0;
    return PopScope<Object?>(
      canPop: !_submitting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br20,
          side: BorderSide(
            color: AppColors.warning.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.warning.withOpacity(0.35)),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Unassign Medicine Box?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                "Warning: You are about to unassign this medicine box.",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadius.br14,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _InfoRow(
                      label: "Medicine Box",
                      value: b.name.trim().isEmpty
                          ? "Unnamed medicine box"
                          : b.name.trim(),
                      isStrong: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(label: "Device ID", value: deviceId),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: "Drawers",
                      value: "$drawers drawer${drawers == 1 ? "" : "s"}",
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: "Status",
                      value: statusLabel,
                      statusColor: _statusColor(b.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "This action will:",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Consequence(
                text: "Remove this user's ownership of the medicine box.",
              ),
              _Consequence(
                text: "Delete ALL drawers configured inside this medicine box.",
              ),
              _Consequence(
                text: "Delete ALL medication-to-drawer assignments.",
              ),
              _Consequence(
                text:
                    "Reset the medicine box to READY and make it available for activation again.",
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: AppRadius.br14,
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            "Your patient records and medication records will NOT be deleted.",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        "Medication records and patient data are preserved, "
                        "but the medication assignments inside this physical box will be removed.",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Type UNASSIGN to confirm:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _confirmController,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: "UNASSIGN",
                  hintStyle: TextStyle(
                    color: AppColors.hintText,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.secondaryBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.br12,
                    borderSide: BorderSide(
                      color: _canConfirm ? AppColors.warning : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.br12,
                    borderSide: BorderSide(
                      color: AppColors.warning,
                      width: 1.5,
                    ),
                  ),
                  border: OutlineInputBorder(borderRadius: AppRadius.br12),
                ),
              ),
              if (_error.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: AppRadius.br12,
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _error,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          const SizedBox(width: AppSpacing.xs),
          Builder(
            builder: (BuildContext c) {
              final bool canConfirm = _canConfirm;
              return ElevatedButton.icon(
                onPressed: canConfirm ? _submit : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: canConfirm
                      ? AppColors.error
                      : AppColors.error.withOpacity(0.25),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withOpacity(0.85),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                icon: _submitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.9),
                          ),
                        ),
                      )
                    : const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(
                  _submitting ? "Unassigning…" : "Yes, Unassign Medicine Box",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 0.1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(MedicineBoxStatus s) {
    switch (s) {
      case MedicineBoxStatus.active:
        return AppColors.success;
      case MedicineBoxStatus.ready:
        return AppColors.textSecondary;
      case MedicineBoxStatus.maintenance:
        return AppColors.warning;
      case MedicineBoxStatus.unknown:
        return AppColors.textSecondary;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isStrong = false,
    this.statusColor,
  });

  final String label;
  final String value;
  final bool isStrong;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: statusColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor!.withOpacity(0.12),
                    borderRadius: AppRadius.br999,
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                )
              : Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Consequence extends StatelessWidget {
  const _Consequence({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.close_rounded, size: 15, color: AppColors.error),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
