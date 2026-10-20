import "package:flutter/material.dart";

import "../../controllers/patient_details_controller.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/curved_bottom_nav_bar.dart";
import "patient_alerts_screen.dart";
import "patient_info_screen.dart";
import "patient_medications_screen.dart";
import "update_patient_screen.dart";

class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  late final PatientDetailsController _controller;
  late final List<Widget> _tabs;

  static const double _navBarTotalHeight = 116;

  static const List<CurvedNavItem> _items = <CurvedNavItem>[
    CurvedNavItem(icon: Icons.person_rounded, label: "Info"),
    CurvedNavItem(icon: Icons.medication_rounded, label: "Meds"),
    CurvedNavItem(icon: Icons.notifications_active_rounded, label: "Alerts"),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PatientDetailsController(
      initialPatient: widget.patient,
      patientId: widget.patient.id.trim().isEmpty ? null : widget.patient.id,
    );
    _tabs = <Widget>[
      PatientInfoScreen(controller: _controller),
      PatientMedicationsScreen(controller: _controller),
      PatientAlertsScreen(controller: _controller),
    ];
    // Kick off data loading: patient (force refresh to ensure fresh data) and downstream tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadAll(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEdit() async {
    final Patient patient = _controller.patient ?? widget.patient;
    final Patient? result = await Navigator.of(context).push<Patient>(
      MaterialPageRoute<Patient>(
        builder: (_) => UpdatePatientScreen(patient: patient),
      ),
    );
    if (result != null && mounted) {
      _controller.setPatient(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: _BackButton(onPressed: () => Navigator.of(context).maybePop()),
        ),
        title: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final String name =
                _controller.patient?.fullName.trim() ??
                widget.patient.fullName.trim();
            return Text(
              name.isEmpty ? "Patient Details" : name,
              style: AppTextStyles.titleLarge(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _EditButton(onPressed: _openEdit),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: _navBarTotalHeight),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  child: IndexedStack(
                    key: ValueKey<int>(_controller.currentTab),
                    index: _controller.currentTab,
                    children: _tabs,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CurvedBottomNavBar(
                  currentIndex: _controller.currentTab,
                  onTap: (int i) => _controller.setTab(i),
                  items: _items,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.icon,
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
      child: InkWell(
        borderRadius: AppRadius.br12,
        onTap: onPressed,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(Icons.edit_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
