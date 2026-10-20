import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "login_screen.dart";
import "register_screen.dart";

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onLoginPressed, this.onRegisterPressed});

  static const Color _background = Color(0xFFFFFFFF);

  static const String _assetPath = "assets/images/welcome.png";

  static const double _illustrationSize = 180;

  static const double _topMargin = 40;
  static const double _bottomPadding = 40;

  static const double _welcomeFontSize = 24;
  static const double _appNameFontSize = 44;
  static const double _descriptionFontSize = 16;
  static const double _buttonFontSize = 18;

  static const double _descriptionHorizontalPadding = 40;
  static const double _buttonsHorizontalMargin = 32;

  static const double _buttonHeight = 56;
  static const double _buttonRadius = 10;

  static const double _spaceIllustrationToWelcome = 20;
  static const double _spaceWelcomeToAppName = 8;
  static const double _spaceAppNameToDescription = 18;
  static const double _spaceDescriptionToLoginMin = 60;
  static const double _spaceBetweenButtons = 14;

  static const Color _welcomeColor = Color(0xFFFF6F4A);
  static const Color _brandColor = Color(0xFF1F6FB8);
  static const Color _loginButtonColor = Color(0xFF216FB4);
  static void _noop() {}

  final VoidCallback? onLoginPressed;
  final VoidCallback? onRegisterPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _WelcomeBody(
          onLoginPressed:
              onLoginPressed ??
              () => Navigator.pushNamed(context, "/login"),
          onRegisterPressed:
              onRegisterPressed ??
              () => Navigator.pushNamed(context, "/register"),
        ),
      ),
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody({
    required this.onLoginPressed,
    required this.onRegisterPressed,
  });

  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: WelcomeScreen._bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: WelcomeScreen._topMargin),
                  Image.asset(
                    WelcomeScreen._assetPath,
                    width: WelcomeScreen._illustrationSize,
                    height: WelcomeScreen._illustrationSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(
                    height: WelcomeScreen._spaceIllustrationToWelcome,
                  ),
                  Text(
                    "Welcome To",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: WelcomeScreen._welcomeColor,
                      fontSize: WelcomeScreen._welcomeFontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: WelcomeScreen._spaceWelcomeToAppName),
                  Text(
                    "MediMinder",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: WelcomeScreen._brandColor,
                      fontSize: WelcomeScreen._appNameFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(
                    height: WelcomeScreen._spaceAppNameToDescription,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WelcomeScreen._descriptionHorizontalPadding,
                    ),
                    child: Text(
                      "Your personal assistant for managing\nyour medication schedule.",
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: WelcomeScreen._brandColor,
                        fontSize: WelcomeScreen._descriptionFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: WelcomeScreen._spaceDescriptionToLoginMin,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WelcomeScreen._buttonsHorizontalMargin,
                    ),
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          height: WelcomeScreen._buttonHeight,
                          child: ElevatedButton(
                            onPressed: onLoginPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WelcomeScreen._loginButtonColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  WelcomeScreen._buttonRadius,
                                ),
                              ),
                            ),
                            child: Text(
                              "Login",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: WelcomeScreen._buttonFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: WelcomeScreen._spaceBetweenButtons,
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: WelcomeScreen._buttonHeight,
                          child: OutlinedButton(
                            onPressed: onRegisterPressed,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: WelcomeScreen._background,
                              side: const BorderSide(
                                color: WelcomeScreen._loginButtonColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  WelcomeScreen._buttonRadius,
                                ),
                              ),
                            ),
                            child: Text(
                              "Register",
                              style: GoogleFonts.poppins(
                                color: WelcomeScreen._loginButtonColor,
                                fontSize: WelcomeScreen._buttonFontSize,
                                fontWeight: FontWeight.w600,
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
        );
      },
    );
  }
}
