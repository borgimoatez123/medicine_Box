import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../controllers/schedule_controller.dart";
import "../../models/medication_model.dart";
import "../../models/patient.dart";
import "../../models/schedule_model.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";
import "../box/assign_medication_to_drawer_screen.dart";

class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({
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
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final ScheduleController _scheduleController;
  late final MedicationController _medicationController;

  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _timesPerDay = 1;
  final List<TimeOfDay> _times = <TimeOfDay>[
    const TimeOfDay(hour: 8, minute: 0),
  ];
  final Set<int> _daysOfWeek = <int>{1, 2, 3, 4, 5, 6, 7};
  ScheduleStatus _status = ScheduleStatus.active;
  bool _isActive = true;
  bool _refillReminder = false;

  MedicationModel? _medication;
  bool _loadingMedication = false;

  Patient? get _patient => widget.patient;
  String? get _patientId =>
      (widget.patientId ?? widget.patient?.id ?? "").trim();

  @override
  void initState() {
    super.initState();
    _scheduleController = ScheduleController();
    _medicationController = MedicationController();
    _medication = widget.medication;
    _startDateController.text = _formatDate(_startDate);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_medication != null) return;
      setState(() => _loadingMedication = true);
      try {
        _medication = await _medicationController.getMedication(
          widget.medicationId,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _loadingMedication = false);
    });
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const List<String> _dowLabels = <String>[
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  static String _formatDate(DateTime d) {
    return "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
  }

  String _formatTime(TimeOfDay t) {
    return "${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}";
  }

  Future<void> _pickStartDate() async {
    final DateTime initial = _startDate;
    final DateTime first = DateTime(initial.year - 5, 1, 1);
    final DateTime last = DateTime(initial.year + 20, 12, 31);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked;
      _startDateController.text = _formatDate(picked);
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
        _endDateController.clear();
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime initial =
        _endDate ?? _startDate.add(const Duration(days: 30));
    final DateTime first = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime last = DateTime(initial.year + 20, 12, 31);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = picked;
      _endDateController.text = _formatDate(picked);
    });
  }

  Future<void> _clearEndDate() async {
    setState(() {
      _endDate = null;
      _endDateController.clear();
    });
  }

  Future<void> _pickTime(int index) async {
    final TimeOfDay initial = _times[index];
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (BuildContext c, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _times[index] = picked);
  }

  void _setTimesPerDay(int value) {
    if (value < 1) value = 1;
    if (value > 8) value = 8;
    if (value == _timesPerDay) return;
    setState(() {
      _timesPerDay = value;
      if (value > _times.length) {
        while (_times.length < value) {
          _times.add(
            TimeOfDay(
              hour: _times.isEmpty ? 8 : 8 + (_times.length * 4),
              minute: 0,
            ),
          );
        }
      } else {
        _times.removeRange(value, _times.length);
      }
    });
  }

  Future<void> _onSubmit() async {
    if (_scheduleController.isCreating) return;
    final FormState? form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final List<int> daysSorted = _daysOfWeek.toList()..sort();
    if (daysSorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one day of the week")),
      );
      return;
    }
    if (_times.length != _timesPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All dose times must be set")),
      );
      return;
    }
    final List<String> timesHhmm = _times
        .map((TimeOfDay t) => _formatTime(t))
        .toList(growable: false);
    try {
      await _scheduleController.createSchedule(
        medicationId: widget.medicationId,
        dosage: _dosageController.text.trim(),
        startDate: _startDate,
        timesPerDay: _timesPerDay,
        times: timesHhmm,
        endDate: _endDate,
        daysOfWeek: daysSorted,
        status: _status,
        isActive: _isActive,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        refillReminder: _refillReminder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Schedule created successfully.")),
      );
      final MedicationModel medication =
          _medication ??
          await _medicationController.getMedication(widget.medicationId);
      if (!mounted) return;
      final bool? assigned = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AssignMedicationToDrawerScreen(
            medicationId: widget.medicationId,
            medication: medication,
            patient: widget.patient,
            patientId: _patientId,
          ),
        ),
      );
      if (!mounted) return;
      if (assigned == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Drawer assigned.")));
      }
      Navigator.of(context).pop(true);
    } on ScheduleControllerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scheduleController,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _Header(
                        patient: _patient,
                        patientId: _patientId,
                        medication: _medication,
                        loadingMedication: _loadingMedication,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        260,
                      ),
                      sliver: SliverList.list(
                        children: <Widget>[
                          _FieldLabel(text: "Dosage"),
                          TextFormField(
                            controller: _dosageController,
                            decoration: _decoration(
                              "1 tablet",
                              Icons.medical_information_outlined,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (String? v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Dosage is required";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(text: "Times per day"),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(
                                    context,
                                  ).copyWith(trackHeight: 6),
                                  child: Slider(
                                    min: 1,
                                    max: 8,
                                    divisions: 7,
                                    value: _timesPerDay.toDouble(),
                                    activeColor: AppColors.primary,
                                    label: "$_timesPerDay",
                                    onChanged: (double v) =>
                                        _setTimesPerDay(v.round()),
                                  ),
                                ),
                              ),
                              Container(
                                width: 64,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: AppRadius.br12,
                                ),
                                child: Text(
                                  "$_timesPerDay",
                                  style: AppTextStyles.titleLarge(context)
                                      .copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ...List<Widget>.generate(_timesPerDay, (int i) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 62,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: AppRadius.br12,
                                    ),
                                    child: Text(
                                      "Dose ${i + 1}",
                                      style: AppTextStyles.label(context)
                                          .copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Material(
                                      color: AppColors.cardBackground,
                                      borderRadius: AppRadius.br16,
                                      child: InkWell(
                                        borderRadius: AppRadius.br16,
                                        onTap: () => _pickTime(i),
                                        child: Container(
                                          height: 56,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: AppRadius.br16,
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: <Widget>[
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.sm,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  _formatTime(_times[i]),
                                                  style:
                                                      AppTextStyles.bodyMedium(
                                                        context,
                                                      ).copyWith(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 20,
                                                color: AppColors.textSecondary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(text: "Start date (required)"),
                          Material(
                            color: AppColors.cardBackground,
                            borderRadius: AppRadius.br16,
                            child: InkWell(
                              borderRadius: AppRadius.br16,
                              onTap: _pickStartDate,
                              child: TextFormField(
                                controller: _startDateController,
                                enabled: false,
                                decoration: _decoration(
                                  "YYYY-MM-DD",
                                  Icons.calendar_month_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(text: "End date (optional)"),
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Material(
                                color: AppColors.cardBackground,
                                borderRadius: AppRadius.br16,
                                child: InkWell(
                                  borderRadius: AppRadius.br16,
                                  onTap: _pickEndDate,
                                  child: TextFormField(
                                    controller: _endDateController,
                                    enabled: false,
                                    decoration: _decoration(
                                      "YYYY-MM-DD",
                                      Icons.event_available_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              if (_endDate != null)
                                Positioned(
                                  right: 8,
                                  top: 6,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.cancel_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: _clearEndDate,
                                    tooltip: "Clear end date",
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(text: "Days of week"),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: AppRadius.br16,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: List<Widget>.generate(7, (int i) {
                                final int day = i + 1;
                                final bool selected = _daysOfWeek.contains(day);
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Material(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: AppRadius.br12,
                                      child: InkWell(
                                        borderRadius: AppRadius.br12,
                                        onTap: () {
                                          setState(() {
                                            if (selected) {
                                              _daysOfWeek.remove(day);
                                            } else {
                                              _daysOfWeek.add(day);
                                            }
                                          });
                                        },
                                        child: SizedBox(
                                          height: 46,
                                          child: Center(
                                            child: Text(
                                              _dowLabels[i],
                                              style:
                                                  AppTextStyles.label(
                                                    context,
                                                  ).copyWith(
                                                    color: selected
                                                        ? Colors.white
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _FieldLabel(text: "Status"),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        borderRadius: AppRadius.br16,
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<ScheduleStatus>(
                                          value: _status,
                                          isExpanded: true,
                                          borderRadius: AppRadius.br16,
                                          icon: Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: AppColors.primary,
                                          ),
                                          items: kSupportedScheduleStatuses
                                              .map((ScheduleStatus s) {
                                                return DropdownMenuItem<
                                                  ScheduleStatus
                                                >(
                                                  value: s,
                                                  child: Text(
                                                    s.displayLabel,
                                                    style:
                                                        AppTextStyles.bodyMedium(
                                                          context,
                                                        ).copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                );
                                              })
                                              .toList(growable: false),
                                          onChanged: (ScheduleStatus? v) {
                                            if (v == null) return;
                                            setState(() => _status = v);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _FieldLabel(text: "Active"),
                                    Container(
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        borderRadius: AppRadius.br16,
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              _isActive ? "ON" : "OFF",
                                              style:
                                                  AppTextStyles.bodyMedium(
                                                    context,
                                                  ).copyWith(
                                                    color: _isActive
                                                        ? AppColors.primary
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Switch(
                                            value: _isActive,
                                            activeColor: AppColors.primary,
                                            onChanged: (bool v) =>
                                                setState(() => _isActive = v),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SwitchRow(
                            label: "Refill reminder",
                            value: _refillReminder,
                            onChanged: (bool v) =>
                                setState(() => _refillReminder = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(text: "Notes (optional)"),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: _decoration(
                              "Take with breakfast and dinner…",
                              Icons.sticky_note_2_outlined,
                            ),
                            textInputAction: TextInputAction.newline,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AnimatedBuilder(
                            animation: _scheduleController,
                            builder: (BuildContext ctx, _) {
                              return PrimaryButton(
                                label: "Create Schedule",
                                isLoading: _scheduleController.isCreating,
                                onPressed: _onSubmit,
                                leading: Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: AppRadius.br16,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.br16,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.br16,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.br16,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      hintStyle: TextStyle(color: AppColors.textSecondary),
    );
  }
}

class _Header extends StatelessWidget {
  _Header({
    required this.patient,
    required this.patientId,
    required this.medication,
    required this.loadingMedication,
  });

  final Patient? patient;
  final String? patientId;
  final MedicationModel? medication;
  final bool loadingMedication;

  @override
  Widget build(BuildContext context) {
    final String patientName = patient?.fullNameDisplay ?? "Patient";
    final String medName = medication?.name ?? "Medication";
    final String medDosage = medication?.dosage ?? "";
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withOpacity(0.95),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Material(
                  color: Colors.white.withOpacity(0.14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.br12,
                  ),
                  child: InkWell(
                    borderRadius: AppRadius.br12,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_month_rounded,
                  size: 28,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Create Schedule",
              style: AppTextStyles.headlineLarge(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Tap a field to customise dose times & days",
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: Colors.white.withOpacity(0.86)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: AppRadius.br20,
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.primaryLight,
                          AppColors.accent.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: AppRadius.br16,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.medication_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (loadingMedication)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              height: 16,
                              width: 120,
                              child: LinearProgressIndicator(
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          )
                        else ...<Widget>[
                          Text(
                            medName,
                            style: AppTextStyles.titleLarge(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (medDosage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                medDosage,
                                style: AppTextStyles.bodyMedium(context)
                                    .copyWith(
                                      color: Colors.white.withOpacity(0.86),
                                    ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: AppRadius.brMax,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patientName,
                          style: AppTextStyles.label(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTextStyles.label(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.notifications_active_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
