import "package:flutter/material.dart";

import "../../controllers/drawer_medication_controller.dart";
import "../../controllers/medication_controller.dart";
import "../../controllers/patient_controller.dart";
import "../../controllers/smart_box_controller.dart";
import "../../models/drawer_command_response_model.dart";
import "../../models/drawer_model.dart";
import "../../models/drawer_medication_model.dart";
import "../../models/medication_model.dart";
import "../../models/medicine_box_model.dart";
import "../../models/medicine_box_sensor_model.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../widgets/buttons/primary_button.dart";
import "../../widgets/drawer_sensor_card.dart";

MedicationForm _defaultMedicationForm() => MedicationForm.tablet;

class DrawerAssignmentScreen extends StatefulWidget {
  const DrawerAssignmentScreen({
    super.key,
    required this.drawerId,
    required this.drawerNumber,
    required this.drawerStatus,
    required this.medicineBoxId,
    this.box,
  });

  final String drawerId;
  final int drawerNumber;
  final DrawerStatus drawerStatus;
  final String medicineBoxId;
  final MedicineBoxModel? box;

  @override
  State<DrawerAssignmentScreen> createState() => _DrawerAssignmentScreenState();
}

class _DrawerAssignmentScreenState extends State<DrawerAssignmentScreen> {
  late final DrawerMedicationController _dmController;
  late final MedicationController _medicationController;
  late final PatientController _patientController;
  late final SmartBoxController _boxController;

  DrawerMedicationModel? _assignment;
  MedicationModel? _selectedMedication;

  String? _error;
  String? _sensorError;
  String? _commandError;
  bool _initializing = true;
  bool _showConfirmChange = false;
  bool _hasLoadedSensors = false;
  String? _lastCommandFeedbackType;
  DateTime? _lastCommandFeedbackAt;

  @override
  void initState() {
    super.initState();
    _dmController = DrawerMedicationController();
    _medicationController = MedicationController();
    _patientController = PatientController();
    _boxController = SmartBoxController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initialize();
      if (mounted) await _refreshDrawerSensors(background: true);
    });
  }

  @override
  void dispose() {
    _dmController.dispose();
    _medicationController.dispose();
    _patientController.dispose();
    _boxController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      await Future.wait(<Future<void>>[
        _dmController.loadAssignments(drawerId: widget.drawerId),
        _medicationController.loadMedications(),
        _patientController.loadPatients(),
      ], eagerError: true);
      try {
        await _boxController.loadBoxes();
      } catch (_) {}
      _dmController.boxForDrawerResolver = (String drawerId) {
        final DrawerModel? drawer = _boxController.drawerById(drawerId);
        if (drawer == null) return null;
        return _boxController.findById(drawer.medicineBoxId);
      };
      try {
        await _boxController.loadDrawersForBox(widget.medicineBoxId);
      } catch (_) {}
      final List<DrawerMedicationModel> list = _dmController.assignments
          .where(
            (DrawerMedicationModel a) =>
                a.drawerId.trim() == widget.drawerId.trim(),
          )
          .toList(growable: false);
      final DrawerMedicationModel? active =
          list.any((DrawerMedicationModel a) => a.isActive)
          ? list.firstWhere((DrawerMedicationModel a) => a.isActive)
          : (list.isEmpty ? null : list.first);
      setState(() {
        _assignment = active;
        if (active != null) {
          _selectedMedication = _medicationController.findById(
            active.medicationId,
          );
        } else {
          _selectedMedication = null;
        }
      });
    } on DrawerMedicationControllerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on MedicationControllerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PatientControllerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _refreshDrawerSensors({bool background = false}) async {
    final String id = widget.drawerId.trim();
    if (id.isEmpty) return;
    if (background) {
      _boxController
          .loadDrawerSensorState(id)
          .catchError((Object e) {
            if (mounted) setState(() => _sensorError = e.toString());
            return Future<DrawerSensorState>.value(
              DrawerSensorState(
                drawerId: id,
                drawerIndex: widget.drawerNumber,
                fireDetected: false,
              ),
            );
          })
          .whenComplete(() {
            if (mounted) setState(() => _hasLoadedSensors = true);
          });
      return;
    }
    try {
      if (mounted) setState(() => _sensorError = null);
      await _boxController.loadDrawerSensorState(id);
      if (mounted) {
        setState(() {
          _sensorError = null;
          _hasLoadedSensors = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sensorError = e.toString();
        _hasLoadedSensors = true;
      });
    }
  }

  Future<void> _openDrawer() async {
    final String did = widget.drawerId.trim();
    if (did.isEmpty) return;
    setState(() {
      _commandError = null;
      _lastCommandFeedbackType = "OPENING";
      _lastCommandFeedbackAt = DateTime.now();
    });
    try {
      final DrawerCommandResponse r = await _boxController.openDrawer(did);
      if (!mounted) return;
      setState(() {
        _commandError = null;
        _lastCommandFeedbackType = "OPEN_COMMAND_SENT";
        _lastCommandFeedbackAt = r.createdAt;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            content: const Text(
              "Open command sent. Waiting for medicine box device.",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commandError = e.toString();
        _lastCommandFeedbackType = "ERROR";
        _lastCommandFeedbackAt = DateTime.now();
      });
    }
  }

  Future<bool?> _confirmCloseDrawer() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: const Text("Close Drawer?"),
          content: const Text(
            "The drawer will receive a lock command.\n\n"
            "Note: A successful response means the command was created. "
            "The physical lock happens once the medicine box device picks it up.",
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text(
                "Close Drawer",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeDrawer() async {
    final bool? confirmed = await _confirmCloseDrawer();
    if (confirmed != true) return;
    final String did = widget.drawerId.trim();
    if (did.isEmpty) return;
    setState(() {
      _commandError = null;
      _lastCommandFeedbackType = "CLOSING";
      _lastCommandFeedbackAt = DateTime.now();
    });
    try {
      final DrawerCommandResponse r = await _boxController.closeDrawer(did);
      if (!mounted) return;
      setState(() {
        _commandError = null;
        _lastCommandFeedbackType = "CLOSE_COMMAND_SENT";
        _lastCommandFeedbackAt = r.createdAt;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.textPrimary,
            content: const Text(
              "Close command sent. Waiting for medicine box device.",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commandError = e.toString();
        _lastCommandFeedbackType = "ERROR";
        _lastCommandFeedbackAt = DateTime.now();
      });
    }
  }

  Future<MedicationModel?> _loadMedicationIfNeeded(String medicationId) async {
    final MedicationModel? cached = _medicationController.findById(
      medicationId,
    );
    if (cached != null) return cached;
    try {
      return _medicationController.getMedication(medicationId);
    } catch (_) {
      return null;
    }
  }

  Future<Patient?> _loadPatientIfNeeded(String patientId) async {
    final List<Patient> list = _patientController.patients;
    final int idx = list.indexWhere(
      (Patient p) => p.id.trim() == patientId.trim(),
    );
    if (idx >= 0) return list[idx];
    try {
      return _patientController.getById(patientId);
    } catch (_) {
      return null;
    }
  }

  List<MedicationModel> get _availableMedications {
    final List<DrawerMedicationModel> assigned = _dmController.assignments;
    final Set<String> blockedMedicationIds = assigned
        .map((DrawerMedicationModel a) => a.medicationId.trim())
        .where((String s) => s.isNotEmpty)
        .toSet();
    return _medicationController.medications
        .where(
          (MedicationModel m) => !blockedMedicationIds.contains(m.id.trim()),
        )
        .toList(growable: false);
  }

  Future<void> _createAssignment(MedicationModel medication) async {
    if (_dmController.isCreating) return;
    final int stock = medication.quantity < 0 ? 0 : medication.quantity;
    final int? cap = _liveBox?.drawerCapacity;
    final int reqQty = (cap != null && cap > 0)
        ? (stock < cap ? stock : cap)
        : stock;
    final int reqRemaining = stock - reqQty < 0 ? 0 : stock - reqQty;
    setState(() => _error = null);
    try {
      final DrawerMedicationModel created = await _dmController
          .createAssignment(
            drawerId: widget.drawerId.trim(),
            medicationId: medication.id.trim(),
            quantity: reqQty,
            missingQuantity: reqRemaining,
          );
      if (!mounted) return;
      setState(() {
        _assignment = created;
        _selectedMedication = medication;
        _showConfirmChange = false;
      });
      final int? respQty = created.quantity;
      final int? respMissing = created.missingQuantity;
      final bool hasMissing = respMissing != null && respMissing > 0;
      final BuildContext ctx = context;
      final String medicationName = medication.name.isNotEmpty
          ? medication.name
          : "Medication";
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
                  medicationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Drawer ${widget.drawerNumber}",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _ResultRow(
                  label: "Loaded into drawer",
                  value: "$respQty units",
                  accent: AppColors.success,
                ),
                if (hasMissing) ...<Widget>[
                  const SizedBox(height: 8),
                  _ResultRow(
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
                onPressed: () => Navigator.of(c).pop(),
                child: const Text("Done"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Medication assigned to drawer.")),
        );
      }
    } on DrawerMedicationControllerException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleActive() async {
    final DrawerMedicationModel? a = _assignment;
    if (a == null) return;
    if (_dmController.isUpdatingAssignment(a.id)) return;
    setState(() => _error = null);
    try {
      final DrawerMedicationModel updated = await _dmController
          .updateAssignment(a, isActive: !a.isActive);
      if (!mounted) return;
      setState(() => _assignment = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isActive ? "Assignment enabled." : "Assignment disabled.",
          ),
        ),
      );
    } on DrawerMedicationControllerException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmRemove() async {
    final DrawerMedicationModel? a = _assignment;
    if (a == null) return;
    final MedicationModel? medication =
        _selectedMedication ?? await _loadMedicationIfNeeded(a.medicationId);
    final String name = medication?.name ?? "the medication";
    final BuildContext ctx = context;
    final bool? ok = await showDialog<bool>(
      context: ctx,
      builder: (BuildContext c) => AlertDialog(
        title: const Text("Remove assignment"),
        content: Text("Remove $name from Drawer ${widget.drawerNumber}?"),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.12),
              foregroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    if (_dmController.isDeletingAssignment(a.id)) return;
    setState(() => _error = null);
    try {
      await _dmController.deleteAssignment(a);
      if (!mounted) return;
      setState(() {
        _assignment = null;
        _selectedMedication = null;
        _showConfirmChange = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Assignment removed. Drawer is available."),
        ),
      );
    } on DrawerMedicationControllerException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _changeMedication(MedicationModel next) async {
    final DrawerMedicationModel? existing = _assignment;
    if (existing == null) return;
    if (_dmController.isUpdatingAssignment(existing.id)) return;
    setState(() {
      _error = null;
      _showConfirmChange = false;
    });
    final DrawerMedicationModel snapshot = existing;
    final MedicationModel previousMed =
        _selectedMedication ??
        MedicationModel(
          id: "",
          patientId: "",
          name: "",
          dosage: "",
          form: _defaultMedicationForm(),
          quantity: 0,
        );
    final String previousMedId = snapshot.medicationId;
    int _calcQty(MedicationModel m) {
      final int stock = m.quantity < 0 ? 0 : m.quantity;
      final int? cap = _liveBox?.drawerCapacity;
      return (cap != null && cap > 0) ? (stock < cap ? stock : cap) : stock;
    }

    int _calcMissing(MedicationModel m, int qty) {
      final int stock = m.quantity < 0 ? 0 : m.quantity;
      return stock - qty < 0 ? 0 : stock - qty;
    }

    try {
      final DrawerMedicationModel updated = await _dmController.moveAssignment(
        assignment: snapshot,
        toDrawerId: widget.drawerId.trim(),
      );
      await _dmController.deleteAssignment(updated);
      final int nextQty = _calcQty(next);
      final int nextMissing = _calcMissing(next, nextQty);
      final DrawerMedicationModel created = await _dmController
          .createAssignment(
            drawerId: widget.drawerId.trim(),
            medicationId: next.id.trim(),
            quantity: nextQty,
            missingQuantity: nextMissing,
          );
      if (!mounted) return;
      setState(() {
        _assignment = created;
        _selectedMedication = next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medication changed for this drawer.")),
      );
    } on DrawerMedicationControllerException catch (e) {
      if (!mounted) return;
      setState(() {
        _assignment = snapshot;
        _selectedMedication = previousMed.id.isEmpty ? null : previousMed;
        _error = e.message;
      });
      try {
        await _dmController.loadAssignments(drawerId: widget.drawerId);
        final DrawerMedicationModel? restored = _dmController.findByDrawerId(
          widget.drawerId,
        );
        if (!mounted) return;
        if (restored != null) {
          setState(() {
            _assignment = restored;
            _selectedMedication =
                _medicationController.findById(restored.medicationId) ??
                (previousMed.id.isEmpty ? null : previousMed);
          });
        } else {
          final MedicationModel? prev = previousMed.id.isEmpty
              ? await _loadMedicationIfNeeded(previousMedId)
              : previousMed;
          DrawerMedicationModel? recreated;
          if (prev != null) {
            final int prevQty = _calcQty(prev);
            final int prevMissing = _calcMissing(prev, prevQty);
            try {
              recreated = await _dmController.createAssignment(
                drawerId: widget.drawerId.trim(),
                medicationId: previousMedId.trim(),
                quantity: prevQty,
                missingQuantity: prevMissing,
              );
            } catch (_) {
              recreated = null;
            }
          }
          if (!mounted) return;
          setState(() {
            _assignment = recreated;
            _selectedMedication = prev;
          });
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  MedicineBoxModel? get _liveBox {
    final MedicineBoxModel? viaParam = widget.box;
    if (viaParam != null) return viaParam;
    if (widget.medicineBoxId.trim().isEmpty) return null;
    return _boxController.findById(widget.medicineBoxId);
  }

  bool get _opsAllowed => _liveBox?.canUsePhysicalOperations ?? false;

  bool get _assignAllowed {
    final MedicineBoxModel? b = _liveBox;
    return b != null && b.status.isActive;
  }

  String get _assignBlockReason {
    final MedicineBoxModel? b = _liveBox;
    if (b == null) return "Medicine box unavailable.";
    if (!b.status.isActive) {
      if (b.status.isMaintenance) {
        return "Your medicine box is under maintenance. Assignments are not available.";
      }
      if (b.status.isReady) {
        return "Your medicine box is not active. Please activate your device first.";
      }
      return "Your medicine box is not active. Please activate your device first.";
    }
    return "";
  }

  String get _blockReason {
    final MedicineBoxModel? b = _liveBox;
    if (b == null) return "Medicine box unavailable.";
    if (!b.status.isActive) {
      if (b.status.isMaintenance) {
        return "Your medicine box is under maintenance.";
      }
      if (b.status.isReady) {
        return "Your medicine box is not active. Please activate your device first.";
      }
      return "Your medicine box is not active. Please activate your device first.";
    }
    if (b.deviceStatus.isOffline || !b.deviceStatus.isOnline) {
      return "Your medicine box is offline. Please make sure your device is connected.";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _dmController,
        _medicationController,
        _patientController,
        _boxController,
      ]),
      builder: (BuildContext c, Widget? _) {
        final bool opsAllowed = _opsAllowed;
        final bool assignAllowed = _assignAllowed;
        final String blockReason = _blockReason;
        final String assignBlockReason = _assignBlockReason;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text("Drawer ${widget.drawerNumber}"),
            centerTitle: false,
          ),
          body: SafeArea(
            child: _initializing
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.lg,
                          ),
                          child: _DrawerHeader(
                            drawerNumber: widget.drawerNumber,
                            status: widget.drawerStatus,
                            box: _liveBox,
                          ),
                        ),
                      ),
                      if (!opsAllowed && blockReason.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.sm,
                            ),
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
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      blockReason,
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
                        ),
                      if (_error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.08),
                                borderRadius: AppRadius.br12,
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: _DrawerSensorSection(
                            drawerId: widget.drawerId,
                            drawerNumber: widget.drawerNumber,
                            controller: _boxController,
                            sensorError: _sensorError,
                            loadedOnce: _hasLoadedSensors,
                            onRetry: () => _refreshDrawerSensors(),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: _DrawerCommandActions(
                            drawerId: widget.drawerId,
                            drawerNumber: widget.drawerNumber,
                            controller: _boxController,
                            commandError: _commandError,
                            feedbackType: _lastCommandFeedbackType,
                            feedbackAt: _lastCommandFeedbackAt,
                            onOpen: _openDrawer,
                            onClose: _closeDrawer,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          200,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _assignment == null
                              ? _EmptyDrawerBody(
                                  liveBox: _liveBox,
                                  assignmentEnabled: assignAllowed,
                                  medications: _availableMedications,
                                  patientController: _patientController,
                                  loadingMedications:
                                      _medicationController.isLoading,
                                  selected: _selectedMedication,
                                  creating: _dmController.isCreating,
                                  onSelect: (MedicationModel m) {
                                    if (!assignAllowed) {
                                      ScaffoldMessenger.of(c).showSnackBar(
                                        SnackBar(
                                          content: Text(assignBlockReason),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => _selectedMedication = m);
                                  },
                                  onConfirm: () {
                                    if (!assignAllowed) {
                                      ScaffoldMessenger.of(c).showSnackBar(
                                        SnackBar(
                                          content: Text(assignBlockReason),
                                        ),
                                      );
                                      return;
                                    }
                                    final MedicationModel? m =
                                        _selectedMedication;
                                    if (m == null) return;
                                    _createAssignment(m);
                                  },
                                )
                              : _AssignedBody(
                                  operationsEnabled: opsAllowed,
                                  blockReason: blockReason,
                                  assignment: _assignment!,
                                  medication: _selectedMedication,
                                  loadingMedication:
                                      _medicationController.isLoading,
                                  patientController: _patientController,
                                  availableMedications: _availableMedications,
                                  selectingChange: _showConfirmChange,
                                  updatingActive: _dmController
                                      .isUpdatingAssignment(_assignment!.id),
                                  deleting: _dmController.isDeletingAssignment(
                                    _assignment!.id,
                                  ),
                                  onToggleActive: _toggleActive,
                                  onRemove: _confirmRemove,
                                  onPickChange: () {
                                    if (!opsAllowed) {
                                      ScaffoldMessenger.of(c).showSnackBar(
                                        SnackBar(content: Text(blockReason)),
                                      );
                                      return;
                                    }
                                    setState(() => _showConfirmChange = true);
                                  },
                                  onCancelChange: () {
                                    setState(() => _showConfirmChange = false);
                                  },
                                  onSelectChange: (MedicationModel next) {
                                    if (!opsAllowed) {
                                      ScaffoldMessenger.of(c).showSnackBar(
                                        SnackBar(content: Text(blockReason)),
                                      );
                                      return;
                                    }
                                    _changeMedication(next);
                                  },
                                  loadMedication: _loadMedicationIfNeeded,
                                  loadPatient: _loadPatientIfNeeded,
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DrawerCommandActions extends StatelessWidget {
  const _DrawerCommandActions({
    required this.drawerId,
    required this.drawerNumber,
    required this.controller,
    required this.commandError,
    required this.feedbackType,
    required this.feedbackAt,
    required this.onOpen,
    required this.onClose,
  });

  final String drawerId;
  final int drawerNumber;
  final SmartBoxController controller;
  final String? commandError;
  final String? feedbackType;
  final DateTime? feedbackAt;
  final Future<void> Function() onOpen;
  final Future<void> Function() onClose;

  static String _formatDateTime(DateTime? t) {
    if (t == null) return "";
    final String d = t.toLocal().toString();
    final int space = d.indexOf(" ");
    if (space < 0 || d.length < space + 6) {
      return d.length > 16 ? d.substring(0, 16) : d;
    }
    return d.substring(0, space + 6);
  }

  @override
  Widget build(BuildContext context) {
    final String did = drawerId.trim();
    final bool isLoading =
        did.isNotEmpty && controller.isSendingDrawerCommand(did);
    final DrawerCommandResponse? lastCmd = did.isNotEmpty
        ? controller.lastDrawerCommand(did)
        : null;
    final String? err = commandError;

    final String? label = _feedbackLabel(feedbackType, lastCmd);
    final bool isSuccess =
        label != null &&
        (label == "Open command sent" || label == "Close command sent");
    final bool isInProgress =
        label != null &&
        (label == "Opening drawer…" || label == "Closing drawer…");

    return Container(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.12),
                  borderRadius: AppRadius.br12,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.lock_open_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Drawer Controls",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Send open or lock commands to Drawer $drawerNumber remotely.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _OpenDrawerButton(onOpen: onOpen, loading: isLoading),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CloseDrawerButton(onClose: onClose, loading: isLoading),
              ),
            ],
          ),
          if (err != null && err.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.10),
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      err,
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (label != null) ...<Widget>[
            SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSuccess
                    ? AppColors.success.withOpacity(0.10)
                    : isInProgress
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                        : AppColors.secondaryBackground,
                borderRadius: AppRadius.br12,
                border: Border.all(
                  color: isSuccess
                      ? AppColors.success.withOpacity(0.35)
                      : isInProgress
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
                          : AppColors.border,
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (isSuccess) ...<Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                  ] else if (isInProgress) ...<Widget>[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.info,
                        ),
                      ),
                    ),
                  ] else ...<Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: TextStyle(
                            color: isSuccess
                                ? AppColors.success
                                : isInProgress
                                ? AppColors.info
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (lastCmd != null &&
                            lastCmd.commandId.isNotEmpty) ...<Widget>[
                          SizedBox(height: 2),
                          Text(
                            "Command ID: ${lastCmd.commandId}  •  Status: ${lastCmd.status.toUpperCase()}",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isSuccess && feedbackAt != null) ...<Widget>[
                            SizedBox(height: 2),
                            Text(
                              "Created: ${_formatDateTime(feedbackAt ?? lastCmd.createdAt)}",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.hintText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ] else if (feedbackAt != null) ...<Widget>[
                          SizedBox(height: 2),
                          Text(
                            "At: ${_formatDateTime(feedbackAt)}",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.hintText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            SizedBox(height: AppSpacing.sm),
            Text(
              "Note: HTTP 200 means the command was created. The physical action happens once the medicine box device picks it up.",
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.hintText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _feedbackLabel(String? type, DrawerCommandResponse? lastCmd) {
    switch (type) {
      case "OPENING":
        return "Opening drawer…";
      case "OPEN_COMMAND_SENT":
        return "Open command sent";
      case "CLOSING":
        return "Closing drawer…";
      case "CLOSE_COMMAND_SENT":
        return "Close command sent";
      case "ERROR":
        return null;
      default:
        return null;
    }
  }
}

class _OpenDrawerButton extends StatelessWidget {
  const _OpenDrawerButton({required this.onOpen, required this.loading});

  final Future<void> Function() onOpen;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = !loading;
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: enabled ? onOpen : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withOpacity(0.5), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          backgroundColor: scheme.primary.withOpacity(0.04),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_open_rounded, size: 18),
        label: Text(
          loading ? "Opening…" : "OPEN / UNLOCK",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _CloseDrawerButton extends StatelessWidget {
  const _CloseDrawerButton({required this.onClose, required this.loading});

  final Future<void> Function() onClose;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !loading;
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: enabled ? onClose : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(
            color: AppColors.error.withOpacity(0.55),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          backgroundColor: AppColors.error.withOpacity(0.04),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_rounded, size: 18),
        label: Text(
          loading ? "Closing…" : "CLOSE / LOCK",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _DrawerSensorSection extends StatelessWidget {
  const _DrawerSensorSection({
    required this.drawerId,
    required this.drawerNumber,
    required this.controller,
    required this.sensorError,
    required this.loadedOnce,
    required this.onRetry,
  });

  final String drawerId;
  final int drawerNumber;
  final SmartBoxController controller;
  final String? sensorError;
  final bool loadedOnce;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String did = drawerId.trim();
    final bool isLoading = did.isNotEmpty
        ? controller.isLoadingDrawerSensors(did)
        : false;
    final DrawerSensorState? state = did.isNotEmpty
        ? controller.sensorStateForDrawer(did)
        : null;
    final String? err = sensorError;
    final int effectiveDrawerIndex = state != null && state.drawerIndex > 0
        ? state.drawerIndex
        : drawerNumber;

    Widget body;
    if (isLoading && state == null && !loadedOnce) {
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (err != null && err.trim().isNotEmpty) {
      body = Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.10),
          borderRadius: AppRadius.br16,
          border: Border.all(color: AppColors.error.withOpacity(0.25)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                err,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: isLoading ? null : onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
              ),
              child: Text(
                isLoading ? "Retrying…" : "Retry",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } else if (state == null && !loadedOnce) {
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else {
      body = DrawerSensorCard(
        drawerIndex: effectiveDrawerIndex,
        temperature: state?.temperature,
        humidity: state?.humidity,
        fireDetected: state?.fireDetected ?? false,
        updatedAt: state?.updatedAt,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                "Drawer $drawerNumber — Sensor Status",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isLoading && state == null)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: isLoading ? null : onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  isLoading ? "Refreshing…" : "Refresh",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        body,
      ],
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.drawerNumber,
    required this.status,
    this.box,
  });

  final int drawerNumber;
  final DrawerStatus status;
  final MedicineBoxModel? box;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withOpacity(0.90),
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: AppRadius.br16,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Text(
              "#$drawerNumber",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Drawer $drawerNumber",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: AppRadius.br999,
                      ),
                      child: Text(
                        "Drawer: ${status.displayLabel}",
                        style: const TextStyle(
                          color: Color(0xFFEFF6FF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (box != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: AppRadius.br999,
                        ),
                        child: Text(
                          "Lifecycle: ${box!.status.displayLabel}",
                          style: const TextStyle(
                            color: Color(0xFFEFF6FF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (box != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: AppRadius.br999,
                        ),
                        child: Text(
                          "Device: ${box!.deviceStatus.displayLabel}",
                          style: const TextStyle(
                            color: Color(0xFFEFF6FF),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(DrawerStatus s) {
    switch (s) {
      case DrawerStatus.empty:
        return Colors.white.withOpacity(0.85);
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

class _EmptyDrawerBody extends StatelessWidget {
  const _EmptyDrawerBody({
    this.liveBox,
    required this.assignmentEnabled,
    required this.medications,
    required this.patientController,
    required this.loadingMedications,
    required this.selected,
    required this.creating,
    required this.onSelect,
    required this.onConfirm,
  });

  final MedicineBoxModel? liveBox;
  final bool assignmentEnabled;
  final List<MedicationModel> medications;
  final PatientController patientController;
  final bool loadingMedications;
  final MedicationModel? selected;
  final bool creating;
  final ValueChanged<MedicationModel> onSelect;
  final VoidCallback onConfirm;

  int? get _drawerCapacity {
    final int? c = liveBox?.drawerCapacity;
    if (c == null) return null;
    if (c <= 0) return null;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          "Drawer is empty",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          "Assign one of your available medications to this drawer.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_drawerCapacity != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.12),
              borderRadius: AppRadius.br999,
            ),
            child: Text(
              "Drawer capacity: $_drawerCapacity units",
              style: TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (loadingMedications)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          )
        else if (medications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "No available medications",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  "Every medication is already assigned, or no medications exist yet.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            primary: false,
            itemCount: medications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext c, int i) {
              final MedicationModel m = medications[i];
              final Patient? p = patientController.patients
                  .cast<Patient?>()
                  .firstWhere(
                    (Patient? x) => x?.id.trim() == m.patientId.trim(),
                    orElse: () => null,
                  );
              final bool isSelected = selected?.id.trim() == m.id.trim();
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadius.br16,
                  onTap: () => onSelect(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: AppRadius.br16,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 1.6 : 1,
                      ),
                      boxShadow: isSelected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.18),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: AppRadius.br12,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.medication_outlined,
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
                                m.name.isEmpty ? "(No name)" : m.name,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: <Widget>[
                                  if (m.dosage.isNotEmpty)
                                    _Badge(
                                      label: "Dosage: ${m.dosage}",
                                      color: AppColors.primary,
                                    ),
                                  _Badge(
                                    label: "Available: ${m.quantity}",
                                    color: AppColors.success,
                                  ),
                                  if (m.expiryDate != null)
                                    _Badge(
                                      label: "Exp: ${_fmtExp(m.expiryDate!)}",
                                      color: AppColors.warning,
                                    ),
                                  _Badge(
                                    label:
                                        "Patient: ${p?.fullNameDisplay ?? '(patient)'}",
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.hintText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (selected != null && _drawerCapacity != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "Assignment Preview",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultRow(
                  label: "Medication",
                  value: selected!.name.isEmpty
                      ? "(medication)"
                      : selected!.name,
                  accent: AppColors.textPrimary,
                ),
                const SizedBox(height: 6),
                _ResultRow(
                  label: "Available stock",
                  value: "${selected!.quantity} units",
                  accent: AppColors.success,
                ),
                const SizedBox(height: 6),
                _ResultRow(
                  label: "Drawer capacity",
                  value: "$_drawerCapacity units",
                  accent: AppColors.info,
                ),
                const SizedBox(height: 10),
                Text(
                  "The backend will load up to $_drawerCapacity units into this drawer.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          onPressed: !assignmentEnabled || creating || selected == null
              ? null
              : onConfirm,
          isLoading: creating,
          label: "Assign Medication",
        ),
      ],
    );
  }

  static String _fmtExp(DateTime d) {
    final String y = d.year.toString();
    final String m = d.month.toString().padLeft(2, "0");
    return "$y-$m";
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
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
          width: 120,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppRadius.br999,
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _AssignedBody extends StatelessWidget {
  const _AssignedBody({
    required this.operationsEnabled,
    required this.blockReason,
    required this.assignment,
    required this.medication,
    required this.loadingMedication,
    required this.patientController,
    required this.availableMedications,
    required this.selectingChange,
    required this.updatingActive,
    required this.deleting,
    required this.onToggleActive,
    required this.onRemove,
    required this.onPickChange,
    required this.onCancelChange,
    required this.onSelectChange,
    required this.loadMedication,
    required this.loadPatient,
  });

  final bool operationsEnabled;
  final String blockReason;
  final DrawerMedicationModel assignment;
  final MedicationModel? medication;
  final bool loadingMedication;
  final PatientController patientController;
  final List<MedicationModel> availableMedications;
  final bool selectingChange;
  final bool updatingActive;
  final bool deleting;
  final VoidCallback onToggleActive;
  final VoidCallback onRemove;
  final VoidCallback onPickChange;
  final VoidCallback onCancelChange;
  final ValueChanged<MedicationModel> onSelectChange;
  final Future<MedicationModel?> Function(String) loadMedication;
  final Future<Patient?> Function(String) loadPatient;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MedicationModel?>(
      future: medication == null
          ? loadMedication(assignment.medicationId)
          : Future<MedicationModel?>.value(medication),
      builder: (BuildContext c, AsyncSnapshot<MedicationModel?> snapshot) {
        final MedicationModel? m = snapshot.data;
        return FutureBuilder<Patient?>(
          future: m == null
              ? Future<Patient?>.value(null)
              : loadPatient(m.patientId),
          builder: (BuildContext cc, AsyncSnapshot<Patient?> patientSnap) {
            final Patient? patient = patientSnap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "Medication",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: AppRadius.br16,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: loadingMedication && m == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m?.name.isEmpty ?? true
                                  ? "(medication)"
                                  : m!.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Kv(
                              label: "Patient",
                              value: patient?.fullNameDisplay ?? "(patient)",
                            ),
                            const SizedBox(height: 6),
                            if (assignment.quantity != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _Kv(
                                  label: "In drawer",
                                  value: "${assignment.quantity} units",
                                  accent: AppColors.success,
                                ),
                              ),
                            if (assignment.missingQuantity != null &&
                                assignment.missingQuantity! > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _Kv(
                                  label: "Remaining to load",
                                  value: "${assignment.missingQuantity} units",
                                  accent: AppColors.warning,
                                ),
                              ),
                            _Kv(
                              label: "Stock available",
                              value: m == null
                                  ? "—"
                                  : "${m.quantity} unit${m.quantity == 1 ? '' : 's'}",
                              accent: AppColors.info,
                            ),
                            const SizedBox(height: 6),
                            _Kv(
                              label: "Assignment",
                              value: assignment.isActive
                                  ? "Active"
                                  : "Inactive",
                              accent: assignment.isActive
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "Actions",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!selectingChange)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: !operationsEnabled || updatingActive
                            ? null
                            : onToggleActive,
                        icon: Icon(
                          assignment.isActive
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                        ),
                        label: Text(
                          updatingActive
                              ? "Saving..."
                              : assignment.isActive
                              ? "Disable"
                              : "Enable",
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            !operationsEnabled || deleting || updatingActive
                            ? null
                            : onPickChange,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text("Change Medication"),
                      ),
                      OutlinedButton.icon(
                        onPressed: !operationsEnabled || deleting
                            ? null
                            : onRemove,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withOpacity(0.35),
                          ),
                        ),
                        icon: Icon(
                          deleting
                              ? Icons.hourglass_empty_rounded
                              : Icons.delete_outline_rounded,
                        ),
                        label: Text(
                          deleting ? "Removing..." : "Remove Assignment",
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: AppRadius.br16,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                "Select another available medication to replace the current assignment.",
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onCancelChange,
                              child: const Text("Cancel"),
                            ),
                          ],
                        ),
                        if (availableMedications.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              "No available medications.",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: ListView.separated(
                              shrinkWrap: true,
                              primary: false,
                              itemCount: availableMedications.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (BuildContext cx, int i) {
                                final MedicationModel next =
                                    availableMedications[i];
                                final Patient? p = patientController.patients
                                    .cast<Patient?>()
                                    .firstWhere(
                                      (Patient? x) =>
                                          x?.id.trim() == next.patientId.trim(),
                                      orElse: () => null,
                                    );
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: AppRadius.br12,
                                    onTap: () => onSelectChange(next),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        borderRadius: AppRadius.br12,
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.medication_outlined,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  next.name.isEmpty
                                                      ? "(No name)"
                                                      : next.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  "Patient: ${p?.fullNameDisplay ?? '(patient)'} · Quantity: ${next.quantity}",
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
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
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: accent ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}
