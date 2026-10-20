import "package:flutter/material.dart";

import "../../controllers/drawer_medication_controller.dart";
import "../../controllers/medication_controller.dart";
import "../../controllers/patient_controller.dart";
import "../../controllers/smart_box_controller.dart";
import "../../models/drawer_model.dart";
import "../../models/drawer_medication_model.dart";
import "../../models/medication_model.dart";
import "../../models/medicine_box_model.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../widgets/buttons/primary_button.dart";

class AssignMedicationToDrawerScreen extends StatefulWidget {
  const AssignMedicationToDrawerScreen({
    super.key,
    required this.medicationId,
    this.medication,
    this.patient,
    this.patientId,
  });

  final String medicationId;
  final MedicationModel? medication;
  final Patient? patient;
  final String? patientId;

  @override
  State<AssignMedicationToDrawerScreen> createState() =>
      _AssignMedicationToDrawerScreenState();
}

class _AssignMedicationToDrawerScreenState
    extends State<AssignMedicationToDrawerScreen> {
  late final SmartBoxController _boxController;
  late final DrawerMedicationController _dmController;
  late final MedicationController _medicationController;
  late final PatientController _patientController;

  DrawerModel? _selectedDrawer;
  String? _resolvedPatientName;
  MedicationModel? _resolvedMedication;

  bool _loadingBoxes = true;
  bool _loadingDrawers = false;
  bool _loadingAssignments = false;
  bool _loadingMeta = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boxController = SmartBoxController();
    _dmController = DrawerMedicationController();
    _medicationController = MedicationController();
    _patientController = PatientController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initialize();
    });
  }

  @override
  void dispose() {
    _boxController.dispose();
    _dmController.dispose();
    _medicationController.dispose();
    _patientController.dispose();
    super.dispose();
  }

  bool get _anyLoading =>
      _loadingBoxes || _loadingDrawers || _loadingAssignments || _loadingMeta;

  Future<void> _initialize() async {
    setState(() {
      _loadingBoxes = true;
      _loadingDrawers = false;
      _loadingAssignments = false;
      _loadingMeta = false;
      _error = null;
      _selectedDrawer = null;
      _resolvedMedication = widget.medication;
      _resolvedPatientName = widget.patient?.fullNameDisplay;
    });
    try {
      await _boxController.loadBoxes();
      if (!mounted) return;
      setState(() {
        _loadingBoxes = false;
        _loadingDrawers = true;
        _loadingAssignments = true;
        _loadingMeta = true;
      });

      final List<MedicineBoxModel> boxes = _boxController.boxes;
      final Future<void> drawersFuture = Future.wait(
        boxes.map<Future<void>>((MedicineBoxModel b) async {
          if (b.id.trim().isEmpty) return;
          try {
            await _boxController.loadDrawersForBox(b.id);
          } catch (_) {
            // individual box drawer load failures collected as empty; error surfaced via global error if user has no drawers anywhere
          }
        }),
        eagerError: false,
      );

      final Future<void> assignmentsFuture = () async {
        try {
          await _dmController.loadAssignments();
        } finally {
          if (mounted) {
            setState(() => _loadingAssignments = false);
          }
        }
      }();

      final Future<void> metaFuture = () async {
        try {
          await _ensureMedicationAndPatient();
        } finally {
          if (mounted) {
            setState(() => _loadingMeta = false);
          }
        }
      }();

      await Future.wait(<Future<void>>[
        drawersFuture,
        assignmentsFuture,
        metaFuture,
      ]);
      _dmController.boxForDrawerResolver = (String drawerId) {
        final DrawerModel? d = _boxController.drawerById(drawerId);
        if (d == null) return null;
        return _boxController.findById(d.medicineBoxId);
      };
      if (!mounted) return;
      setState(() {
        _loadingDrawers = false;
        _loadingAssignments = false;
        _loadingMeta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loadingBoxes = false;
        _loadingDrawers = false;
        _loadingAssignments = false;
        _loadingMeta = false;
      });
    }
  }

  String _friendlyError(Object e) {
    if (e is SmartBoxControllerException) return e.message;
    if (e is DrawerMedicationControllerException) return e.message;
    if (e is MedicationControllerException) return e.message;
    if (e is PatientControllerException) return e.message;
    final String s = e.toString();
    if (s.toLowerCase().contains("401")) return "Authentication failure.";
    if (s.toLowerCase().contains("409")) {
      return "This drawer or medication is already assigned.";
    }
    if (s.isEmpty) return "Unable to load.";
    return s;
  }

  Future<void> _ensureMedicationAndPatient() async {
    MedicationModel? med = _resolvedMedication;
    final String medId = widget.medicationId.trim();
    if (med == null || med.id.trim() != medId) {
      final MedicationModel? cached = _medicationController.findById(medId);
      if (cached != null && cached.id.trim() == medId) {
        med = cached;
      } else {
        try {
          med = await _medicationController.getMedication(medId);
        } catch (_) {
          // medication detail load failure shouldn't block screen; fall back to passed widget.medication
        }
      }
    }
    if (!mounted) return;
    setState(() {
      if (med != null) _resolvedMedication = med;
    });

    if ((widget.patient?.fullNameDisplay ?? "").trim().isNotEmpty) {
      return;
    }
    String? pId = widget.patientId?.trim();
    pId ??= widget.patient?.id.trim();
    pId ??= med?.patientId.trim();
    if (pId == null || pId.isEmpty) return;
    final List<Patient> all = _patientController.patients;
    final int idx = all.indexWhere((Patient p) => p.id.trim() == pId);
    if (idx >= 0) {
      if (!mounted) return;
      setState(() {
        _resolvedPatientName = all[idx].fullNameDisplay;
      });
      return;
    }
    try {
      await _patientController.loadPatients(limit: 200);
      if (!mounted) return;
      final int i2 = _patientController.patients.indexWhere(
        (Patient p) => p.id.trim() == pId,
      );
      if (i2 >= 0) {
        setState(() {
          _resolvedPatientName =
              _patientController.patients[i2].fullNameDisplay;
        });
        return;
      }
      final Patient? fetched = await _patientController.getById(pId);
      if (mounted && fetched != null) {
        setState(() {
          _resolvedPatientName = fetched.fullNameDisplay;
        });
      }
    } catch (_) {
      // patient detail missing is non-fatal; screen uses patientId badge when name is absent
    }
  }

  Set<String> get _assignedDrawerIds => _dmController.assignments
      .map((DrawerMedicationModel a) => a.drawerId.trim())
      .where((String s) => s.isNotEmpty)
      .toSet();

  Set<String> get _assignedMedicationIds => _dmController.assignments
      .map((DrawerMedicationModel a) => a.medicationId.trim())
      .where((String s) => s.isNotEmpty)
      .toSet();

  DrawerMedicationModel? assignmentForDrawer(String drawerId) {
    return _dmController.findByDrawerId(drawerId);
  }

  MedicationModel? medicationForId(String id) {
    return _medicationController.findById(id);
  }

  bool get _hasAnyBoxes => _boxController.boxes.isNotEmpty;

  bool get _hasAnyDrawersAnywhere {
    for (final MedicineBoxModel b in _boxController.boxes) {
      if (_boxController.drawersForBox(b.id).isNotEmpty) return true;
    }
    return false;
  }

  List<DrawerModel> availableDrawersForBox(MedicineBoxModel box) {
    final Set<String> assigned = _assignedDrawerIds;
    final bool medAssignedElsewhere = _assignedMedicationIds.contains(
      widget.medicationId.trim(),
    );
    final List<DrawerModel> drawers = _boxController.drawersForBox(box.id);
    if (medAssignedElsewhere) return const <DrawerModel>[];
    return drawers
        .where((DrawerModel d) => !assigned.contains(d.id.trim()))
        .toList(growable: false);
  }

  int get _availableCount {
    int n = 0;
    for (final MedicineBoxModel b in _boxController.boxes) {
      n += availableDrawersForBox(b).length;
    }
    return n;
  }

  Future<void> _createAssignment() async {
    final DrawerModel? d = _selectedDrawer;
    if (d == null) return;
    if (_dmController.isCreating) return;
    final MedicationModel? med = _resolvedMedication;
    final MedicineBoxModel? box = _boxForDrawer(d);
    final int stock = med == null || med.quantity < 0 ? 0 : med.quantity;
    final int? cap = box == null ? null : box.drawerCapacity;
    final int reqQty = (cap != null && cap > 0)
        ? (stock < cap ? stock : cap)
        : stock;
    final int reqMissing = stock - reqQty < 0 ? 0 : stock - reqQty;
    setState(() => _error = null);
    try {
      final DrawerMedicationModel created = await _dmController
          .createAssignment(
            drawerId: d.id.trim(),
            medicationId: widget.medicationId.trim(),
            quantity: reqQty,
            missingQuantity: reqMissing,
          );
      if (!mounted) return;
      final int? respQty = created.quantity;
      final int? respMissing = created.missingQuantity;
      final bool hasMissing = respMissing != null && respMissing > 0;
      final String medName = _resolvedMedication?.name.isNotEmpty == true
          ? _resolvedMedication!.name
          : "Medication";
      final BuildContext ctx = context;
      if (respQty != null) {
        await showDialog<void>(
          context: ctx,
          barrierDismissible: false,
          builder: (BuildContext c) => AlertDialog(
            title: const Text("Medication assigned successfully"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  medName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_boxNameFor(d)} · Drawer ${d.drawerNumber}",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _AssignmentResultRow(
                  label: "Loaded into drawer",
                  value: "$respQty units",
                  accent: AppColors.success,
                ),
                if (hasMissing) ...<Widget>[
                  const SizedBox(height: 8),
                  _AssignmentResultRow(
                    label: "Remaining to load",
                    value: "$respMissing units",
                    accent: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.10),
                      borderRadius: AppRadius.br12,
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.28),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$respMissing unit${respMissing == 1 ? '' : 's'} could not fit in this drawer. Use another drawer for the remaining stock.",
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    "No medication remains to be loaded.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.of(c).pop();
                  Navigator.of(ctx).pop(true);
                },
                child: const Text("Done"),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Medication assigned to drawer.")),
        );
        Navigator.of(ctx).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      final String msg = _friendlyError(e);
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _initialize();
    }
  }

  void _skip() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _boxController,
        _dmController,
        _medicationController,
        _patientController,
      ]),
      builder: (BuildContext c, Widget? _) {
        final MedicationModel? med = _resolvedMedication;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text("Assign Medication"),
            centerTitle: false,
            actions: <Widget>[
              TextButton(
                onPressed: _anyLoading ? null : _skip,
                child: const Text("Skip"),
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: _anyLoading
                ? _LoadingView(
                    loadingBoxes: _loadingBoxes,
                    loadingDrawers: _loadingDrawers,
                    loadingAssignments: _loadingAssignments,
                    loadingMeta: _loadingMeta,
                  )
                : CustomScrollView(
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
                          child: _MedicationHeader(
                            medication: med,
                            medicationId: widget.medicationId,
                            patientName: _resolvedPatientName,
                            patientId:
                                widget.patientId ??
                                widget.patient?.id ??
                                med?.patientId,
                          ),
                        ),
                      ),
                      if (_error != null && _error!.trim().isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: _ErrorBox(
                              message: _error!,
                              onRetry: _initialize,
                            ),
                          ),
                        ),
                      if (!_hasAnyBoxes && _error == null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _EmptyStateBox(
                              title: "No medicine boxes available yet.",
                              subtitle:
                                  "Activate or add a medicine box first to assign this medication.",
                              icon: Icons.inbox_rounded,
                              onRetry: _initialize,
                            ),
                          ),
                        )
                      else if (_hasAnyBoxes && !_hasAnyDrawersAnywhere)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _EmptyStateBox(
                              title: "Unable to load drawers.",
                              subtitle:
                                  "Your medicine boxes exist but we couldn't load their drawers right now.",
                              icon: Icons.error_outline_rounded,
                              onRetry: _initialize,
                              retryLabel: "Retry loading drawers",
                            ),
                          ),
                        )
                      else ...<Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        "Choose a drawer",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _availableCount == 0
                                            ? "All drawers are currently assigned."
                                            : "$_availableCount free drawer${_availableCount == 1 ? '' : 's'} across your boxes.",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: AppRadius.br999,
                                  ),
                                  child: Text(
                                    "$_availableCount free",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              "MY MEDICINE BOXES",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            240,
                          ),
                          sliver: SliverList.separated(
                            itemCount: _boxController.boxes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (BuildContext bc, int i) {
                              final MedicineBoxModel box =
                                  _boxController.boxes[i];
                              return _BoxCard(
                                box: box,
                                canAssign: box.status.isActive,
                                assignBlockReason: box.status.isActive
                                    ? ""
                                    : _assignBlockReasonFor(
                                        _boxController
                                                .drawersForBox(box.id)
                                                .firstOrNull ??
                                            DrawerModel(
                                              id: "",
                                              medicineBoxId: box.id,
                                              drawerNumber: 1,
                                              status: DrawerStatus.empty,
                                              createdAt: null,
                                              updatedAt: null,
                                            ),
                                      ),
                                boxDrawerCapacity: box.drawerCapacity,
                                drawers: _boxController.drawersForBox(box.id),
                                assignedDrawerIds: _assignedDrawerIds,
                                medicationAlreadyAssigned:
                                    _assignedMedicationIds.contains(
                                      widget.medicationId.trim(),
                                    ),
                                selectedDrawerId: _selectedDrawer?.id.trim(),
                                assignmentForDrawer: assignmentForDrawer,
                                medicationForId: medicationForId,
                                onSelectAvailable: (DrawerModel d) {
                                  if (!_assignAllowedFor(d)) {
                                    ScaffoldMessenger.of(bc).showSnackBar(
                                      SnackBar(
                                        content: Text(_assignBlockReasonFor(d)),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _selectedDrawer = d);
                                },
                                isCreating: _dmController.isCreating,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          bottomSheet: _anyLoading
              ? null
              : Container(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    MediaQuery.of(context).padding.bottom + AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_selectedDrawer != null) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: AppRadius.br12,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Selected: Drawer ${_selectedDrawer!.drawerNumber} — ${_boxNameFor(_selectedDrawer!)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Builder(
                            builder: (BuildContext c) {
                              final MedicationModel? med = _resolvedMedication;
                              final MedicineBoxModel? box = _boxForDrawer(
                                _selectedDrawer!,
                              );
                              final int? cap = box == null
                                  ? null
                                  : box.drawerCapacity;
                              final int? stock = med?.quantity;
                              final bool canPreview =
                                  (cap != null && cap > 0) ||
                                  (stock != null && stock >= 0);
                              if (!canPreview) return const SizedBox.shrink();
                              final int previewUpTo =
                                  (cap != null && stock != null)
                                  ? (stock < cap ? stock : cap)
                                  : (cap ?? stock ?? 0);
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: AppRadius.br14,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      const Text(
                                        "Assignment Preview",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (med != null) ...<Widget>[
                                        _AssignmentResultRow(
                                          label: "Medication",
                                          value: med.name.isEmpty
                                              ? "(Medication)"
                                              : med.name,
                                          accent: AppColors.textPrimary,
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      if (stock != null) ...<Widget>[
                                        _AssignmentResultRow(
                                          label: "Available stock",
                                          value: "$stock units",
                                          accent: AppColors.info,
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      _AssignmentResultRow(
                                        label: "Selected drawer",
                                        value:
                                            "Drawer ${_selectedDrawer!.drawerNumber}",
                                        accent: AppColors.textPrimary,
                                      ),
                                      if (cap != null && cap > 0) ...<Widget>[
                                        const SizedBox(height: 4),
                                        _AssignmentResultRow(
                                          label: "Drawer capacity",
                                          value: "$cap units",
                                          accent: AppColors.info,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.info.withOpacity(
                                            0.08,
                                          ),
                                          borderRadius: AppRadius.br12,
                                          border: Border.all(
                                            color: AppColors.info.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 1,
                                              ),
                                              child: Icon(
                                                Icons.info_outline_rounded,
                                                size: 16,
                                                color: AppColors.info,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                previewUpTo > 0
                                                    ? "The backend will load up to $previewUpTo units into this drawer. Final loaded quantity is determined by the server."
                                                    : "The backend will determine how many units can be loaded into this drawer.",
                                                style: TextStyle(
                                                  color: AppColors.info,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        PrimaryButton(
                          label: "Assign Medication",
                          isLoading: _dmController.isCreating,
                          onPressed:
                              _selectedDrawer == null ||
                                  _dmController.isCreating ||
                                  _availableCount == 0 ||
                                  !_assignAllowedFor(_selectedDrawer!)
                              ? null
                              : () {
                                  if (!_assignAllowedFor(_selectedDrawer!)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _assignBlockReasonFor(
                                            _selectedDrawer!,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  _createAssignment();
                                },
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _boxNameFor(DrawerModel d) {
    for (final MedicineBoxModel b in _boxController.boxes) {
      if (b.id.trim() == d.medicineBoxId.trim()) {
        return b.name.isEmpty ? "(Box)" : b.name;
      }
    }
    return "";
  }

  MedicineBoxModel? _boxForDrawer(DrawerModel d) {
    final String bid = d.medicineBoxId.trim();
    if (bid.isEmpty) return null;
    for (final MedicineBoxModel b in _boxController.boxes) {
      if (b.id.trim() == bid) return b;
    }
    return null;
  }

  bool _assignAllowedFor(DrawerModel d) {
    final MedicineBoxModel? b = _boxForDrawer(d);
    if (b == null) return false;
    return b.status.isActive;
  }

  String _assignBlockReasonFor(DrawerModel d) {
    final MedicineBoxModel? b = _boxForDrawer(d);
    if (b == null) return "Medicine box unavailable.";
    if (!b.status.isActive) {
      if (b.status.isMaintenance) {
        return "Your medicine box is under maintenance. Assignments are not available.";
      }
      return "Your medicine box is not active. Please activate your device first.";
    }
    return "";
  }
}

class _AssignmentResultRow extends StatelessWidget {
  const _AssignmentResultRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({
    required this.loadingBoxes,
    required this.loadingDrawers,
    required this.loadingAssignments,
    required this.loadingMeta,
  });

  final bool loadingBoxes;
  final bool loadingDrawers;
  final bool loadingAssignments;
  final bool loadingMeta;

  @override
  Widget build(BuildContext context) {
    final List<({String label, bool active})> steps =
        <({String label, bool active})>[
          (label: "Loading your medicine boxes…", active: loadingBoxes),
          (label: "Loading drawers for each box…", active: loadingDrawers),
          (label: "Loading drawer assignments…", active: loadingAssignments),
          (label: "Loading medication details…", active: loadingMeta),
        ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...steps.map((({String label, bool active}) e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: e.active
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      e.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: e.active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: e.active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text("Retry")),
          ],
        ],
      ),
    );
  }
}

class _EmptyStateBox extends StatelessWidget {
  const _EmptyStateBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onRetry,
    this.retryLabel = "Retry",
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary, size: 42),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: retryLabel, onPressed: onRetry, compact: true),
          ],
        ],
      ),
    );
  }
}

class _BoxCard extends StatelessWidget {
  const _BoxCard({
    required this.box,
    required this.canAssign,
    required this.assignBlockReason,
    required this.boxDrawerCapacity,
    required this.drawers,
    required this.assignedDrawerIds,
    required this.medicationAlreadyAssigned,
    required this.selectedDrawerId,
    required this.assignmentForDrawer,
    required this.medicationForId,
    required this.onSelectAvailable,
    required this.isCreating,
  });

  final MedicineBoxModel box;
  final bool canAssign;
  final String assignBlockReason;
  final int boxDrawerCapacity;
  final List<DrawerModel> drawers;
  final Set<String> assignedDrawerIds;
  final bool medicationAlreadyAssigned;
  final String? selectedDrawerId;
  final DrawerMedicationModel? Function(String drawerId) assignmentForDrawer;
  final MedicationModel? Function(String medicationId) medicationForId;
  final void Function(DrawerModel drawer) onSelectAvailable;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final int freeCount = drawers
        .where((DrawerModel d) => !assignedDrawerIds.contains(d.id.trim()))
        .length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.br12,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        box.name.isEmpty ? "(Unnamed Box)" : box.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(box.status).withOpacity(0.12),
                              borderRadius: AppRadius.br999,
                            ),
                            child: Text(
                              box.status.displayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: _statusColor(box.status),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$freeCount free · ${drawers.length} drawer${drawers.length == 1 ? '' : 's'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!canAssign && assignBlockReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.10),
                    borderRadius: AppRadius.br12,
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 17,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          assignBlockReason,
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (drawers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  "No drawers loaded for this box yet.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...<Widget>[
              Container(
                width: double.infinity,
                height: 1,
                color: AppColors.divider,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...drawers.map<Widget>((DrawerModel d) {
                final DrawerMedicationModel? assignment = assignmentForDrawer(
                  d.id,
                );
                final bool isAssigned = assignment != null;
                final bool available =
                    !isAssigned && !medicationAlreadyAssigned && canAssign;
                final bool selected =
                    selectedDrawerId == d.id.trim() && available;
                final MedicationModel? existingMed = assignment == null
                    ? null
                    : medicationForId(assignment.medicationId);
                final bool showCapacity = boxDrawerCapacity > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.br14,
                      onTap: available && !isCreating
                          ? () => onSelectAvailable(d)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: canAssign
                              ? available
                                    ? AppColors.background
                                    : AppColors.cardBackground.withOpacity(0.7)
                              : AppColors.cardBackground.withOpacity(0.5),
                          borderRadius: AppRadius.br14,
                          border: Border.all(
                            color: !canAssign
                                ? AppColors.border
                                : !available
                                ? AppColors.border
                                : selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (_drawerColor(
                                  d.status,
                                )).withOpacity(0.12),
                                borderRadius: AppRadius.br12,
                                border: Border.all(
                                  color: (_drawerColor(
                                    d.status,
                                  )).withOpacity(0.28),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "#${d.drawerNumber}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _drawerColor(d.status),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        "Drawer ${d.drawerNumber}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _drawerColor(
                                            d.status,
                                          ).withOpacity(0.12),
                                          borderRadius: AppRadius.br999,
                                        ),
                                        child: Text(
                                          d.status.displayLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10.5,
                                            color: _drawerColor(d.status),
                                          ),
                                        ),
                                      ),
                                      if (showCapacity) ...<Widget>[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.info.withOpacity(
                                              0.10,
                                            ),
                                            borderRadius: AppRadius.br999,
                                          ),
                                          child: Text(
                                            "Capacity: $boxDrawerCapacity",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                              color: AppColors.info,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (isAssigned) ...<Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning
                                                .withOpacity(0.12),
                                            borderRadius: AppRadius.br999,
                                          ),
                                          child: Text(
                                            assignment.isActive
                                                ? "Assigned"
                                                : "Assigned (inactive)",
                                            style: TextStyle(
                                              color: assignment.isActive
                                                  ? AppColors.warning
                                                  : AppColors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            existingMed?.name.isNotEmpty == true
                                                ? existingMed!.name
                                                : "Medication ${assignment.medicationId.substring(0, assignment.medicationId.length > 8 ? 8 : assignment.medicationId.length)}",
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (medicationAlreadyAssigned) ...<
                                    Widget
                                  >[
                                    Text(
                                      "This medication is already assigned to another drawer.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else ...<Widget>[
                                    Text(
                                      canAssign
                                          ? (selected
                                                ? "Selected"
                                                : "Available")
                                          : "Unavailable",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: canAssign
                                            ? selected
                                                  ? AppColors.primary
                                                  : AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!available)
                              Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.hintText,
                                size: 20,
                              )
                            else
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.hintText,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
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

  Color _drawerColor(DrawerStatus s) {
    switch (s) {
      case DrawerStatus.empty:
        return AppColors.textSecondary;
      case DrawerStatus.loaded:
        return AppColors.success;
      case DrawerStatus.locked:
        return AppColors.warning;
      case DrawerStatus.dispensing:
        return AppColors.info;
      case DrawerStatus.error:
        return AppColors.error;
    }
  }
}

class _MedicationHeader extends StatelessWidget {
  const _MedicationHeader({
    required this.medication,
    required this.medicationId,
    required this.patientName,
    required this.patientId,
  });

  final MedicationModel? medication;
  final String medicationId;
  final String? patientName;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    final String medName = medication?.name.isNotEmpty == true
        ? medication!.name
        : "(Medication)";
    final int quantity = medication?.quantity ?? 0;
    final String dosage = (medication?.dosage ?? "").trim();
    final DateTime? expiryDate = medication?.expiryDate;
    final bool hasPatientName = patientName?.trim().isNotEmpty == true;
    final bool hasPatientId = patientId?.trim().isNotEmpty == true;
    final String? expiryStr = expiryDate == null
        ? null
        : "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}";
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withOpacity(0.92),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.br20,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: AppRadius.br16,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "Medication",
                  style: TextStyle(
                    color: Color(0xFFDCEAFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  medName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    if (hasPatientName || hasPatientId)
                      _Badge(
                        label:
                            "Patient: ${hasPatientName ? patientName! : '(patient)'}",
                      ),
                    if (dosage.isNotEmpty) _Badge(label: "Dosage: $dosage"),
                    _Badge(label: "Available: $quantity"),
                    if (expiryStr != null) _Badge(label: "Expiry: $expiryStr"),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: AppRadius.br999,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEFF6FF),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
