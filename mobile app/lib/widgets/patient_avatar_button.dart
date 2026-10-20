import "dart:io";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../controllers/patient_controller.dart";
import "../models/patient.dart";
import "../utils/app_colors.dart";
import "../utils/app_radius.dart";
import "../utils/app_spacing.dart";

enum _AvatarAction { gallery, camera, delete }

class PatientAvatarButton extends StatefulWidget {
  const PatientAvatarButton({
    super.key,
    required this.controller,
    this.patientId,
    this.patient,
    this.size = 120,
    this.borderWidth = 4,
    this.enabled = true,
    this.onAvatarChanged,
  });

  final PatientController controller;
  final String? patientId;
  final Patient? patient;
  final double size;
  final double borderWidth;
  final bool enabled;
  final ValueChanged<String?>? onAvatarChanged;

  @override
  State<PatientAvatarButton> createState() => _PatientAvatarButtonState();
}

class _PatientAvatarButtonState extends State<PatientAvatarButton> {
  static const int maxBytes = 5 * 1024 * 1024;

  bool _picking = false;

  String get _effectiveId =>
      (widget.patientId ?? widget.patient?.id ?? "").trim();

  String? get _avatarUrl {
    final String id = _effectiveId;
    if (widget.patient != null) {
      final String? direct = widget.patient!.avatarUrl?.trim();
      if ((direct ?? "").isNotEmpty) return direct;
    }
    if (id.isEmpty) return null;
    final Patient? found = widget.controller.findById(id);
    final String? u = found?.avatarUrl?.trim();
    return (u ?? "").isEmpty ? null : u;
  }

  String get _initials {
    if (widget.patient != null) return widget.patient!.initialsDisplay;
    final String id = _effectiveId;
    if (id.isNotEmpty) {
      final Patient? found = widget.controller.findById(id);
      if (found != null) return found.initialsDisplay;
    }
    return "?";
  }

  String get _displayName {
    if (widget.patient != null) return widget.patient!.fullNameDisplay;
    final String id = _effectiveId;
    if (id.isNotEmpty) {
      final Patient? found = widget.controller.findById(id);
      if (found != null) return found.fullNameDisplay;
    }
    return "Patient";
  }

  Widget _initialsAvatar({
    Key? key,
    required String initials,
    required double size,
  }) {
    final String text = initials.trim().isEmpty ? "?" : initials;
    final double fSize = (size * 0.32).clamp(18.0, 64.0);
    return Container(
      key: key,
      width: size,
      height: size,
      color: AppColors.primary.withOpacity(0.12),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: fSize,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (!widget.enabled) return;
    final String id = _effectiveId;
    if (id.isEmpty) {
      _showError("Save the patient first before uploading an avatar.");
      return;
    }
    if (_picking || widget.controller.isUploadingAvatarFor(id)) return;
    setState(() => _picking = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted) return;
      if (picked == null) return;
      int bytes = 0;
      try {
        bytes = await picked.length();
      } catch (_) {
        bytes = 0;
      }
      if (bytes > maxBytes) {
        _showError("File too large. Maximum is 5 MB.");
        return;
      }
      final File file = File(picked.path);
      if (!file.existsSync()) {
        _showError("Selected image file does not exist.");
        return;
      }
      final dynamic result = await widget.controller.uploadPatientAvatar(
        id,
        file,
      );
      if (!mounted) return;
      final String? nextUrl =
          // ignore: avoid_dynamic_calls
          result?.avatarUrl as String? ?? _avatarUrl;
      widget.onAvatarChanged?.call(nextUrl);
      _showSuccess("Avatar updated.");
    } on PatientControllerException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError("Unable to upload avatar right now.");
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _confirmDelete() async {
    final String id = _effectiveId;
    if (id.isEmpty) return;
    final String name = _displayName;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
          title: const Text("Remove patient avatar?"),
          content: Text("The avatar for $name will be removed."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      await widget.controller.deletePatientAvatar(id);
      if (!mounted) return;
      widget.onAvatarChanged?.call(null);
      _showSuccess("Avatar removed.");
    } on PatientControllerException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError("Unable to remove avatar right now.");
    }
  }

  Future<void> _showActions() async {
    if (!widget.enabled) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size screen = MediaQuery.of(context).size;
    final RelativeRect position = box == null
        ? RelativeRect.fromLTRB(
            screen.width / 2 - 80,
            screen.height / 2,
            screen.width / 2 + 80,
            screen.height / 2,
          )
        : RelativeRect.fromRect(
            Rect.fromPoints(
              box.localToGlobal(Offset.zero),
              box.localToGlobal(box.size.bottomCenter(Offset.zero)),
            ),
            Offset.zero & screen,
          );
    final bool hasAvatar = (_avatarUrl ?? "").isNotEmpty;
    final _AvatarAction? picked = await showMenu<_AvatarAction>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
      items: <PopupMenuEntry<_AvatarAction>>[
        PopupMenuItem<_AvatarAction>(
          value: _AvatarAction.gallery,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.photo_library_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text("Choose from gallery"),
            ],
          ),
        ),
        PopupMenuItem<_AvatarAction>(
          value: _AvatarAction.camera,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.photo_camera_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text("Take a photo"),
            ],
          ),
        ),
        if (hasAvatar)
          PopupMenuItem<_AvatarAction>(
            value: _AvatarAction.delete,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text("Remove avatar", style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
      ],
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case _AvatarAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
        break;
      case _AvatarAction.camera:
        await _pickAndUpload(ImageSource.camera);
        break;
      case _AvatarAction.delete:
        await _confirmDelete();
        break;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String id = _effectiveId;
    final bool busy =
        _picking ||
        widget.controller.isUploadingAvatarFor(id) ||
        widget.controller.isDeletingAvatarFor(id);
    final double outer = widget.size + (widget.borderWidth * 2);

    return GestureDetector(
      onTap: widget.enabled ? _showActions : null,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.9,
        child: SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            children: <Widget>[
              AnimatedBuilder(
                animation: widget.controller,
                builder: (BuildContext c, Widget? _) {
                  final String? url = _avatarUrl;
                  final bool hasAvatar = (url ?? "").isNotEmpty;
                  final String sId = "avatar-$id-${url ?? 'no'}";
                  return Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border,
                        width: widget.borderWidth,
                      ),
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: ClipOval(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: hasAvatar
                                ? Image.network(
                                    url!,
                                    key: ValueKey<String>(sId),
                                    width: widget.size,
                                    height: widget.size,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          BuildContext _,
                                          Object __,
                                          StackTrace? ___,
                                        ) {
                                          return _initialsAvatar(
                                            initials: _initials,
                                            size: widget.size,
                                          );
                                        },
                                    loadingBuilder:
                                        (
                                          BuildContext _,
                                          Widget child,
                                          ImageChunkEvent? progress,
                                        ) {
                                          if (progress == null) return child;
                                          final int? expected =
                                              progress.expectedTotalBytes;
                                          final double? value =
                                              (expected == null ||
                                                  expected <= 0)
                                              ? null
                                              : progress.cumulativeBytesLoaded /
                                                    expected;
                                          return Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                value: value,
                                              ),
                                            ),
                                          );
                                        },
                                  )
                                : _initialsAvatar(
                                    key: ValueKey<String>("noavatar-$id"),
                                    initials: _initials,
                                    size: widget.size,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.enabled)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (busy)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    width: outer,
                    height: outer,
                    color: Colors.black38,
                  ),
                ),
              if (busy)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
