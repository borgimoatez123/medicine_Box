import "package:flutter/material.dart";

import "../../controllers/patient_controller.dart";
import "../../controllers/patient_dashboard_controller.dart";
import "../../models/patient.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";
import "../../widgets/patient_avatar_button.dart";

String? _normalizeGender(String? gender) {
  if (gender == null) return null;
  final String normalized = gender.trim().toUpperCase();
  if (normalized == "MALE") return "MALE";
  if (normalized == "FEMALE") return "FEMALE";
  return null;
}

String? _normalizeBloodType(String? bloodType) {
  if (bloodType == null) return null;
  String normalized = bloodType.trim().toUpperCase();
  normalized = normalized.replaceAll(" ", "");
  const List<String> valid = <String>[
    "A+",
    "A-",
    "B+",
    "B-",
    "AB+",
    "AB-",
    "O+",
    "O-",
  ];
  return valid.contains(normalized) ? normalized : null;
}

class UpdatePatientScreen extends StatefulWidget {
  const UpdatePatientScreen({
    super.key,
    required this.patient,
    this.dashboardController,
  });

  final Patient patient;
  final PatientDashboardController? dashboardController;

  @override
  State<UpdatePatientScreen> createState() => _UpdatePatientScreenState();
}

class _UpdatePatientScreenState extends State<UpdatePatientScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final PatientController _controller;

  late final TextEditingController _firstnameController;
  late final TextEditingController _lastnameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _notesController;

  DateTime? _birthDate;
  String? _gender;
  String? _bloodType;

  bool _animateIn = false;

  static const List<Map<String, String>> _genderOptionsRaw =
      <Map<String, String>>[
        <String, String>{"label": "Male", "value": "MALE"},
        <String, String>{"label": "Female", "value": "FEMALE"},
      ];

  static List<Map<String, String>> get _genderOptions {
    final Set<String> seen = <String>{};
    return _genderOptionsRaw
        .where((Map<String, String> e) {
          final String? v = e["value"];
          if (v == null) return false;
          return seen.add(v);
        })
        .toList(growable: false);
  }

  static const List<String> _bloodGroupsRaw = <String>[
    "A+",
    "A-",
    "B+",
    "B-",
    "AB+",
    "AB-",
    "O+",
    "O-",
  ];

  static List<String> get _bloodGroups =>
      _bloodGroupsRaw.toSet().toList(growable: false);

  @override
  void initState() {
    super.initState();
    _controller = PatientController();
    final Patient p = widget.patient;
    _firstnameController = TextEditingController(text: p.firstname);
    _lastnameController = TextEditingController(text: p.lastname);
    _birthDate = p.dateOfBirth;
    _birthDateController = TextEditingController(
      text: _birthDate != null ? _formatDate(_birthDate!) : "",
    );
    _weightController = TextEditingController(
      text: p.weightKg != null ? _stripTrailingZeros(p.weightKg!) : "",
    );
    _heightController = TextEditingController(
      text: p.heightCm != null ? p.heightCm.toString() : "",
    );
    _allergiesController = TextEditingController(text: p.allergies ?? "");
    _notesController = TextEditingController(text: p.notes ?? "");
    _gender = _normalizeGender(p.gender);
    _bloodType = _normalizeBloodType(p.bloodType);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatDate(picked);
    });
  }

  Future<void> _onSubmit() async {
    if (_controller.isUpdating) return;
    final FormState? form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final double? weightKg = _weightController.text.trim().isEmpty
        ? null
        : double.tryParse(_weightController.text.trim());
    final int? heightCm = _heightController.text.trim().isEmpty
        ? null
        : int.tryParse(_heightController.text.trim());

    if (_weightController.text.trim().isNotEmpty &&
        (weightKg == null || weightKg <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Weight must be greater than 0")),
      );
      return;
    }
    if (_heightController.text.trim().isNotEmpty &&
        (heightCm == null || heightCm <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Height must be greater than 0")),
      );
      return;
    }

    final String firstname = _firstnameController.text;
    final String lastname = _lastnameController.text;
    if (firstname.trim().isEmpty || lastname.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("First and last name are required")),
      );
      return;
    }

    final String? normalizedGender = _normalizeGender(_gender);
    final String? normalizedBloodType = _normalizeBloodType(_bloodType);

    try {
      final Patient updated = await _controller.updatePatient(
        original: widget.patient,
        firstName: firstname,
        lastName: lastname,
        gender: normalizedGender,
        dateOfBirth: _birthDate,
        weightKg: weightKg,
        heightCm: heightCm,
        bloodType: normalizedBloodType,
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      widget.dashboardController?.setPatient(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            content: Row(
              children: const <Widget>[
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "Patient updated successfully.",
                    style: TextStyle(
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
      Navigator.of(context).pop(updated);
    } on PatientControllerException catch (e) {
      if (!mounted) return;
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
                    e.message.isEmpty ? "Failed to update patient." : e.message,
                    style: const TextStyle(
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
    } catch (e) {
      if (!mounted) return;
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
                    e.toString().isEmpty
                        ? "Failed to update patient."
                        : e.toString(),
                    style: const TextStyle(
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
                            const SizedBox(height: AppSpacing.xl),
                            Center(
                              child: PatientAvatarButton(
                                controller: _controller,
                                patient: widget.patient,
                                enabled: !_controller.isUpdating,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              "Tap the avatar to upload, replace, or remove the photo.",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: <Widget>[
                                  _FieldLabel(text: "First Name"),
                                  TextFormField(
                                    controller: _firstnameController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const <String>[
                                      AutofillHints.givenName,
                                    ],
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "First name is required";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Enter first name",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Last Name"),
                                  TextFormField(
                                    controller: _lastnameController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const <String>[
                                      AutofillHints.familyName,
                                    ],
                                    validator: (String? value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "Last name is required";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Enter last name",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Gender"),
                                  DropdownButtonFormField<String>(
                                    value: _gender,
                                    isExpanded: true,
                                    items: _genderOptions.map((
                                      Map<String, String> option,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: option["value"],
                                        child: Text(option["label"] ?? ""),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      setState(() => _gender = value);
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Select gender",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Birth Date"),
                                  TextFormField(
                                    controller: _birthDateController,
                                    readOnly: true,
                                    enableInteractiveSelection: false,
                                    onTap: _pickBirthDate,
                                    decoration: const InputDecoration(
                                      hintText: "yyyy-MM-dd",
                                      suffixIcon: Icon(
                                        Icons.calendar_month_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Weight"),
                                  TextFormField(
                                    controller: _weightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: false,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    validator: (String? value) {
                                      final String v = (value ?? "").trim();
                                      if (v.isEmpty) return null;
                                      final double? d = double.tryParse(v);
                                      if (d == null) {
                                        return "Enter a valid number";
                                      }
                                      if (d <= 0) return "Weight must be > 0";
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "72.5",
                                      suffixText: "kg",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Height"),
                                  TextFormField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    validator: (String? value) {
                                      final String v = (value ?? "").trim();
                                      if (v.isEmpty) return null;
                                      final double? d = double.tryParse(v);
                                      if (d == null) {
                                        return "Enter a valid number";
                                      }
                                      if (d <= 0) return "Height must be > 0";
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "175",
                                      suffixText: "cm",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Blood Type"),
                                  DropdownButtonFormField<String>(
                                    value: _bloodType,
                                    isExpanded: true,
                                    items: _bloodGroups.map((String bg) {
                                      return DropdownMenuItem<String>(
                                        value: bg,
                                        child: Text(bg),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      setState(() => _bloodType = value);
                                    },
                                    decoration: const InputDecoration(
                                      hintText: "Select blood type",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Allergies"),
                                  TextFormField(
                                    controller: _allergiesController,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.next,
                                    minLines: 2,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      hintText: "List any allergies (optional)",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FieldLabel(text: "Notes"),
                                  TextFormField(
                                    controller: _notesController,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.newline,
                                    minLines: 4,
                                    maxLines: 8,
                                    decoration: const InputDecoration(
                                      hintText: "Additional notes (optional)",
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: ElevatedButton(
                                      onPressed: _controller.isUpdating
                                          ? null
                                          : _onSubmit,
                                      style: ElevatedButton.styleFrom(
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: AppRadius.br12,
                                        ),
                                      ),
                                      child: _controller.isUpdating
                                          ? SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                              ),
                                            )
                                          : Text(
                                              "Save Changes",
                                              style: AppTextStyles.button(
                                                context,
                                              ),
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

  static String _stripTrailingZeros(num value) {
    if (value is int) return value.toString();
    String s = value.toString();
    if (s.contains(".")) {
      s = s.replaceAll(RegExp(r"0+$"), "");
      s = s.replaceAll(RegExp(r"\.$"), "");
    }
    return s;
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
          "Edit Patient",
          style: AppTextStyles.headlineLarge(
            context,
          ).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Update patient information",
          style: AppTextStyles.bodyMedium(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      ],
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
