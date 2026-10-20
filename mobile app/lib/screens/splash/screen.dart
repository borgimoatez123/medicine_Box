import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:http/http.dart" as http;

import "../../utils/constants/api_constants.dart";
import "../auth/auth_gate.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _timeout = Duration(seconds: 10);
  bool _showingAlert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHealth();
    });
  }

  Future<void> _checkHealth() async {
    try {
      final http.Response response = await http
          .get(Uri.parse(ApiConstants.healthUrl))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic body = response.body.isNotEmpty
            ? jsonDecode(utf8.decode(response.bodyBytes))
            : null;
        final bool isOk = _isHealthy(body, response.body);
        if (isOk) {
          _navigateToNext();
          return;
        }
      }
      _showConnectionError();
    } on TimeoutException {
      _showConnectionError();
    } on SocketException {
      _showConnectionError();
    } on http.ClientException {
      _showConnectionError();
    } on FormatException {
      _showConnectionError();
    } catch (_) {
      _showConnectionError();
    }
  }

  bool _isHealthy(dynamic decoded, String rawBody) {
    if (decoded is Map<String, dynamic>) {
      final dynamic status = decoded["status"] ?? decoded["health"];
      if (status is String && status.toLowerCase() == "ok") return true;
    }
    if (decoded is String && decoded.toLowerCase() == "ok") return true;
    if (rawBody.trim().toLowerCase() == "ok") return true;
    return false;
  }

  void _navigateToNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AuthGate(),
      ),
    );
  }

  void _showConnectionError() {
    if (!mounted || _showingAlert) return;
    _showingAlert = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Connection Error"),
          content: const Text("you need to content to the server"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showingAlert = false;
                _checkHealth();
              },
              child: const Text("Retry"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            SizedBox(
              width: 120,
              height: 120,
              child: Image(
                image: AssetImage("assets/icons/pills_logo.png"),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
