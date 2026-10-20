import "package:flutter/material.dart";

import "../../controllers/auth_controller.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_text_styles.dart";
import "../home/screen.dart";
import "login_screen.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const double topSpacing = 40;
  static const double titleTopMargin = 70;

  static const double spaceTitleToFirstName = 45;
  static const double spaceBetweenFields = 16;
  static const double spaceConfirmPasswordToRegister = 32;
  static const double spaceRegisterToDivider = 36;
  static const double spaceDividerToGoogle = 32;
  static const double spaceGoogleToBottomText = 70;
  static const double bottomPadding = 30;

  static const double horizontalPadding = 24;

  static const double backButtonSize = 48;
  static const double backButtonRadius = 12;

  static const double textFieldHeight = 58;
  static const double buttonHeight = 56;
  static const double buttonRadius = 10;

  static const String googleAsset = "assets/images/google.png";

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final AuthController _controller;

  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AuthController()..addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            RegisterScreen.horizontalPadding,
            0,
            RegisterScreen.horizontalPadding,
            keyboardBottom + RegisterScreen.bottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: RegisterScreen.topSpacing),
                  _BackButton(onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(height: RegisterScreen.titleTopMargin),
                  Text(
                    "Hello! Register to get\nstarted",
                    style: AppTextStyles.headlineLarge(context).copyWith(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceTitleToFirstName),
                  SizedBox(
                    height: RegisterScreen.textFieldHeight,
                    child: TextFormField(
                      controller: _firstnameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: "First Name"),
                      validator: (String? value) {
                        final String v = (value ?? "").trim();
                        if (v.isEmpty) return "First Name is required";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceBetweenFields),
                  SizedBox(
                    height: RegisterScreen.textFieldHeight,
                    child: TextFormField(
                      controller: _lastnameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: "Last Name"),
                      validator: (String? value) {
                        final String v = (value ?? "").trim();
                        if (v.isEmpty) return "Last Name is required";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceBetweenFields),
                  SizedBox(
                    height: RegisterScreen.textFieldHeight,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: "Email"),
                      validator: (String? value) {
                        final String v = (value ?? "").trim();
                        if (v.isEmpty) return "Email is required";
                        final RegExp emailRegex = RegExp(
                          r"^[^\s@]+@[^\s@]+\.[^\s@]+$",
                        );
                        if (!emailRegex.hasMatch(v)) return "Invalid email";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceBetweenFields),
                  SizedBox(
                    height: RegisterScreen.textFieldHeight,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: "Password",
                        suffixIcon: Icon(Icons.visibility_off_outlined),
                      ),
                      validator: (String? value) {
                        final String v = (value ?? "");
                        if (v.isEmpty) return "Password is required";
                        if (v.length < 8) return "Minimum 8 characters";
                        if (!v.contains(RegExp(r"[A-Za-z]"))) {
                          return "Password must contain at least one letter";
                        }
                        if (!v.contains(RegExp(r"[0-9]"))) {
                          return "Password must contain at least one number";
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceBetweenFields),
                  SizedBox(
                    height: RegisterScreen.textFieldHeight,
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: "Confirm password",
                        suffixIcon: Icon(Icons.visibility_off_outlined),
                      ),
                      validator: (String? value) {
                        final String v = (value ?? "");
                        if (v.isEmpty) return "Confirm password is required";
                        if (v != _passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(
                    height: RegisterScreen.spaceConfirmPasswordToRegister,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: RegisterScreen.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _controller.isLoading
                          ? null
                          : _onRegisterPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RegisterScreen.buttonRadius,
                          ),
                        ),
                      ),
                      child: _controller.isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              "Register",
                              style: AppTextStyles.bodyLarge(context).copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.background,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: RegisterScreen.spaceRegisterToDivider),
                  const _OrDivider(label: "Or"),
                  const SizedBox(height: RegisterScreen.spaceDividerToGoogle),
                  SizedBox(
                    width: double.infinity,
                    height: RegisterScreen.buttonHeight,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Google Sign-In integration.
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        side: BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RegisterScreen.buttonRadius,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Image.asset(
                            RegisterScreen.googleAsset,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Continue with Google",
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: RegisterScreen.spaceGoogleToBottomText,
                  ),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          "Already have an account? ",
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: _controller.isLoading ? null : _goToLogin,
                          child: Text(
                            "Login",
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
    );
  }

  Future<void> _onRegisterPressed() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await _controller.register(
        firstname: _firstnameController.text,
        lastname: _lastnameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      _goToHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _goToHome() {
    try {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil("/home", (Route<dynamic> route) => false);
    } catch (_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _goToLogin() {
    try {
      Navigator.pushReplacementNamed(context, "/login");
    } catch (_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: RegisterScreen.backButtonSize,
      height: RegisterScreen.backButtonSize,
      child: Material(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RegisterScreen.backButtonRadius),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RegisterScreen.backButtonRadius),
          onTap: onPressed,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}
