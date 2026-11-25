import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../state/app_controller.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 14 · Android Lock Screen & Notification Shade interactive preview.
class NotificationPreviewScreen extends StatelessWidget {
  const NotificationPreviewScreen({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$hh:$mm',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 38,
                        height: 42 / 38,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Color(0xFFEDEDF0),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Android Notification Shade · Live Action Preview',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: Text(
                  'Conversations & Alerts',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),

              _AndroidNotifCard(
                urgent: true,
                meta: 'TernaryCode · storefront · 12s',
                title: 'Claude Code wants to run a command',
                body: r'$ npm test -- auth',
                actions: [
                  _NotifAction(
                    label: 'Approve',
                    primary: true,
                    onTap: () {
                      if (controller.isDemoMode) {
                        controller.sendQuickAction(1, 'approve');
                        controller.focusPane(1);
                      } else {
                        controller.showToast(
                          'Preview only — real approvals run from Android notifications',
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  _NotifAction(
                    label: 'Reject',
                    reject: true,
                    onTap: () {
                      if (controller.isDemoMode) {
                        controller.sendQuickAction(1, 'reject');
                      } else {
                        controller.showToast(
                          'Preview only — real rejections run from Android notifications',
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  _NotifAction(
                    label: 'Open',
                    onTap: () {
                      if (controller.isDemoMode) {
                        controller.focusPane(1);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _AndroidNotifCard(
                meta: 'TernaryCode · api-gateway · 2m',
                title: 'claude1 hit its 5-hour limit',
                body: 'Resets in 14m · claude2 (12%) is ready',
                actions: [
                  _NotifAction(
                    label: 'Resume on claude2',
                    primary: true,
                    onTap: () {
                      if (controller.isDemoMode) {
                        controller.switchProfile(2, 'claude2');
                        controller.focusPane(2);
                      } else {
                        controller.showToast(
                          'Preview only — real failover runs from Android notifications',
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  _NotifAction(
                    label: 'Open',
                    onTap: () {
                      if (controller.isDemoMode) {
                        controller.focusPane(2);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: Text(
                  'Silent · Background',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),

              _AndroidNotifCard(
                quiet: true,
                meta:
                    'TernaryCode · Connected to ${controller.activeHost?.name ?? 'MacBook Pro'}',
                body:
                    '${controller.activeHost?.baseUrl ?? 'http://192.168.1.5:7890'} · ${controller.snapshot.panes.length} panes · ${controller.snapshot.waitingCount} waiting',
              ),

              const Spacer(),
              SlateButton(
                label: 'Send real Android test notification',
                variant: SlateButtonVariant.primary,
                height: 40,
                expanded: true,
                onPressed: controller.sendTestApprovalNotification,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Back to app',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEDEDF0),
                          ),
                        ),
                      ),
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

class _AndroidNotifCard extends StatelessWidget {
  const _AndroidNotifCard({
    required this.meta,
    this.title,
    required this.body,
    this.actions = const [],
    this.urgent = false,
    this.quiet = false,
  });

  final String meta;
  final String? title;
  final String body;
  final List<_NotifAction> actions;
  final bool urgent;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: quiet ? 10 : 13),
      decoration: BoxDecoration(
        color: quiet ? const Color(0xFF141417) : const Color(0xFF18181C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent
              ? const Color(0x52F2B14B)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SvgPicture.asset(
                  'assets/brand/icon.svg',
                  width: 15,
                  height: 15,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFFA1A1AA),
                  ),
                ),
              ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 7),
            Text(
              title!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF4F4F5),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            body,
            style: SlateTypography.data(
              SlateColors.dark,
              size: 11.5,
              color: const Color(0xFFA1A1AA),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _NotifAction extends StatelessWidget {
  const _NotifAction({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.reject = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool reject;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? const Color(0xFF2E6BE6)
        : reject
            ? const Color(0x1FF06A64)
            : Colors.white.withValues(alpha: 0.08);
    final fg = primary
        ? Colors.white
        : reject
            ? const Color(0xFFF06A64)
            : const Color(0xFFEDEDF0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
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
