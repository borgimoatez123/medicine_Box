import "package:flutter/material.dart";

import "../../services/auth_storage.dart";
import "../home/home_screen.dart";
import "screen.dart";

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bool ok = await AuthStorage().hasValidAccessToken();
    if (!mounted) return;
    setState(() => _isAuthenticated = ok);
  }

  @override
  Widget build(BuildContext context) {
    final bool? authed = _isAuthenticated;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: authed == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : authed
          ? const HomeScreen()
          : const WelcomeScreen(),
    );
  }
}

class UnauthenticatedOnly extends StatefulWidget {
  const UnauthenticatedOnly({super.key, required this.child});

  final Widget child;

  @override
  State<UnauthenticatedOnly> createState() => _UnauthenticatedOnlyState();
}

class _UnauthenticatedOnlyState extends State<UnauthenticatedOnly> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final bool authed = await AuthStorage().hasValidAccessToken();
    if (!mounted) return;

    if (authed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil("/home", (Route<dynamic> route) => false);
      });
      return;
    }

    setState(() => _allowed = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: (_allowed ?? false)
          ? widget.child
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class AuthenticatedOnly extends StatefulWidget {
  const AuthenticatedOnly({super.key, required this.child});

  final Widget child;

  @override
  State<AuthenticatedOnly> createState() => _AuthenticatedOnlyState();
}

class _AuthenticatedOnlyState extends State<AuthenticatedOnly> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final bool authed = await AuthStorage().hasValidAccessToken();
    if (!mounted) return;

    if (!authed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          "/",
          (Route<dynamic> route) => false,
        );
      });
      return;
    }

    setState(() => _allowed = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: (_allowed ?? false)
          ? widget.child
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

