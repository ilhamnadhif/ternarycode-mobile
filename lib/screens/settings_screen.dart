import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/update_sheet.dart';

/// Screen 13 · Settings, Android Notifications, Appearance & In-App APK Self-Updater.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onOpenHosts,
    required this.onOpenShadePreview,
    required this.onUnpaired,
  });

  final AppController controller;
  final VoidCallback onOpenHosts;
  final VoidCallback onOpenShadePreview;
  final VoidCallback onUnpaired;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;

  Future<void> _checkUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final info = await widget.controller.checkForApkUpdates(silent: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    await showApkUpdateSheet(
      context: context,
      updater: widget.controller.updater,
      release: info,
      onToast: widget.controller.showToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final host = ctrl.activeHost;
        final s = ctrl.settings;
        final pendingUpdate = ctrl.availableUpdate;
        final hasUpdate = pendingUpdate?.hasUpdate ?? false;

        return Scaffold(
          backgroundColor: c.window,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    SlateIconButton(
                      icon: PhosphorIconsRegular.arrowLeft,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Settings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.title(c, size: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SlateGoButton(
                      label: 'Shade preview',
                      icon: PhosphorIconsRegular.bell,
                      onTap: widget.onOpenShadePreview,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (hasUpdate && pendingUpdate != null) ...[
                  SlateCard(
                    borderColor: c.accent.withValues(alpha: 0.45),
                    child: SlateRow(
                      leading: Icon(
                        PhosphorIconsRegular.arrowCircleDown,
                        size: 18,
                        color: c.accentText,
                      ),
                      title: Text(
                        'Update available · v${pendingUpdate.latestVersion}',
                        style: SlateTypography.body(c, weight: FontWeight.w500),
                      ),
                      monoSubtitle:
                          'Current v${ctrl.appVersion} · tap to download & install',
                      trailing: const SlateTag(label: 'Install'),
                      onTap: () => showApkUpdateSheet(
                        context: context,
                        updater: ctrl.updater,
                        release: pendingUpdate,
                        onToast: ctrl.showToast,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                const SlateSectionLabel('Connection'),
                const SizedBox(height: 8),
                SlateCard(
                  child: Column(
                    children: [
                      SlateRow(
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ctrl.phase == ConnectionPhase.connected
                                ? c.done
                                : c.input,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          host?.name ?? 'No paired computer',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        monoSubtitle: host != null
                            ? '${host.baseUrl} · ${host.via}'
                            : 'Tap to pair',
                        trailing:
                            Text('Switch', style: SlateTypography.data(c)),
                        onTap: widget.onOpenHosts,
                      ),
                      SlateRow(
                        showTopDivider: true,
                        title: Text(
                          'Background keep-alive',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Keep SSE event stream live in background',
                        trailing: SlateSwitch(
                          value: s.keepAlive,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(keepAlive: v)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const SlateSectionLabel('Android notifications'),
                const SizedBox(height: 8),
                SlateCard(
                  child: Column(
                    children: [
                      SlateRow(
                        title: Text(
                          'Needs input (with Approve/Reject)',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Answer agents directly from lock screen',
                        trailing: SlateSwitch(
                          value: s.notifInput,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(notifInput: v)),
                        ),
                      ),
                      SlateRow(
                        showTopDivider: true,
                        title: Text(
                          'Rate limit & failover',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Alert with 1-tap Resume on next account',
                        trailing: SlateSwitch(
                          value: s.notifLimit,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(notifLimit: v)),
                        ),
                      ),
                      SlateRow(
                        showTopDivider: true,
                        title: Text(
                          'Command failed',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Non-zero exits and agent errors',
                        trailing: SlateSwitch(
                          value: s.notifFailed,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(notifFailed: v)),
                        ),
                      ),
                      SlateRow(
                        showTopDivider: true,
                        title: Text(
                          'Haptic feedback',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Tactile confirmation on Approve & Stop',
                        trailing: SlateSwitch(
                          value: s.haptics,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(haptics: v)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const SlateSectionLabel('Appearance'),
                const SizedBox(height: 8),
                SlateCard(
                  padding: const EdgeInsets.all(10),
                  child: SlateSegmented<ThemeMode>(
                    value: s.themeMode == ThemeMode.light
                        ? ThemeMode.light
                        : ThemeMode.dark,
                    items: const [
                      (ThemeMode.dark, 'Dark', null),
                      (ThemeMode.light, 'Light', null),
                    ],
                    onChanged: (mode) =>
                        ctrl.updateSettings(s.copyWith(themeMode: mode)),
                  ),
                ),

                const SizedBox(height: 18),
                const SlateSectionLabel('App & security'),
                const SizedBox(height: 8),
                SlateCard(
                  child: Column(
                    children: [
                      SlateRow(
                        title: Text(
                          'Biometric unlock',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        subtitle: 'Require fingerprint before approving',
                        trailing: SlateSwitch(
                          value: s.biometric,
                          onChanged: (v) =>
                              ctrl.updateSettings(s.copyWith(biometric: v)),
                        ),
                      ),
                      SlateRow(
                        showTopDivider: true,
                        title: Text(
                          'TernaryCode Mobile',
                          style:
                              SlateTypography.body(c, weight: FontWeight.w500),
                        ),
                        monoSubtitle:
                            'v${ctrl.appVersion} · GitHub APK self-updater',
                        trailing: SlateGoButton(
                          label: _checkingUpdate
                              ? 'Checking…'
                              : (hasUpdate ? 'Update' : 'Check'),
                          onTap: _checkUpdates,
                        ),
                        onTap: _checkUpdates,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                SlateButton(
                  label: 'Unpair this device',
                  icon: PhosphorIconsRegular.signOut,
                  variant: SlateButtonVariant.danger,
                  expanded: true,
                  onPressed: () async {
                    await ctrl.unpairActiveHost();
                    if (!context.mounted) return;
                    if (!ctrl.isPaired) {
                      widget.onUnpaired();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
