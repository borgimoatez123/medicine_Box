import "package:flutter/material.dart";

import "../../controllers/profile_controller.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_text_styles.dart";

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const double _padding = 24;
  static const double _fieldHeight = 58;
  static const double _buttonHeight = 58;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final ProfileController _controller;

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController()..addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_controller.isChangingPassword) return;

    try {
      final String? serverMsg = await _controller.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (serverMsg?.trim().isNotEmpty ?? false)
                ? serverMsg!.trim()
                : "Password updated successfully.",
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bool busy = _controller.isChangingPassword;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            _padding,
            0,
            _padding,
            keyboardBottom + 24,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    _BackIcon(
                      onPressed: busy ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Change Password",
                      style: AppTextStyles.headlineMedium(context).copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Update your account password",
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: _fieldHeight,
                      child: TextFormField(
                        controller: _currentController,
                        obscureText: !_showCurrent,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "Current Password",
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showCurrent = !_showCurrent),
                            icon: Icon(
                              _showCurrent
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (String? value) {
                          if ((value ?? "").isEmpty) {
                            return "Current password is required";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: _fieldHeight,
                      child: TextFormField(
                        controller: _newController,
                        obscureText: !_showNew,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "New Password",
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showNew = !_showNew),
                            icon: Icon(
                              _showNew
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (String? value) {
                          final String v = (value ?? "");
                          if (v.isEmpty) return "New password is required";
                          if (v.length < 8) return "Minimum 8 characters";
                          if (!v.contains(RegExp(r"[A-Za-z]"))) {
                            return "Must contain at least one letter";
                          }
                          if (!v.contains(RegExp(r"[0-9]"))) {
                            return "Must contain at least one number";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: _fieldHeight,
                      child: TextFormField(
                        controller: _confirmController,
                        obscureText: !_showConfirm,
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: "Confirm New Password",
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (String? value) {
                          final String v = (value ?? "");
                          if (v.isEmpty) return "Confirm password is required";
                          if (v != _newController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: _buttonHeight,
                      child: ElevatedButton(
                        onPressed: busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                "Update Password",
                                style: AppTextStyles.bodyLarge(context)
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.background,
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.icon,
            size: 18,
          ),
        ),
      ),
    );
  }
}
