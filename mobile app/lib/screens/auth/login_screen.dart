import "package:flutter/material.dart";

import "../../controllers/auth_controller.dart";
import "../home/screen.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_text_styles.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const double _topSpacing = 40;
  static const double _titleTopMargin = 80;

  static const double _spaceTitleToEmail = 50;
  static const double _spaceEmailToPassword = 16;
  static const double _spacePasswordToForgot = 12;
  static const double _spaceForgotToLogin = 36;
  static const double _spaceLoginToDivider = 40;
  static const double _spaceDividerToGoogle = 32;
  static const double _spaceGoogleToBottomText = 80;
  static const double _bottomPadding = 30;

  static const double _horizontalPadding = 24;

  static const double _backButtonSize = 48;
  static const double _backButtonRadius = 12;

  static const double _textFieldHeight = 58;
  static const double _buttonHeight = 56;
  static const double _buttonRadius = 10;

  static const String _googleAsset = "assets/images/google.png";

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final AuthController _controller;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    _emailController.dispose();
    _passwordController.dispose();
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
            LoginScreen._horizontalPadding,
            0,
            LoginScreen._horizontalPadding,
            keyboardBottom + LoginScreen._bottomPadding,
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
                  const SizedBox(height: LoginScreen._topSpacing),
                  _BackButton(onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(height: LoginScreen._titleTopMargin),
                  Text(
                    "Welcome back! Glad\nto see you, Again!",
                    style: AppTextStyles.headlineLarge(context).copyWith(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: LoginScreen._spaceTitleToEmail),
                  SizedBox(
                    height: LoginScreen._textFieldHeight,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: "Enter your email",
                      ),
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
                  const SizedBox(height: LoginScreen._spaceEmailToPassword),
                  SizedBox(
                    height: LoginScreen._textFieldHeight,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: "Enter your password",
                        suffixIcon: Icon(Icons.visibility_off_outlined),
                      ),
                      validator: (String? value) {
                        final String v = (value ?? "");
                        if (v.isEmpty) return "Password is required";
                        if (v.length < 8) return "Minimum 8 characters";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: LoginScreen._spacePasswordToForgot),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        "/forgot-password",
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          "Forgot Password?",
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: LoginScreen._spaceForgotToLogin),
                  SizedBox(
                    width: double.infinity,
                    height: LoginScreen._buttonHeight,
                    child: ElevatedButton(
                      onPressed: _controller.isLoading ? null : _onLoginPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            LoginScreen._buttonRadius,
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
                              "Login",
                              style: AppTextStyles.bodyLarge(context).copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.background,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: LoginScreen._spaceLoginToDivider),
                  _OrDivider(label: "Or", color: AppColors.border),
                  const SizedBox(height: LoginScreen._spaceDividerToGoogle),
                  SizedBox(
                    width: double.infinity,
                    height: LoginScreen._buttonHeight,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        side: BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            LoginScreen._buttonRadius,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Image.asset(
                            LoginScreen._googleAsset,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Continue with Google",
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LoginScreen._spaceGoogleToBottomText),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          "Don't have an account? ",
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, "/register");
                          },
                          child: Text(
                            "Register",
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

  Future<void> _onLoginPressed() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await _controller.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      try {
        Navigator.of(context).pushNamedAndRemoveUntil(
          "/home",
          (Route<dynamic> route) => false,
        );
      } catch (_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LoginScreen._backButtonSize,
      height: LoginScreen._backButtonSize,
      child: Material(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LoginScreen._backButtonRadius),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(LoginScreen._backButtonRadius),
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
  const _OrDivider({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: color, thickness: 1)),
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
        Expanded(child: Divider(color: color, thickness: 1)),
      ],
    );
  }
}
