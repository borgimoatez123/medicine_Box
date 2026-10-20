import "package:flutter/material.dart";

import "../../controllers/medication_controller.dart";
import "../../models/medication_model.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/buttons/primary_button.dart";

class EditMedicationScreen extends StatefulWidget {
  const EditMedicationScreen({
    super.key,
    required this.medication,
    this.patient,
    this.patientName,
  });

  final MedicationModel medication;
  final Patient? patient;
  final String? patientName;

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final MedicationController _controller;

  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _quantityController;
  late final TextEditingController _expiryDateController;

  late MedicationForm _form;
  late DateTime? _expiryDate;
  late bool _clearExpiryOnSave;

  bool _animateIn = false;

  MedicationModel get _medication => widget.medication;
  String get _patientDisplayName =>
      (widget.patient?.fullNameDisplay ?? widget.patientName ?? "Patient")
          .trim();

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
    _nameController = TextEditingController(text: _medication.name);
    _dosageController = TextEditingController(text: _medication.dosage);
    _quantityController = TextEditingController(
      text: _medication.quantity > 0 ? _medication.quantity.toString() : "",
    );
    _form = _medication.form;
    _expiryDate = _medication.expiryDate;
    _clearExpiryOnSave = false;
    _expiryDateController = TextEditingController(
      text: _expiryDate == null ? "" : _formatDate(_expiryDate!),
    );
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
      _clearExpiryOnSave = false;
      _expiryDate = picked;
      _expiryDateController.text = _formatDate(picked);
    });
  }

  Future<void> _clearExpiryDate() async {
    setState(() {
      _clearExpiryOnSave = true;
      _expiryDate = null;
      _expiryDateController.clear();
    });
  }

  Future<void> _onSubmit() async {
    if (_controller.isUpdating) return;
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

    final String origName = _medication.name;
    final String origDosage = _medication.dosage;
    final MedicationForm origForm = _medication.form;
    final int origQty = _medication.quantity;
    final DateTime? origExpiry = _medication.expiryDate;

    final String newName = _nameController.text.trim();
    final String newDosage = _dosageController.text.trim();
    final MedicationForm newForm = _form;
    final int newQty = quantity;
    final DateTime? newExpiry = _clearExpiryOnSave ? null : _expiryDate;

    final bool anyChanges =
        (newName != origName) ||
        (newDosage != origDosage) ||
        (newForm != origForm) ||
        (newQty != origQty) ||
        ((_clearExpiryOnSave && origExpiry != null)) ||
        (!_clearExpiryOnSave && newExpiry != origExpiry);

    if (!anyChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    try {
      final String? pName = newName != origName ? newName : null;
      final String? pDosage = newDosage != origDosage ? newDosage : null;
      final MedicationForm? pForm = newForm != origForm ? newForm : null;
      final int? pQty = newQty != origQty ? newQty : null;
      final DateTime? pExpiry = (!_clearExpiryOnSave && newExpiry != origExpiry)
          ? newExpiry
          : null;
      final bool pClearExpiry = _clearExpiryOnSave && origExpiry != null;

      await _controller.updateMedication(
        _medication,
        name: pName,
        dosage: pDosage,
        form: pForm,
        quantity: pQty,
        expiryDate: pExpiry,
        clearExpiryDate: pClearExpiry,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medication updated successfully.")),
      );
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
                    absorbing: _controller.isUpdating,
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
                                      hintText:
                                          _clearExpiryOnSave ||
                                              _expiryDate == null
                                          ? "No expiry date"
                                          : "yyyy-MM-dd",
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          if (_expiryDate != null ||
                                              _clearExpiryOnSave)
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
                                      label: "Save Changes",
                                      isLoading: _controller.isUpdating,
                                      onPressed: _onSubmit,
                                      leading: const Icon(
                                        Icons.save_rounded,
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
          "Edit Medication",
          style: AppTextStyles.headlineLarge(
            context,
          ).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Update medication details",
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
                  "For patient (read-only)",
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_rounded, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  "Locked",
                  style: AppTextStyles.label(context).copyWith(
                    color: AppColors.info,
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
