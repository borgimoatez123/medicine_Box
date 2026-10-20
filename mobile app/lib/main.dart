import "dart:async";

import "package:flutter/material.dart";

import "controllers/notification_controller.dart";
import "controllers/patient_details_controller.dart";
import "controllers/settings_controller.dart";
import "data/repositories/patient_repository.dart";
import "models/patient.dart";
import "screens/auth/auth_gate.dart";
import "screens/auth/login_screen.dart";
import "screens/auth/register_screen.dart";
import "screens/auth/screen.dart";
import "screens/home/home_screen.dart";
import "screens/patient/patient_details_screen.dart";
import "screens/profile/change_password_screen.dart";
import "screens/profile/delete_account_screen.dart";
import "screens/profile/forgot_password_screen.dart";
import "screens/splash/screen.dart";
import "utils/app_colors.dart";
import "utils/app_palette.dart";
import "utils/app_text_styles.dart";
import "utils/app_theme.dart";

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: "rootNav",
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsController.instance.load();
  await NotificationController.instance.init(navigatorKey: _rootNavigatorKey);
  runApp(const SmartMedicineApp());
}

class SmartMedicineApp extends StatelessWidget {
  const SmartMedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Listenable settings = SettingsController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        settings,
        NotificationController.instance,
      ]),
      builder: (BuildContext c, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _rootNavigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: SettingsController.instance.themeMode,
          home: const SplashScreen(),
          onGenerateRoute: (RouteSettings s) {
            switch (s.name) {
              case "/":
              case "/welcome":
                return MaterialPageRoute(
                  builder: (_) =>
                      const UnauthenticatedOnly(child: WelcomeScreen()),
                  settings: s,
                );
              case "/login":
                return MaterialPageRoute(
                  builder: (_) =>
                      const UnauthenticatedOnly(child: LoginScreen()),
                  settings: s,
                );
              case "/register":
                return MaterialPageRoute(
                  builder: (_) =>
                      const UnauthenticatedOnly(child: RegisterScreen()),
                  settings: s,
                );
              case "/forgot-password":
                return MaterialPageRoute(
                  builder: (_) =>
                      const UnauthenticatedOnly(child: ForgotPasswordScreen()),
                  settings: s,
                );
              case "/home":
                return MaterialPageRoute(
                  builder: (_) => const AuthenticatedOnly(child: HomeScreen()),
                  settings: s,
                );
              case "/change-password":
                return MaterialPageRoute(
                  builder: (_) =>
                      const AuthenticatedOnly(child: ChangePasswordScreen()),
                  settings: s,
                );
              case "/delete-account":
                return MaterialPageRoute(
                  builder: (_) =>
                      const AuthenticatedOnly(child: DeleteAccountScreen()),
                  settings: s,
                );
              case NotificationController.kRouteMedicationSchedule:
                final NotificationRouteArgs? args =
                    s.arguments is NotificationRouteArgs
                    ? s.arguments as NotificationRouteArgs
                    : null;
                return MaterialPageRoute(
                  builder: (_) => AuthenticatedOnly(
                    child: _NotificationDeepLinkScreen(
                      medicationId: args?.medicationId,
                      scheduleId: args?.scheduleId,
                      patientId: args?.patientId,
                    ),
                  ),
                  settings: s,
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => const AuthGate(),
                  settings: s,
                );
            }
          },
        );
      },
    );
  }
}

class _NotificationDeepLinkScreen extends StatefulWidget {
  const _NotificationDeepLinkScreen({
    this.medicationId,
    this.scheduleId,
    this.patientId,
  });

  final String? medicationId;
  final String? scheduleId;
  final String? patientId;

  @override
  State<_NotificationDeepLinkScreen> createState() =>
      _NotificationDeepLinkScreenState();
}

class _NotificationDeepLinkScreenState
    extends State<_NotificationDeepLinkScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final String? pid = widget.patientId?.trim();
    try {
      if (pid != null && pid.isNotEmpty) {
        final Patient patient = await PatientRepository().getPatientById(pid);
        if (!mounted) return;
        final NavigatorState nav = Navigator.of(context);
        await nav.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailsScreen(patient: patient),
          ),
        );
        final PatientDetailsController? c = _findDetailsController();
        if (c != null) {
          c.setTab(1);
        }
        return;
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  PatientDetailsController? _findDetailsController() {
    try {
      final BuildContext? ctx = _rootNavigatorKey.currentContext;
      if (ctx == null) return null;
      // Best-effort: walk up the tree and look for a PatientDetailsController
      // attached to a PatientDetailsScreen's state. We cannot guarantee it
      // synchronously, so we simply skip the tab preselect and let the user
      // navigate manually.
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: palette.icon),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _loading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      "Opening reminder…",
                      style: AppTextStyles.bodyLarge(
                        context,
                      ).copyWith(color: palette.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: palette.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Could not open this reminder",
                      style: AppTextStyles.titleLarge(context).copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(color: palette.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomeScreen(),
                          ),
                        );
                      },
                      child: const Text("Go to Home"),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
