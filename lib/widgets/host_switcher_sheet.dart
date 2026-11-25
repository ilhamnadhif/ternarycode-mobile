import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Screen 04 bottom sheet: switch between paired Mac/Linux/Windows hosts or pair a new one.
Future<void> showHostSwitcherSheet({
  required BuildContext context,
  required AppController controller,
  required VoidCallback onPairAnother,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HostSwitcherBody(
      controller: controller,
      onPairAnother: onPairAnother,
    ),
  );
}

class _HostSwitcherBody extends StatelessWidget {
  const _HostSwitcherBody({
    required this.controller,
    required this.onPairAnother,
  });

  final AppController controller;
  final VoidCallback onPairAnother;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final activeId = controller.activeHost?.id;
        return Container(
      decoration: BoxDecoration(
        color: c.overlay,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.lineStrong)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Computers', style: SlateTypography.title(c, size: 16)),
              const Spacer(),
              SlateIconButton(
                icon: PhosphorIconsRegular.x,
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SlateCard(
            child: Column(
              children: [
                for (var i = 0; i < controller.hosts.length; i++)
                  Builder(builder: (context) {
                    final h = controller.hosts[i];
                    final isActive = h.id == activeId;
                    final meta = h.online
                        ? '${h.baseUrl} · ${h.paneCount} panes${h.latencyMs != null ? ' · ${h.latencyMs} ms' : ''}'
                        : '${h.baseUrl} · offline · ${h.lastSeenLabel}';
                    return SlateRow(
                      showTopDivider: i > 0,
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: h.online ? c.done : c.idle,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              h.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SlateTypography.body(c,
                                  weight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(h.via, style: SlateTypography.data(c)),
                        ],
                      ),
                      monoSubtitle: meta,
                      trailing: isActive
                          ? const SlateTag(label: 'Active')
                          : Text(
                              h.online ? 'Switch' : 'Retry',
                              style: SlateTypography.data(c),
                            ),
                      onTap: () {
                        Navigator.of(context).pop();
                        controller.switchHost(h.id);
                      },
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SlateButton(
            label: 'Pair another computer',
            icon: PhosphorIconsRegular.qrCode,
            variant: SlateButtonVariant.secondary,
            height: 40,
            expanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              onPairAnother();
            },
          ),
        ],
      ),
        );
      },
    );
  }
}

/// Screen 04 background state when the active desktop host is offline or token revoked.
class OfflineHostView extends StatelessWidget {
  const OfflineHostView({
    super.key,
    required this.hostName,
    required this.baseUrl,
    required this.isRevoked,
    required this.retrySeconds,
    required this.onRetry,
    required this.onSwitchHost,
    required this.onPairAgain,
  });

  final String hostName;
  final String baseUrl;
  final bool isRevoked;
  final int retrySeconds;
  final VoidCallback onRetry;
  final VoidCallback onSwitchHost;
  final VoidCallback onPairAgain;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.hover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.lineSubtle),
              ),
              child: Icon(
                isRevoked
                    ? PhosphorIconsRegular.shieldWarning
                    : PhosphorIconsRegular.wifiSlash,
                size: 22,
                color: isRevoked ? c.failed : c.text2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRevoked
                  ? 'Pairing revoked on $hostName'
                  : '$hostName is unreachable',
              textAlign: TextAlign.center,
              style: SlateTypography.body(c, weight: FontWeight.w500)
                  .copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              isRevoked
                  ? 'This phone was removed in Settings → Phone on your computer. Scan a fresh QR code to reconnect.'
                  : 'Retrying $baseUrl${retrySeconds > 0 ? ' in ${retrySeconds}s' : ''}. Check your Wi-Fi or tunnel, or switch to another computer.',
              textAlign: TextAlign.center,
              style: SlateTypography.body2(c),
            ),
            const SizedBox(height: 16),
            if (isRevoked)
              SizedBox(
                width: 220,
                child: SlateButton(
                  label: 'Pair again',
                  icon: PhosphorIconsRegular.qrCode,
                  height: 38,
                  expanded: true,
                  onPressed: onPairAgain,
                ),
              )
            else
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    Expanded(
                      child: SlateButton(
                        label: 'Retry now',
                        variant: SlateButtonVariant.secondary,
                        height: 38,
                        expanded: true,
                        onPressed: onRetry,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SlateButton(
                        label: 'Switch host',
                        variant: SlateButtonVariant.primary,
                        height: 38,
                        expanded: true,
                        onPressed: onSwitchHost,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
