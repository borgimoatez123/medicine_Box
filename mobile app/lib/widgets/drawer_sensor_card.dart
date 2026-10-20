import "package:flutter/material.dart";

import "../models/drawer_model.dart";
import "../models/medicine_box_model.dart";
import "../screens/box/drawer_assignment_screen.dart";
import "../utils/app_colors.dart";
import "../utils/app_radius.dart";
import "../utils/app_spacing.dart";

class DrawerSensorCard extends StatelessWidget {
  const DrawerSensorCard({
    super.key,
    required this.drawerIndex,
    this.temperature,
    this.humidity,
    required this.fireDetected,
    this.updatedAt,
    this.drawerId,
    this.medicineBoxId,
    this.box,
    this.drawerStatus,
    this.enabled = true,
  });

  final int drawerIndex;
  final double? temperature;
  final double? humidity;
  final bool fireDetected;
  final DateTime? updatedAt;
  final String? drawerId;
  final String? medicineBoxId;
  final MedicineBoxModel? box;
  final DrawerStatus? drawerStatus;
  final bool enabled;

  static String _formatDateTime(DateTime? t) {
    if (t == null) return "No reading yet";
    final String d = t.toLocal().toString();
    final int space = d.indexOf(" ");
    if (space < 0 || d.length < space + 6) {
      return d.length > 16 ? d.substring(0, 16) : d;
    }
    return d.substring(0, space + 6);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool fire = fireDetected;
    final Color borderColor = fire ? AppColors.error : AppColors.border;
    final Color bgColor = fire
        ? AppColors.error.withOpacity(0.08)
        : AppColors.cardBackground;

    final String? did = drawerId?.trim();
    final String? trimmedMedId = medicineBoxId?.trim();
    final String? trimmedBoxId = box?.id.trim();
    final String? mbidTemp = (trimmedMedId != null && trimmedMedId.isNotEmpty)
        ? trimmedMedId
        : trimmedBoxId;
    final String? mbid = mbidTemp != null && mbidTemp.isNotEmpty
        ? mbidTemp
        : null;
    final bool canNavigate =
        enabled &&
        (did != null && did.isNotEmpty) &&
        (mbid != null && mbid.isNotEmpty);

    final VoidCallback? onTap = canNavigate
        ? () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => DrawerAssignmentScreen(
                  drawerId: did,
                  drawerNumber: drawerIndex,
                  drawerStatus: drawerStatus ?? DrawerStatus.loaded,
                  medicineBoxId: mbid,
                  box: box,
                ),
              ),
            );
          }
        : null;

    final Widget body = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.br16,
        border: Border.all(color: borderColor, width: fire ? 1.5 : 1.0),
        boxShadow: fire
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.error.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fire
                      ? AppColors.error.withOpacity(0.18)
                      : scheme.primary.withOpacity(0.12),
                  borderRadius: AppRadius.br12,
                  border: Border.all(
                    color: fire
                        ? AppColors.error.withOpacity(0.5)
                        : scheme.primary.withOpacity(0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: fire
                    ? Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.error,
                        size: 20,
                      )
                    : Text(
                        "#$drawerIndex",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "Drawer $drawerIndex",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (canNavigate) ...<Widget>[
                _statusChip(fire: fire),
                SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  size: 20,
                ),
              ] else
                _statusChip(fire: fire),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          if (fire)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: AppRadius.br12,
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Fire detected in this drawer. Please check your medicine box immediately.",
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: _SensorReadingTile(
                  icon: Icons.thermostat_rounded,
                  label: "Temperature",
                  value: temperature == null
                      ? "No reading yet"
                      : "${temperature!.toStringAsFixed(1)} \u00B0C",
                  isNull: temperature == null,
                  accent: temperature != null && temperature! >= 40
                      ? AppColors.warning
                      : null,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SensorReadingTile(
                  icon: Icons.water_drop_rounded,
                  label: "Humidity",
                  value: humidity == null
                      ? "No reading yet"
                      : "${humidity!.toStringAsFixed(1)} %",
                  isNull: humidity == null,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Last update: ${_formatDateTime(updatedAt)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: AppRadius.br16, onTap: onTap, child: body),
    );
  }

  Widget _statusChip({required bool fire}) {
    if (fire) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.br999,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              "FIRE DETECTED",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: AppRadius.br999,
      ),
      child: Text(
        "Normal",
        style: TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _SensorReadingTile extends StatelessWidget {
  const _SensorReadingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isNull,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isNull;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color valueColor = isNull
        ? AppColors.textSecondary
        : (accent ?? AppColors.textPrimary);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isNull ? AppColors.hintText : (accent ?? AppColors.icon),
                size: 15,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
