import "package:flutter/material.dart";

import "../../controllers/profile_controller.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_text_styles.dart";

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const double _padding = 24;
  static const double _buttonHeight = 58;

  late final ProfileController _controller;
  bool _confirmed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_confirmed) return;
    if (_isSubmitting) return;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text("This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _isSubmitting = true);
    try {
      await _controller.deleteAccount();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil("/login", (Route<dynamic> route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              _BackIcon(onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDEE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Delete Account",
                style: AppTextStyles.headlineMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w800, color: AppColors.error),
              ),
              const SizedBox(height: 10),
              Text(
                "Deleting your account is permanent.\n\nThis action cannot be undone.\n\nAll medications, reminders, history and profile information will be permanently removed.",
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF0F2F5)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Checkbox(
                          value: _confirmed,
                          onChanged: (bool? v) =>
                              setState(() => _confirmed = v ?? false),
                          activeColor: AppColors.error,
                        ),
                        Expanded(
                          child: Text(
                            "I understand this action is irreversible.",
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: _buttonHeight,
                child: ElevatedButton(
                  onPressed: (_confirmed && !_isSubmitting) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          "Delete Account",
                          style: AppTextStyles.bodyLarge(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.background,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({required this.onPressed});

  final VoidCallback onPressed;

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
