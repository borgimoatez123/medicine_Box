import "package:flutter/material.dart";

import "custom_text_field.dart";

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.textInputAction,
    this.onChanged,
    this.validator,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      labelText: widget.labelText,
      hintText: widget.hintText,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      validator: widget.validator,
      obscureText: _obscured,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(_obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded),
      ),
    );
  }
}

