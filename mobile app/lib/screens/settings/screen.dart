import "package:flutter/material.dart";

import "../../controllers/notification_controller.dart";
import "../../controllers/settings_controller.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_palette.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "../../utils/app_text_styles.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsController _controller = SettingsController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationController.instance.refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.icon),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: "Back",
        ),
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _controller,
            NotificationController.instance,
          ]),
          builder: (BuildContext c, Widget? _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionHeader(
                    title: "Appearance",
                    subtitle: "Choose how the app looks on this device.",
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionCard(
                    palette: palette,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            _TileIcon(
                              icon: Icons.dark_mode_outlined,
                              palette: palette,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    "Theme",
                                    style: AppTextStyles.bodyLarge(c).copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _subtitleForMode(_controller.themeMode),
                                    style: AppTextStyles.bodySmall(c).copyWith(
                                      color: palette.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LayoutBuilder(
                          builder: (BuildContext ctx, BoxConstraints bc) {
                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: _ThemeSegmentedButton(
                                    selected: _controller.themeMode,
                                    onChanged: (ThemeMode mode) =>
                                        _controller.setThemeMode(mode),
                                    palette: palette,
                                    width: bc.maxWidth,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: "General",
                    subtitle: "Localization, notifications, and data.",
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionCard(
                    palette: palette,
                    child: Column(
                      children: <Widget>[
                        _PlaceholderTile(
                          icon: Icons.translate_outlined,
                          title: "Language",
                          trailing: "English",
                          palette: palette,
                          onTap: _notImplemented,
                        ),
                        const Divider(height: 1),
                        _NotificationsTile(palette: palette),
                        const Divider(height: 1),
                        _PlaceholderTile(
                          icon: Icons.storage_outlined,
                          title: "Clear local cache",
                          trailing: "3.2 MB",
                          palette: palette,
                          onTap: _notImplemented,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: "About",
                    subtitle: "Version, support, and legal info.",
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionCard(
                    palette: palette,
                    child: Column(
                      children: <Widget>[
                        _PlaceholderTile(
                          icon: Icons.info_outline_rounded,
                          title: "App version",
                          trailing: "1.0.0",
                          palette: palette,
                          enabled: false,
                        ),
                        const Divider(height: 1),
                        _PlaceholderTile(
                          icon: Icons.help_outline_rounded,
                          title: "Help & support",
                          trailing: "",
                          palette: palette,
                          onTap: _notImplemented,
                        ),
                        const Divider(height: 1),
                        _PlaceholderTile(
                          icon: Icons.gavel_outlined,
                          title: "Privacy policy",
                          trailing: "",
                          palette: palette,
                          onTap: _notImplemented,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _subtitleForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "Matches your device's system theme.";
      case ThemeMode.light:
        return "Always use the light color palette.";
      case ThemeMode.dark:
        return "Always use the dark color palette.";
    }
  }

  void _notImplemented() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Coming soon."),
        backgroundColor: AppColors.of(context).secondaryBackground,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTextStyles.titleMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w800, color: palette.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: palette.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.palette, required this.child});

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBackground,
        border: Border.all(color: palette.border),
        borderRadius: AppRadius.br16,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.palette});

  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: palette.primary, size: 22),
    );
  }
}

class _ThemeSegmentedButton extends StatelessWidget {
  const _ThemeSegmentedButton({
    required this.selected,
    required this.onChanged,
    required this.palette,
    required this.width,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  final AppPalette palette;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Color onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      label: "Theme selector",
      child: SegmentedButton<ThemeMode>(
        segments: <ButtonSegment<ThemeMode>>[
          ButtonSegment<ThemeMode>(
            value: ThemeMode.system,
            label: Text(
              "System",
              style: _labelStyle(context, selected == ThemeMode.system),
            ),
            icon: Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: selected == ThemeMode.system ? onPrimary : palette.icon,
            ),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.light,
            label: Text(
              "Light",
              style: _labelStyle(context, selected == ThemeMode.light),
            ),
            icon: Icon(
              Icons.light_mode_outlined,
              size: 18,
              color: selected == ThemeMode.light ? onPrimary : palette.icon,
            ),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.dark,
            label: Text(
              "Dark",
              style: _labelStyle(context, selected == ThemeMode.dark),
            ),
            icon: Icon(
              Icons.dark_mode_outlined,
              size: 18,
              color: selected == ThemeMode.dark ? onPrimary : palette.icon,
            ),
          ),
        ],
        selected: <ThemeMode>{selected},
        onSelectionChanged: (Set<ThemeMode> next) {
          if (next.isEmpty) return;
          onChanged(next.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> s) => s.contains(WidgetState.selected)
                ? palette.primary
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> s) => s.contains(WidgetState.selected)
                ? onPrimary
                : palette.textSecondary,
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: palette.border, width: 1),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadius.br14),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          ),
          splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
        ),
      ),
    );
  }

  TextStyle _labelStyle(BuildContext c, bool selected) {
    final Color onPrimary = Theme.of(c).colorScheme.onPrimary;
    return AppTextStyles.labelMedium(c).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: selected ? onPrimary : palette.textSecondary,
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.palette,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final AppPalette palette;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isTappable = enabled && onTap != null;
    return InkWell(
      onTap: isTappable ? onTap : null,
      borderRadius: AppRadius.br12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(
          children: <Widget>[
            _TileIcon(icon: icon, palette: palette),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: enabled ? palette.textPrimary : palette.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.secondaryBackground,
                  border: Border.all(color: palette.border),
                  borderRadius: AppRadius.br999,
                ),
                child: Text(
                  trailing,
                  style: AppTextStyles.labelMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (isTappable)
              Icon(Icons.chevron_right_rounded, color: palette.icon),
          ],
        ),
      ),
    );
  }
}

class _NotificationsTile extends StatelessWidget {
  const _NotificationsTile({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final NotificationController nc = NotificationController.instance;
    final bool? enabled = nc.enabledSnapshot;
    final bool loading = nc.permissionsLoading;

    final String label;
    final Color badgeColor;
    final Color badgeTextColor;
    if (loading) {
      label = "Checking";
      badgeColor = palette.secondaryBackground;
      badgeTextColor = palette.textSecondary;
    } else if (enabled == true) {
      label = "Enabled";
      badgeColor = palette.success.withValues(alpha: 0.12);
      badgeTextColor = palette.success;
    } else if (enabled == false) {
      label = "Disabled";
      badgeColor = palette.warning.withValues(alpha: 0.12);
      badgeTextColor = palette.warning;
    } else {
      label = "Unknown";
      badgeColor = palette.secondaryBackground;
      badgeTextColor = palette.textSecondary;
    }

    return InkWell(
      onTap: loading
          ? null
          : () async {
              try {
                await nc.requestPermissions(ifNotPromptedOnly: true);
                await nc.refreshStatus();
              } catch (_) {}
            },
      borderRadius: AppRadius.br12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(
          children: <Widget>[
            _TileIcon(
              icon: Icons.notifications_active_outlined,
              palette: palette,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Notifications",
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading
                        ? "Checking permissions…"
                        : enabled == true
                        ? "Medication reminders are on."
                        : "Tap to enable medication reminders.",
                    style: AppTextStyles.bodySmall(
                      context,
                    ).copyWith(color: palette.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            if (loading) ...<Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.xs),
            ] else ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  border: Border.all(color: palette.border),
                  borderRadius: AppRadius.br999,
                ),
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Icon(Icons.chevron_right_rounded, color: palette.icon),
          ],
        ),
      ),
    );
  }
}
