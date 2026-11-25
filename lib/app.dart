import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models/companion_models.dart';
import 'screens/accounts_screen.dart';
import 'screens/fullscreen_terminal_screen.dart';
import 'screens/inbox_detail_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/live_screen.dart';
import 'screens/manual_pair_screen.dart';
import 'screens/notification_preview_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_controller.dart';
import 'theme/slate_theme.dart';
import 'theme/slate_tokens.dart';
import 'widgets/host_switcher_sheet.dart';

/// Root TernaryCode Mobile Flutter app wired to the Slate design system.
class TernaryCodeApp extends StatelessWidget {
  const TernaryCodeApp({
    super.key,
    required this.controller,
    this.disableCameraForTests = false,
  });

  final AppController controller;
  final bool disableCameraForTests;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.settings.themeMode;
        final isDark = mode != ThemeMode.light;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor:
              isDark ? SlateColors.dark.sheet : SlateColors.light.sheet,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'TernaryCode',
          debugShowCheckedModeBanner: false,
          theme: SlateTheme.build(Brightness.light),
          darkTheme: SlateTheme.build(Brightness.dark),
          themeMode: mode,
          home: _RootShell(
            controller: controller,
            disableCameraForTests: disableCameraForTests,
          ),
        );
      },
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({
    required this.controller,
    required this.disableCameraForTests,
  });

  final AppController controller;
  final bool disableCameraForTests;

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> with WidgetsBindingObserver {
  AppController get controller => widget.controller;
  bool get disableCameraForTests => widget.disableCameraForTests;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.onAppLifecycleChanged(state);
  }

  void _openQrScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeCtx) => QrScannerScreen(
          controller: controller,
          cameraDisabled: disableCameraForTests,
          onManualFallback: () {
            Navigator.of(routeCtx).pushReplacement(
              MaterialPageRoute<void>(
                builder: (mCtx) => ManualPairScreen(
                  controller: controller,
                  onPaired: () => Navigator.of(mCtx).popUntil((r) => r.isFirst),
                ),
              ),
            );
          },
          onPaired: () => Navigator.of(routeCtx).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  void _openManualPair(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeCtx) => ManualPairScreen(
          controller: controller,
          onPaired: () => Navigator.of(routeCtx).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  void _openHostSwitcher(BuildContext context) {
    showHostSwitcherSheet(
      context: context,
      controller: controller,
      onPairAnother: () => _openQrScanner(context),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeCtx) => SettingsScreen(
          controller: controller,
          onOpenHosts: () => _openHostSwitcher(routeCtx),
          onOpenShadePreview: () {
            Navigator.of(routeCtx).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationPreviewScreen(
                  controller: controller,
                ),
              ),
            );
          },
          onUnpaired: () => Navigator.of(routeCtx).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, CompanionPane pane) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenTerminalScreen(
          controller: controller,
          paneId: pane.id,
        ),
      ),
    );
  }

  void _openInboxDetail(BuildContext context, CompanionPane pane) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InboxDetailScreen(
          controller: controller,
          paneId: pane.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.bootstrapped) {
          return Scaffold(
            backgroundColor: c.window,
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.accent,
              ),
            ),
          );
        }

        if (!controller.isPaired) {
          return WelcomeScreen(
            onScanQr: () => _openQrScanner(context),
            onManualPair: () => _openManualPair(context),
            onTryDemo: controller.enterDemoMode,
          );
        }

        final snap = controller.snapshot;
        final waiting = snap.waitingCount;
        final urgent = snap.urgentInboxCount;
        final hasErr = snap.panes.any((p) => p.status == 'failed');

        return Scaffold(
          backgroundColor: c.window,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: controller.tabIndex,
                  children: [
                    LiveScreen(
                      controller: controller,
                      onOpenHosts: () => _openHostSwitcher(context),
                      onOpenSettings: () => _openSettings(context),
                      onOpenFullscreen: (pane) =>
                          _openFullscreen(context, pane),
                      onOpenProjects: () => controller.setTab(2),
                      onPairAgain: () => _openQrScanner(context),
                    ),
                    InboxScreen(
                      controller: controller,
                      onOpenHosts: () => _openHostSwitcher(context),
                      onOpenSettings: () => _openSettings(context),
                      onOpenDetail: (pane) => _openInboxDetail(context, pane),
                    ),
                    ProjectsScreen(
                      controller: controller,
                      onOpenHosts: () => _openHostSwitcher(context),
                      onOpenSettings: () => _openSettings(context),
                    ),
                    AccountsScreen(
                      controller: controller,
                      onOpenHosts: () => _openHostSwitcher(context),
                      onOpenSettings: () => _openSettings(context),
                    ),
                  ],
                ),
              ),
              if (controller.toastMessage != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.menu,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.lineStrong),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c.done,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              controller.toastMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SlateTypography.body(c)
                                  .copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _SlateBottomNav(
            currentIndex: controller.tabIndex,
            liveBadge: waiting,
            inboxBadge: urgent,
            inboxHasError: hasErr,
            onSelect: controller.setTab,
          ),
        );
      },
    );
  }
}

class _SlateBottomNav extends StatelessWidget {
  const _SlateBottomNav({
    required this.currentIndex,
    required this.liveBadge,
    required this.inboxBadge,
    required this.inboxHasError,
    required this.onSelect,
  });

  final int currentIndex;
  final int liveBadge;
  final int inboxBadge;
  final bool inboxHasError;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.sheet,
        border: Border(top: BorderSide(color: c.lineSubtle)),
      ),
      padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + bottomPad),
      child: Row(
        children: [
          _NavItem(
            icon: PhosphorIconsRegular.terminalWindow,
            label: 'Live',
            active: currentIndex == 0,
            badgeCount: liveBadge,
            badgeFg: c.input,
            badgeTint: c.inputTint,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: PhosphorIconsRegular.tray,
            label: 'Inbox',
            active: currentIndex == 1,
            badgeCount: inboxBadge,
            badgeFg: inboxHasError ? c.failed : c.input,
            badgeTint: inboxHasError ? c.failedTint : c.inputTint,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: PhosphorIconsRegular.squaresFour,
            label: 'Projects',
            active: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: PhosphorIconsRegular.userCircle,
            label: 'Accounts',
            active: currentIndex == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeFg,
    this.badgeTint,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? badgeFg;
  final Color? badgeTint;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final fg = active ? c.text : c.text3;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: fg),
                  if (badgeCount > 0)
                    Positioned(
                      top: -5,
                      right: -11,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            badgeTint ?? c.inputTint,
                            c.sheet,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: SlateTypography.data(
                            c,
                            size: 10,
                            weight: FontWeight.w600,
                            color: badgeFg ?? c.input,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
