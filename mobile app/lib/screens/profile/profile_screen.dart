import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../controllers/profile_controller.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_text_styles.dart";
import "../settings/screen.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _horizontalPadding = 24;
  static const double _fieldHeight = 58;
  static const double _buttonHeight = 58;
  static const double _radius = 14;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final ProfileController _controller;

  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Uint8List? _pickedImageBytes;
  String? _prefilledUserId;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController()..addListener(_onControllerChanged);
    _controller.loadUserProfile();
  }

  void _onControllerChanged() {
    final user = _controller.user;
    if (user != null && _prefilledUserId == null) {
      _firstnameController.text = user.firstName;
      _lastnameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phone?.trim() ?? "";
      _prefilledUserId = user.id.isNotEmpty ? user.id : "__prefilled__";
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showAvatarSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              _SheetItem(
                icon: Icons.photo_library_rounded,
                title: "Gallery",
                onTap: () async {
                  final XFile? file = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (file == null) return;
                  final Uint8List bytes = await file.readAsBytes();
                  if (!mounted) return;
                  setState(() => _pickedImageBytes = bytes);
                },
              ),
              _SheetItem(
                icon: Icons.photo_camera_rounded,
                title: "Camera",
                onTap: () async {
                  final XFile? file = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (file == null) return;
                  final Uint8List bytes = await file.readAsBytes();
                  if (!mounted) return;
                  setState(() => _pickedImageBytes = bytes);
                },
              ),
              _SheetItem(
                icon: Icons.delete_outline_rounded,
                title: "Remove Photo",
                titleColor: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _pickedImageBytes = null);
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: AppTextStyles.bodyLarge(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSave() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await _controller.updateProfile(
        firstname: _firstnameController.text,
        lastname: _lastnameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showChangePasswordFlow() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_controller.isChangingPassword) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Change Password?"),
          content: const Text("Do you want to change your account password?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dctx) {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        final TextEditingController currentCtrl = TextEditingController();
        final TextEditingController newCtrl = TextEditingController();
        final TextEditingController confirmCtrl = TextEditingController();
        bool showCurrent = false;
        bool showNew = false;
        bool showConfirm = false;

        return StatefulBuilder(
          builder:
              (BuildContext dialogCtx, void Function(VoidCallback) setState) {
                final bool busy = _controller.isChangingPassword;

                InputDecoration passwordDecoration({
                  required String hint,
                  required bool visible,
                  required VoidCallback onToggle,
                }) {
                  return InputDecoration(
                    hintText: hint,
                    suffixIcon: IconButton(
                      onPressed: busy ? null : () => setState(onToggle),
                      icon: Icon(
                        visible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  );
                }

                Future<void> submit() async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (busy) return;

                  try {
                    final String? serverMsg = await _controller.changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
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
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }

                return AlertDialog(
                  scrollable: true,
                  title: const Text("Change Password"),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 52,
                          child: TextFormField(
                            controller: currentCtrl,
                            obscureText: !showCurrent,
                            enabled: !busy,
                            textInputAction: TextInputAction.next,
                            decoration: passwordDecoration(
                              hint: "Current Password",
                              visible: showCurrent,
                              onToggle: () => showCurrent = !showCurrent,
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
                          height: 52,
                          child: TextFormField(
                            controller: newCtrl,
                            obscureText: !showNew,
                            enabled: !busy,
                            textInputAction: TextInputAction.next,
                            decoration: passwordDecoration(
                              hint: "New Password",
                              visible: showNew,
                              onToggle: () => showNew = !showNew,
                            ),
                            validator: (String? value) {
                              final String v = value ?? "";
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
                          height: 52,
                          child: TextFormField(
                            controller: confirmCtrl,
                            obscureText: !showConfirm,
                            enabled: !busy,
                            textInputAction: TextInputAction.done,
                            decoration: passwordDecoration(
                              hint: "Confirm New Password",
                              visible: showConfirm,
                              onToggle: () => showConfirm = !showConfirm,
                            ),
                            validator: (String? value) {
                              final String v = value ?? "";
                              if (v.isEmpty)
                                return "Confirm password is required";
                              if (v != newCtrl.text)
                                return "Passwords do not match";
                              return null;
                            },
                            onFieldSubmitted: (_) => submit(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pop(dialogCtx);
                              currentCtrl.dispose();
                              newCtrl.dispose();
                              confirmCtrl.dispose();
                            },
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: busy ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                      ),
                      child: busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Text("Update Password"),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout?"),
          content: const Text("Are you sure you want to logout?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    await _controller.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil("/login", (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bool busy = _controller.isLoading || _controller.isSaving;
    final String? error = _controller.error;

    final Widget content = _controller.isLoading && _controller.user == null
        ? const Center(child: CircularProgressIndicator())
        : (_controller.user == null && error != null && error.trim().isNotEmpty)
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDEE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      color: AppColors.error,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Unable to load profile.",
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.textSecondary, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _controller.isLoading
                          ? null
                          : () => _controller.loadUserProfile(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Retry",
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
          )
        : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(
                  onCalendar: () {},
                  onSettings: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  avatarImageProvider: _buildSmallHeaderAvatar(),
                ),
                const SizedBox(height: 18),
                Center(
                  child: _ProfileAvatar(
                    imageProvider: _buildMainAvatar(),
                    onEdit: busy ? null : _showAvatarSheet,
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Text(
                    (_controller.user?.fullName ?? "Your Profile").trim(),
                    style: AppTextStyles.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    "Manage your profile information",
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: _fieldHeight,
                  child: TextFormField(
                    controller: _firstnameController,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: "First name"),
                    validator: (String? value) {
                      if ((value ?? "").trim().isEmpty) return "Required";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: _fieldHeight,
                  child: TextFormField(
                    controller: _lastnameController,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: "Last name"),
                    validator: (String? value) {
                      if ((value ?? "").trim().isEmpty) return "Required";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: _fieldHeight,
                  child: TextFormField(
                    controller: _emailController,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: "Email"),
                    validator: (String? value) {
                      final String v = (value ?? "").trim();
                      if (v.isEmpty) return "Required";
                      final RegExp emailRegex = RegExp(
                        r"^[^\s@]+@[^\s@]+\.[^\s@]+$",
                      );
                      if (!emailRegex.hasMatch(v)) return "Invalid email";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: _fieldHeight,
                  child: TextFormField(
                    controller: _phoneController,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: "Phone (e.g. +21620123456)",
                    ),
                    validator: (String? value) {
                      final String v = (value ?? "").trim();
                      if (v.isEmpty) return null;
                      final String digits = v.replaceAll(RegExp(r"[^0-9]"), "");
                      if (digits.isNotEmpty && digits.length < 6) {
                        return "Phone must have at least 6 digits";
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: _buttonHeight,
                  child: ElevatedButton(
                    onPressed: busy ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                    ),
                    child: _controller.isSaving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            "Save",
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.background,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: busy ? null : _confirmLogout,
                    child: Text(
                      "Sign Out",
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Account",
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _AccountTile(
                  icon: Icons.lock_rounded,
                  title: "Change Password",
                  onTap: busy ? null : _showChangePasswordFlow,
                ),
                if ((_controller.error ?? "").trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    _controller.error!,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            _horizontalPadding,
            0,
            _horizontalPadding,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildSmallHeaderAvatar() {
    final ImageProvider<Object>? main = _buildMainAvatar();
    return main;
  }

  ImageProvider<Object>? _buildMainAvatar() {
    final Uint8List? bytes = _pickedImageBytes;
    if (bytes != null) {
      return MemoryImage(bytes);
    }

    final String? url = _controller.user?.profileImage;
    if (url != null && url.trim().isNotEmpty) {
      return NetworkImage(url.trim());
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onCalendar,
    required this.onSettings,
    required this.avatarImageProvider,
  });

  final VoidCallback onCalendar;
  final VoidCallback onSettings;
  final ImageProvider<Object>? avatarImageProvider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: <Widget>[
          _CircleIconButton(
            icon: Icons.calendar_month_rounded,
            onPressed: onCalendar,
          ),
          Expanded(
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF4FA),
                backgroundImage: avatarImageProvider,
                child: avatarImageProvider == null
                    ? Icon(Icons.person_rounded, color: AppColors.primary)
                    : null,
              ),
            ),
          ),
          _CircleIconButton(
            icon: Icons.settings_rounded,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
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
          child: Icon(icon, color: AppColors.icon, size: 22),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageProvider, required this.onEdit});

  final ImageProvider<Object>? imageProvider;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Hero(
          tag: "profile_avatar",
          child: CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFFEFF4FA),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Icon(Icons.person_rounded, size: 48, color: AppColors.primary)
                : null,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEdit,
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge(context).copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
    );
  }
}
