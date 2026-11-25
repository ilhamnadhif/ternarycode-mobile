import 'package:flutter/material.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 12 · Accounts & Usage Quotas (summary strip, failover policy, ranked 5h/weekly meters).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({
    super.key,
    required this.controller,
    required this.onOpenHosts,
    required this.onOpenSettings,
  });

  final AppController controller;
  final VoidCallback onOpenHosts;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final snap = controller.snapshot;
    final host = controller.activeHost;
    final isAuto = snap.failoverMode == 'auto';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlateTopHeader(
            title: 'Accounts',
            hostName: host?.name ?? 'No host',
            hostOnline: controller.phase == ConnectionPhase.connected,
            hostReconnecting: controller.phase == ConnectionPhase.connecting ||
                controller.phase == ConnectionPhase.reconnecting,
            hasUpdateBadge: controller.availableUpdate?.hasUpdate ?? false,
            onTapHost: onOpenHosts,
            onTapSettings: onOpenSettings,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                // 3-column summary strip
                SlateCard(
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _StatCell(
                          label: 'Running',
                          value: '${snap.runningCount}',
                        ),
                        VerticalDivider(
                            width: 1, thickness: 1, color: c.lineSubtle),
                        _StatCell(
                          label: 'Healthy',
                          value:
                              '${snap.healthyProfileCount}/${snap.profiles.length}',
                          valueColor: c.done,
                        ),
                        VerticalDivider(
                            width: 1, thickness: 1, color: c.lineSubtle),
                        _StatCell(
                          label: '5h tokens',
                          value: formatTokens(snap.total5hTokens),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Failover mode card
                SlateCard(
                  child: SlateRow(
                    title: Text(
                      'Failover mode',
                      style: SlateTypography.body(c, weight: FontWeight.w500),
                    ),
                    subtitle: 'When an account hits its usage limit',
                    trailing: SlateTag(label: isAuto ? 'Automatic' : 'Ask me'),
                    onTap: controller.toggleDemoFailoverMode,
                  ),
                ),
                const SizedBox(height: 14),

                const SlateSectionLabel('Failover order'),
                const SizedBox(height: 8),

                if (snap.profiles.isEmpty)
                  SlateCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No AI agent accounts configured on this host yet.',
                      style: SlateTypography.body2(c),
                    ),
                  )
                else
                  for (var i = 0; i < snap.profiles.length; i++) ...[
                    _AccountQuotaCard(rank: i + 1, profile: snap.profiles[i]),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: c.text3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: SlateTypography.data(
                c,
                size: 15,
                weight: FontWeight.w600,
                color: valueColor ?? c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountQuotaCard extends StatelessWidget {
  const _AccountQuotaCard({
    required this.rank,
    required this.profile,
  });

  final int rank;
  final CompanionProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final w5 = profile.window5h;
    final wk = profile.windowWeekly;

    return SlateCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AgentTile(agent: profile.agentKey),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('#$rank', style: SlateTypography.data(c)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            profile.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SlateTypography.data(
                              c,
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                        ),
                        if (profile.planType != null &&
                            profile.planType!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          SlateTag(label: profile.planType!.toUpperCase()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.accountHint != null &&
                              profile.accountHint!.isNotEmpty
                          ? '${profile.provider} · ${profile.accountHint}'
                          : profile.provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.body2(c),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                status: profile.statusPillKey,
                label: profile.statusPillLabel,
              ),
            ],
          ),
          if (w5 != null) ...[
            const SizedBox(height: 11),
            SlateQuotaMeter(
              label: w5.label,
              usedPct: w5.usedPct ?? 0,
              tokensLabel: formatTokens(w5.tokens),
              resetLabel: formatResetCountdown(w5.resetsAtUnix),
            ),
          ],
          if (wk != null) ...[
            const SizedBox(height: 10),
            SlateQuotaMeter(
              label: wk.label,
              usedPct: wk.usedPct ?? 0,
              tokensLabel: formatTokens(wk.tokens),
              resetLabel: formatResetCountdown(wk.resetsAtUnix),
            ),
          ],
          if (w5 == null && wk == null) ...[
            const SizedBox(height: 10),
            Text(
              'Usage: ${formatTokens(profile.tokensIn + profile.tokensOut)} tokens',
              style: SlateTypography.data(c),
            ),
          ],
          if (profile.activeSession != null &&
              profile.activeSession!.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Active in ${profile.activeSession}',
              style: SlateTypography.data(c),
            ),
          ],
        ],
      ),
    );
  }
}
