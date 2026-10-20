import "package:flutter/material.dart";

import "../../controllers/drawer_medication_controller.dart";
import "../../controllers/smart_box_controller.dart";
import "../../models/drawer_model.dart";
import "../../models/medicine_box_model.dart";
import "../../models/medicine_box_sensor_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../widgets/drawer_sensor_card.dart";
import "../../widgets/unassign_medicine_box_dialog.dart";
import "drawer_assignment_screen.dart";
import "scan_box_screen.dart";

class BoxScreen extends StatefulWidget {
  const BoxScreen({
    super.key,
    SmartBoxController? controller,
    String? initialBoxId,
    MedicineBoxModel? initialBox,
  }) : _controller = controller,
       _initialBoxId = initialBoxId,
       _initialBox = initialBox;

  final SmartBoxController? _controller;
  final String? _initialBoxId;
  final MedicineBoxModel? _initialBox;

  @override
  State<BoxScreen> createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen>
    with WidgetsBindingObserver
    implements RouteAware {
  late SmartBoxController _controller;
  MedicineBoxModel? _activeBox;
  final TextEditingController _nameController = TextEditingController();
  final DrawerMedicationController _dm = DrawerMedicationController();
  bool _isEditingName = false;
  String? _error;
  String? _sensorError;
  String? _lastRefreshedBoxId;
  String? _lastRefreshedSensorsBoxId;

  static final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget._controller ?? SmartBoxController();
    _controller.addListener(_onController);
    final MedicineBoxModel? init = widget._initialBox;
    if (init != null) {
      _activeBox = init;
      _nameController.text = init.name;
    }
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<void>? route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onController);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final String? id = _activeBox?.id.trim();
      if (id != null && id.isNotEmpty) {
        _refreshDrawers(id, background: true);
        _refreshSensors(id, background: true);
      }
    }
  }

  @override
  void didPopNext() {
    final String? id = _activeBox?.id.trim();
    if (id != null && id.isNotEmpty) {
      _refreshDrawers(id, background: true);
      _refreshSensors(id, background: true);
    }
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  void _onController() {
    if (!mounted) return;
    String? newBoxId;
    setState(() {
      _error = _controller.error;
      if (_activeBox != null && _controller.boxes.isNotEmpty) {
        final String id = _activeBox!.id.trim();
        for (final MedicineBoxModel b in _controller.boxes) {
          if (b.id.trim() == id) {
            _activeBox = b;
            if (!_isEditingName) _nameController.text = b.name;
            break;
          }
        }
      }
      newBoxId = _activeBox?.id.trim();
    });
    final String? nb = newBoxId;
    if (nb != null && nb.isNotEmpty) {
      if (nb != _lastRefreshedBoxId) {
        _refreshDrawers(nb, background: true);
      }
      if (nb != _lastRefreshedSensorsBoxId) {
        _refreshSensors(nb, background: true);
      }
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _controller.loadBoxes();
    } catch (_) {}
    if (!mounted) return;
    final String? startId = widget._initialBoxId?.trim().isEmpty == true
        ? null
        : widget._initialBoxId?.trim();
    MedicineBoxModel? pick;
    if (_activeBox != null) {
      pick = _activeBox!;
    } else if (startId != null && startId.isNotEmpty) {
      for (final MedicineBoxModel b in _controller.boxes) {
        if (b.id.trim() == startId) {
          pick = b;
          break;
        }
      }
      pick ??= await _tryReload(startId);
    } else if (_controller.boxes.isNotEmpty) {
      pick = _controller.boxes.first;
    }
    if (!mounted) return;
    if (pick != null) {
      final MedicineBoxModel picked = pick;
      setState(() {
        _activeBox = picked;
        _nameController.text = picked.name;
      });
      _refreshDrawers(picked.id);
      _refreshSensors(picked.id, background: true);
    }
  }

  Future<MedicineBoxModel?> _tryReload(String boxId) async {
    try {
      return await _controller.reloadBox(boxId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureDrawers(String boxId) => _refreshDrawers(boxId);
  Future<void> _ensureSensors(String boxId) => _refreshSensors(boxId);

  Future<void> _refreshDrawers(String boxId, {bool background = false}) async {
    final String id = boxId.trim();
    if (id.isEmpty) return;
    _lastRefreshedBoxId = id;
    if (background) {
      _controller.loadDrawersForBox(id).catchError((Object e) {
        if (mounted) {
          setState(() => _error = e.toString());
        }
        return Future<List<DrawerModel>>.value(const <DrawerModel>[]);
      });
      return;
    }
    try {
      await _controller.loadDrawersForBox(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _refreshSensors(String boxId, {bool background = false}) async {
    final String id = boxId.trim();
    if (id.isEmpty) return;
    _lastRefreshedSensorsBoxId = id;
    if (background) {
      _controller.loadSensorStateForBox(id).catchError((Object e) {
        if (mounted) {
          setState(() => _sensorError = e.toString());
        }
        return Future<MedicineBoxSensorStateResponse>.value(
          MedicineBoxSensorStateResponse(
            medicineBoxId: id,
            drawers: const <DrawerSensorState>[],
          ),
        );
      });
      return;
    }
    try {
      if (mounted) setState(() => _sensorError = null);
      await _controller.loadSensorStateForBox(id);
      if (mounted) setState(() => _sensorError = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sensorError = e.toString());
    }
  }

  Future<void> _saveName() async {
    final MedicineBoxModel? b = _activeBox;
    if (b == null) return;
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Name cannot be empty.");
      return;
    }
    try {
      final MedicineBoxModel updated = await _controller.renameBox(b.id, name);
      if (!mounted) return;
      setState(() {
        _activeBox = updated;
        _isEditingName = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Medicine box updated.")));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _unassignBox(MedicineBoxModel box) async {
    final String id = box.id.trim();
    if (id.isEmpty) return;
    if (_controller.isUnassigningBoxId(id)) return;
    final List<String> orphanPreIds = _controller.orphanDrawerIdsForBox(id);
    final dynamic result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext c) =>
          UnassignMedicineBoxDialog(box: box, controller: _controller),
    );
    if (!mounted) return;
    if (result != true) return;
    final List<String> orphanDrawerIds =
        _controller.orphanDrawerIdsForBox(id).isEmpty
        ? orphanPreIds
        : _controller.orphanDrawerIdsForBox(id);
    if (orphanDrawerIds.isNotEmpty) {
      try {
        _dm.clearAssignmentsForBoxDrawers(orphanDrawerIds);
      } catch (_) {}
    }
    final MedicineBoxModel? updated = _controller.findById(id);
    setState(() {
      if (updated != null) {
        _activeBox = updated;
        _nameController.text = updated.name;
      }
      _error = null;
    });
    if (_activeBox == null && _controller.boxes.isNotEmpty) {
      setState(() {
        _activeBox = _controller.boxes.first;
        _nameController.text = _activeBox!.name;
      });
    }
    await _tryReloadDrawers();
  }

  Future<void> _tryReloadDrawers() async {
    final String? id = _activeBox?.id.trim();
    if (id == null || id.isEmpty) return;
    try {
      await Future.wait<void>(<Future<void>>[
        _ensureDrawers(id),
        _ensureSensors(id),
      ]);
    } catch (_) {}
  }

  Future<void> _goScan() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanBoxScreen(controller: _controller),
      ),
    );
    if (!mounted) return;
    if (_controller.boxes.isNotEmpty) {
      setState(() {
        _activeBox = _controller.boxes.first;
        _nameController.text = _activeBox!.name;
        _sensorError = null;
      });
      _ensureDrawers(_activeBox!.id);
      _ensureSensors(_activeBox!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext c, Widget? child) {
        final MedicineBoxModel? liveActive = _liveActiveBox;
        void Function()? onEditToggle;
        void Function()? onEditCancel;
        void Function()? onUnassign;
        if (liveActive != null) {
          final MedicineBoxModel box = liveActive;
          onEditToggle = () {
            setState(() {
              _isEditingName = !_isEditingName;
              if (_isEditingName) {
                _nameController.text = box.name;
              }
            });
          };
          onEditCancel = () {
            setState(() {
              _isEditingName = false;
              _nameController.text = box.name;
            });
          };
          onUnassign = () => _unassignBox(box);
        }
        VoidCallback? onRefresh;
        if (liveActive != null) {
          final MedicineBoxModel box = liveActive;
          onRefresh = () async {
            setState(() {
              _error = null;
              _sensorError = null;
            });
            try {
              await Future.wait<void>(<Future<void>>[
                _controller.loadDrawersForBox(box.id),
                _controller.loadSensorStateForBox(box.id),
              ]);
            } catch (e) {
              if (!mounted) return;
              setState(() {
                if (_error == null) _error = e.toString();
                _sensorError ??= _error;
              });
            }
          };
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: liveActive == null && !_controller.isLoading
                ? _EmptyBoxView(onAdd: _goScan, error: _error)
                : CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.cardBackground,
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppRadius.br12,
                                        side: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(AppSpacing.xxs),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      "Medicine Box",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  if (_controller.boxes.length > 1)
                                    PopupMenuButton<MedicineBoxModel>(
                                      itemBuilder: (BuildContext c) {
                                        return _controller.boxes
                                            .map(
                                              (MedicineBoxModel b) =>
                                                  PopupMenuItem<
                                                    MedicineBoxModel
                                                  >(
                                                    value: b,
                                                    child: Text(b.name),
                                                  ),
                                            )
                                            .toList(growable: false);
                                      },
                                      onSelected: (MedicineBoxModel b) {
                                        setState(() {
                                          _activeBox = b;
                                          _nameController.text = b.name;
                                          _sensorError = null;
                                        });
                                        _ensureDrawers(b.id);
                                        _ensureSensors(b.id);
                                      },
                                    ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: scheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppRadius.br12,
                                      ),
                                      padding: EdgeInsets.all(AppSpacing.xxs),
                                    ),
                                    onPressed: _goScan,
                                    tooltip: "Add medicine box",
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.lg),
                              _BoxHeaderCard(
                                box: liveActive,
                                nameController: _nameController,
                                isEditingName: _isEditingName,
                                isRenaming: _controller.isRenamingBox,
                                isUnassigning: liveActive == null
                                    ? false
                                    : _controller.isUnassigningBoxId(
                                        liveActive.id,
                                      ),
                                onToggleEdit: onEditToggle,
                                onCancelEdit: onEditCancel,
                                onSaveName: _saveName,
                                onUnassign: onUnassign,
                              ),
                              if (_error != null && _error!.trim().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.sm),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.12),
                                      borderRadius: AppRadius.br12,
                                      border: Border.all(
                                        color: AppColors.error.withOpacity(
                                          0.25,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(height: AppSpacing.xl),
                              _SensorsSection(
                                box: liveActive,
                                controller: _controller,
                                sensorError: _sensorError,
                                onRetry: () {
                                  final MedicineBoxModel? b = liveActive;
                                  if (b == null) return;
                                  _refreshSensors(b.id);
                                },
                              ),
                              SizedBox(height: AppSpacing.xl),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      "Drawers",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  if (_controller.isLoadingDrawers)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    TextButton.icon(
                                      onPressed: onRefresh,
                                      style: TextButton.styleFrom(
                                        foregroundColor: scheme.primary,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        "Refresh",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.sm),
                            ],
                          ),
                        ),
                      ),
                      liveActive == null
                          ? const SliverToBoxAdapter(child: SizedBox.shrink())
                          : _DrawersList(
                              box: liveActive,
                              controller: _controller,
                            ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl + 120),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  MedicineBoxModel? get _liveActiveBox {
    final MedicineBoxModel? local = _activeBox;
    if (local == null) {
      final List<MedicineBoxModel> boxes = _controller.boxes;
      if (boxes.isEmpty) return null;
      return boxes.first;
    }
    final MedicineBoxModel? fresh = _controller.findById(local.id);
    return fresh ?? local;
  }
}

class _EmptyBoxView extends StatelessWidget {
  const _EmptyBoxView({required this.onAdd, this.error});
  final VoidCallback onAdd;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.br12,
                          side: BorderSide(color: AppColors.border),
                        ),
                        padding: EdgeInsets.all(AppSpacing.xxs),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Medicine Box",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.br20,
                    gradient: LinearGradient(
                      colors: <Color>[
                        scheme.primary,
                        scheme.primary.withOpacity(0.78),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.smart_toy_rounded,
                        size: 54,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "No medicine box linked yet",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Scan the QR code on your box to get started.",
                        style: TextStyle(
                          color: Color(0xFFEAF3FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null && error!.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: AppRadius.br12,
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.br14,
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text(
                      "Scan Medicine Box",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxHeaderCard extends StatelessWidget {
  const _BoxHeaderCard({
    required this.box,
    required this.nameController,
    required this.isEditingName,
    required this.isRenaming,
    required this.isUnassigning,
    this.onToggleEdit,
    this.onCancelEdit,
    required this.onSaveName,
    this.onUnassign,
  });

  final MedicineBoxModel? box;
  final TextEditingController nameController;
  final bool isEditingName;
  final bool isRenaming;
  final bool isUnassigning;
  final VoidCallback? onToggleEdit;
  final VoidCallback? onCancelEdit;
  final VoidCallback onSaveName;
  final VoidCallback? onUnassign;

  @override
  Widget build(BuildContext context) {
    final MedicineBoxModel b = box!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[scheme.primary, scheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.br20,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: AppRadius.br14,
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: isEditingName
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            "Name",
                            style: TextStyle(
                              color: Color(0xFFE9F3FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.12),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                borderRadius: AppRadius.br12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                borderRadius: AppRadius.br12,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                                borderRadius: AppRadius.br12,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            b.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: AppRadius.br999,
                                ),
                                child: Text(
                                  "Lifecycle: ${b.status.displayLabel}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: b.deviceStatus.isOnline
                                      ? Colors.white.withOpacity(0.22)
                                      : const Color(
                                          0xFFFFB1B1,
                                        ).withOpacity(0.28),
                                  borderRadius: AppRadius.br999,
                                ),
                                child: Text(
                                  "Device: ${b.deviceStatus.displayLabel}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!b.status.isActive || !b.deviceStatus.isOnline)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: b.status.isMaintenance
                                      ? const Color(
                                          0xFFFFF1CC,
                                        ).withOpacity(0.22)
                                      : b.deviceStatus.isOffline
                                      ? const Color(
                                          0xFFFFE0E0,
                                        ).withOpacity(0.22)
                                      : const Color(
                                          0xFFE3F2FD,
                                        ).withOpacity(0.22),
                                  borderRadius: AppRadius.br12,
                                ),
                                child: Text(
                                  b.status.isMaintenance
                                      ? "Your medicine box is under maintenance."
                                      : !b.status.isActive
                                      ? "Your medicine box is not active. Please activate your device first."
                                      : "Your medicine box is offline. Please make sure your device is connected. Read-only access remains available.",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              SizedBox(width: AppSpacing.xs),
              if (isEditingName)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: isRenaming ? null : onCancelEdit,
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.br12,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isRenaming ? null : onSaveName,
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.primary,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.br12,
                        ),
                      ),
                      icon: isRenaming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                    ),
                  ],
                )
              else
                IconButton(
                  onPressed: onToggleEdit,
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _StatTile(
                  icon: Icons.grid_on_rounded,
                  label: "Drawers",
                  value: b.numberOfDrawers.toString(),
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 3,
                child: _StatTile(
                  icon: Icons.inventory_rounded,
                  label: "Capacity",
                  value: "${b.drawerCapacity}",
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 5,
                child: _StatTile(
                  icon: Icons.tag_rounded,
                  label: "Device ID",
                  value: b.deviceId.isEmpty ? "—" : b.deviceId,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (isUnassigning || isEditingName || onUnassign == null)
                  ? null
                  : onUnassign,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                backgroundColor: Colors.white.withOpacity(0.12),
                disabledForegroundColor: Colors.white.withOpacity(0.65),
                side: BorderSide(
                  color: isUnassigning
                      ? AppColors.error.withOpacity(0.55)
                      : AppColors.error.withOpacity(0.65),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.br14),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              icon: isUnassigning
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
                  : const Icon(Icons.link_off_rounded, size: 18),
              label: Text(
                isUnassigning ? "Unassigning…" : "Unassign Medicine Box",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: AppRadius.br12,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE2ECFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorsSection extends StatelessWidget {
  const _SensorsSection({
    required this.box,
    required this.controller,
    required this.sensorError,
    required this.onRetry,
  });

  final MedicineBoxModel? box;
  final SmartBoxController controller;
  final String? sensorError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (box == null) return const SizedBox.shrink();
    final String boxId = box!.id.trim();
    if (boxId.isEmpty) return const SizedBox.shrink();

    final MedicineBoxSensorStateResponse? state = controller.sensorStateForBox(
      boxId,
    );
    final bool isLoading = controller.isLoadingSensors;
    final String? err = sensorError;
    final List<DrawerSensorState> drawers =
        state?.drawers ?? const <DrawerSensorState>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                "Drawer Environment & Safety",
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
        if (err != null && err.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.10),
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.error.withOpacity(0.25)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.br12,
                      ),
                    ),
                    child: Text(
                      isLoading ? "Retrying…" : "Retry",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isLoading && state == null && err == null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (state == null && (err == null || err.trim().isEmpty))
          const SizedBox.shrink()
        else if (drawers.isEmpty)
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.sensors_off_rounded,
                  color: AppColors.textSecondary.withOpacity(0.8),
                  size: 44,
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  "No drawers configured.",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sensor readings will appear once drawers are provisioned for ${box!.name}.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              for (int i = 0; i < drawers.length; i++) ...<Widget>[
                DrawerSensorCard(
                  drawerIndex: drawers[i].drawerIndex,
                  temperature: drawers[i].temperature,
                  humidity: drawers[i].humidity,
                  fireDetected: drawers[i].fireDetected,
                  updatedAt: drawers[i].updatedAt,
                  drawerId: drawers[i].drawerId,
                  medicineBoxId:
                      drawers[i].medicineBoxId?.isNotEmpty ?? false
                          ? drawers[i].medicineBoxId
                          : (box?.id ?? ""),
                  box: box,
                ),
                if (i != drawers.length - 1) SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
      ],
    );
  }
}

class _DrawersList extends StatelessWidget {
  const _DrawersList({required this.box, required this.controller});

  final MedicineBoxModel box;
  final SmartBoxController controller;

  @override
  Widget build(BuildContext context) {
    final List<DrawerModel> items = controller.drawersForBox(box.id);
    if (items.isEmpty && controller.isLoadingDrawers) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: AppRadius.br16,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.inbox_rounded,
                color: AppColors.textSecondary.withOpacity(0.8),
                size: 44,
              ),
              SizedBox(height: AppSpacing.xxs),
              Text(
                "No drawers yet.",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Refresh to load the drawers of ${box.name}.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext c, int index) {
          final DrawerModel d = items[index];
          return _DrawerTile(drawer: d, medicineBoxId: box.id, box: box);
        },
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.drawer,
    required this.medicineBoxId,
    this.box,
  });

  final DrawerModel drawer;
  final String medicineBoxId;
  final MedicineBoxModel? box;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color statusColor = _colorFor(drawer.status, scheme);
    return InkWell(
      borderRadius: AppRadius.br16,
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext c) => DrawerAssignmentScreen(
              drawerId: drawer.id.trim(),
              drawerNumber: drawer.drawerNumber,
              drawerStatus: drawer.status,
              medicineBoxId: medicineBoxId.trim(),
              box: box,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: AppRadius.br12,
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "#${drawer.drawerNumber}",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Drawer ${drawer.drawerNumber}",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: AppRadius.br999,
                            ),
                            child: Text(
                              drawer.status.displayLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          if (drawer.lastDispensedAt != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              "Last dispensed ${_ago(drawer.lastDispensedAt!)}",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.hintText,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(DrawerStatus s, ColorScheme scheme) {
    switch (s) {
      case DrawerStatus.empty:
        return AppColors.textSecondary.withOpacity(0.8);
      case DrawerStatus.loaded:
        return AppColors.success;
      case DrawerStatus.locked:
        return AppColors.warning;
      case DrawerStatus.dispensing:
        return scheme.primary;
      case DrawerStatus.error:
        return AppColors.error;
    }
  }

  String _ago(DateTime t) {
    final Duration d = DateTime.now().toUtc().difference(t.toUtc());
    if (d.inDays >= 2) return "${d.inDays}d ago";
    if (d.inDays >= 1) return "1d ago";
    if (d.inHours >= 2) return "${d.inHours}h ago";
    if (d.inHours >= 1) return "1h ago";
    if (d.inMinutes >= 2) return "${d.inMinutes}m ago";
    return "just now";
  }
}
