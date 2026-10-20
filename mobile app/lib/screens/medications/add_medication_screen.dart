import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../models/medication_model.dart";
import "../../models/patient.dart";
import "../../screens/schedules/create_schedule_screen.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.patient, this.patientId})
    : assert(
        patient != null || patientId != null,
        "Either patient or patientId must be provided.",
      );

  final Patient? patient;
  final String? patientId;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final MedicationController _controller;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  MedicationForm _form = MedicationForm.tablet;
  DateTime? _expiryDate;

  bool _animateIn = false;

  Patient? get _patient => widget.patient;
  String get _patientId =>
      (widget.patientId ?? widget.patient?.id ?? "").trim();
  String get _patientDisplayName =>
      _patient?.fullNameDisplay ?? "Selected Patient";

  static const List<Map<String, Object>> _formOptions = <Map<String, Object>>[
    <String, Object>{"label": "Tablet", "value": MedicationForm.tablet},
    <String, Object>{"label": "Capsule", "value": MedicationForm.capsule},
    <String, Object>{"label": "Liquid", "value": MedicationForm.liquid},
    <String, Object>{"label": "Injection", "value": MedicationForm.injection},
    <String, Object>{"label": "Cream", "value": MedicationForm.cream},
    <String, Object>{"label": "Powder", "value": MedicationForm.powder},
    <String, Object>{"label": "Other", "value": MedicationForm.other},
  ];

  @override
  void initState() {
    super.initState();
    _controller = MedicationController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _quantityController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    FocusScope.of(context).unfocus();
    final DateTime now = DateTime.now();
    final DateTime initial =
        _expiryDate ?? DateTime(now.year + 1, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _expiryDate = picked;
      _expiryDateController.text = _formatDate(picked);
    });
  }

  Future<void> _clearExpiryDate() async {
    setState(() {
      _expiryDate = null;
      _expiryDateController.clear();
    });
  }

  Future<void> _onSubmit() async {
    if (_controller.isCreating) return;
    final FormState? form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantity must be at least 1")),
      );
      return;
    }
    if (_patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid patient ID format")),
      );
      return;
    }

    try {
      final MedicationModel created = await _controller.createMedication(
        patientId: _patientId,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        form: _form,
        quantity: quantity,
        expiryDate: _expiryDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Medication created successfully — now set up a schedule.",
          ),
        ),
      );
      final bool? scheduleCreated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CreateScheduleScreen(
            medicationId: created.id,
            medication: created,
            patient: _patient,
            patientId: _patientId.isEmpty ? null : _patientId,
          ),
        ),
      );
      if (!mounted) return;
      if (scheduleCreated == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Schedule added.")));
      }
      Navigator.of(context).pop(true);
    } on MedicationControllerException catch (e) {
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
      animation: _controller,
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AbsorbPointer(
                    absorbing: _controller.isCreating,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _animateIn ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        offset: _animateIn
                            ? Offset.zero
                            : const Offset(0, 0.03),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _Header(
                              onBack: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            _PatientBanner(patientName: _patientDisplayName),
                            const SizedBox(height: AppSpacing.xl),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: <Widget>[
                                  _FieldLabel(text: "Name"),
                                  TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "Medication name is required";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "e.g. Lisinopril",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Dosage"),
                                  TextFormField(
                                    controller: _dosageController,
                                    textInputAction: TextInputAction.next,
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "Dosage is required";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "e.g. 10 mg",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Form"),
                                  DropdownButtonFormField<MedicationForm>(
                                    value: _form,
                                    isExpanded: true,
                                    items: _formOptions.map((
                                      Map<String, Object> option,
                                    ) {
                                      return DropdownMenuItem<MedicationForm>(
                                        value:
                                            option["value"] as MedicationForm,
                                        child: Text(option["label"].toString()),
                                      );
                                    }).toList(),
                                    onChanged: (MedicationForm? value) {
                                      if (value == null) return;
                                      setState(() => _form = value);
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Select form",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Quantity"),
                                  TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    validator: (String? value) {
                                      final int? v = int.tryParse(
                                        (value ?? "").trim(),
                                      );
                                      if (v == null) {
                                        return "Quantity is required";
                                      }
                                      if (v < 1) {
                                        return "Quantity must be at least 1";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "e.g. 90",
                                      suffixText: "units",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Expiry Date"),
                                  TextFormField(
                                    controller: _expiryDateController,
                                    readOnly: true,
                                    enableInteractiveSelection: false,
                                    onTap: _pickExpiryDate,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      hintText: "yyyy-MM-dd (optional)",
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          if (_expiryDate != null)
                                            IconButton(
                                              onPressed: _clearExpiryDate,
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                              ),
                                              tooltip: "Clear date",
                                            ),
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: PrimaryButton(
                                      label: "Create Medication",
                                      isLoading: _controller.isCreating,
                                      onPressed: _onSubmit,
                                      leading: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, "0");
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[_BackButton(onPressed: onBack)]),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "Add Medication",
          style: AppTextStyles.headlineLarge(
            context,
          ).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Register a new medication for the patient",
          style: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PatientBanner extends StatelessWidget {
  const _PatientBanner({required this.patientName});

  final String patientName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.br12,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "For patient",
                  style: AppTextStyles.label(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  patientName,
                  style: AppTextStyles.titleLarge(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br12,
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.br12,
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

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
