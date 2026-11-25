import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 01 · Welcome & Pair (first-launch entry).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onScanQr,
    required this.onManualPair,
    required this.onTryDemo,
  });

  final VoidCallback onScanQr;
  final VoidCallback onManualPair;
  final VoidCallback onTryDemo;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Scaffold(
      backgroundColor: c.window,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 64, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TernaryCodeMark(size: 52, radius: 12),
              const SizedBox(height: 16),
              Text(
                'Pair with TernaryCode',
                style: SlateTypography.title(c, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'Watch live agent runs, approve commands, switch rate-limited accounts, and resume sessions from your Android phone.',
                style: SlateTypography.body(c).copyWith(
                  fontSize: 13.5,
                  height: 19 / 13.5,
                  color: c.text2,
                ),
              ),
              const SizedBox(height: 22),
              SlateButton(
                label: 'Scan QR code',
                icon: PhosphorIconsRegular.qrCode,
                variant: SlateButtonVariant.primary,
                expanded: true,
                onPressed: onScanQr,
              ),
              const SizedBox(height: 9),
              SlateButton(
                label: 'Enter address & code',
                icon: PhosphorIconsRegular.keyboard,
                variant: SlateButtonVariant.secondary,
                expanded: true,
                onPressed: onManualPair,
              ),
              const SizedBox(height: 20),
              SlateCard(
                child: Column(
                  children: [
                    SlateRow(
                      minHeight: 48,
                      leading: Icon(
                        PhosphorIconsRegular.wifiHigh,
                        size: 16,
                        color: c.accentText,
                      ),
                      title: Text(
                        'Same Wi-Fi, Tailscale, Cloudflare or ngrok',
                        style: SlateTypography.body(c, weight: FontWeight.w500)
                            .copyWith(fontSize: 12.5),
                      ),
                      monoSubtitle: 'Settings → Phone on your computer',
                    ),
                    SlateRow(
                      minHeight: 48,
                      showTopDivider: true,
                      leading: Icon(
                        PhosphorIconsRegular.shieldCheck,
                        size: 16,
                        color: c.done,
                      ),
                      title: Text(
                        'Stored in Android Keystore',
                        style: SlateTypography.body(c, weight: FontWeight.w500)
                            .copyWith(fontSize: 12.5),
                      ),
                      monoSubtitle: 'Per-device token · revoke anytime',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: onTryDemo,
                  style: TextButton.styleFrom(
                    foregroundColor: c.text3,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    'Preview interactive demo without desktop →',
                    style: SlateTypography.body2(c).copyWith(color: c.text3),
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
