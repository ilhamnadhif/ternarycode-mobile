import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 09 · Inbox Attention Queue (oldest-first triage with inline quick actions).
class InboxScreen extends StatelessWidget {
  const InboxScreen({
    super.key,
    required this.controller,
    required this.onOpenHosts,
    required this.onOpenSettings,
    required this.onOpenDetail,
  });

  final AppController controller;
  final VoidCallback onOpenHosts;
  final VoidCallback onOpenSettings;
  final ValueChanged<CompanionPane> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final snap = controller.snapshot;
    final host = controller.activeHost;
    final filter = controller.inboxFilter;

    final urgent = snap.panes.where((p) => p.isUrgent).toList();
    final donePanes = snap.panes.where((p) => p.status == 'done').toList();
    final infoAlerts = snap.alerts.where((a) => a.level == 'info').toList();
    final finishedCount = donePanes.length + infoAlerts.length;
    final total = urgent.length + finishedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlateTopHeader(
            title: 'Inbox',
            hostName: host?.name ?? 'No host',
            hostOnline: controller.phase == ConnectionPhase.connected,
            hostReconnecting: controller.phase == ConnectionPhase.connecting ||
                controller.phase == ConnectionPhase.reconnecting,
            hasUpdateBadge: controller.availableUpdate?.hasUpdate ?? false,
            onTapHost: onOpenHosts,
            onTapSettings: onOpenSettings,
          ),
          const SizedBox(height: 12),
          SlateSegmented<InboxFilter>(
            value: filter,
            items: [
              (InboxFilter.all, 'All', total),
              (InboxFilter.needsYou, 'Needs you', urgent.length),
              (InboxFilter.finished, 'Finished', finishedCount),
            ],
            onChanged: controller.setInboxFilter,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                if (filter != InboxFilter.finished) ...[
                  if (urgent.isNotEmpty) ...[
                    const SlateSectionLabel('Needs you · oldest first'),
                    const SizedBox(height: 8),
                    for (final pane in urgent) ...[
                      _UrgentInboxCard(
                        pane: pane,
                        nextProfile: snap.healthyProfilesFor(pane).firstOrNull,
                        onTap: () => onOpenDetail(pane),
                        onApprove: () =>
                            controller.sendQuickAction(pane.id, 'approve'),
                        onReject: () =>
                            controller.sendQuickAction(pane.id, 'reject'),
                        onFailover: (profId) =>
                            controller.switchProfile(pane.id, profId),
                        onDismissLimit: () =>
                            controller.dismissRateLimit(pane.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ] else if (filter == InboxFilter.needsYou)
                    _CaughtUpBox(
                      title: 'Nothing waiting for you',
                      subtitle:
                          'All running agents are progressing without prompts or rate limits.',
                    ),
                ],
                if (filter != InboxFilter.needsYou) ...[
                  if (finishedCount > 0) ...[
                    const SizedBox(height: 4),
                    const SlateSectionLabel('Finished'),
                    const SizedBox(height: 8),
                    for (final pane in donePanes) ...[
                      _FinishedCard(
                        project: pane.projectName,
                        who: pane.label,
                        summary: pane.message ?? 'Run completed cleanly',
                        age: 'now',
                        onTap: () => controller.focusPane(pane.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final alert in infoAlerts) ...[
                      Builder(builder: (_) {
                        final parts = alert.message.split(':');
                        final proj = parts.length > 1
                            ? parts.first.trim()
                            : (alert.profile ?? 'workspace');
                        final msg = parts.length > 1
                            ? parts.sublist(1).join(':').trim()
                            : alert.message;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FinishedCard(
                            project: proj,
                            who: alert.profile ?? 'Agent',
                            summary: msg,
                            age: alert.time.length >= 5
                                ? alert.time.substring(0, 5)
                                : alert.time,
                            onTap: () => controller.openAlertProject(proj),
                          ),
                        );
                      }),
                    ],
                  ] else if (filter == InboxFilter.finished)
                    _CaughtUpBox(
                      title: 'No finished runs yet',
                      subtitle:
                          'Completed agent runs and summaries appear here.',
                    ),
                ],
                if (filter == InboxFilter.all && total == 0)
                  _CaughtUpBox(
                    title: 'All clear',
                    subtitle:
                        'When an agent asks for approval, hits a limit, or finishes, it shows up here.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentInboxCard extends StatelessWidget {
  const _UrgentInboxCard({
    required this.pane,
    required this.nextProfile,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onFailover,
    required this.onDismissLimit,
  });

  final CompanionPane pane;
  final CompanionProfile? nextProfile;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<String> onFailover;
  final VoidCallback onDismissLimit;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final isAsk = pane.status == 'needs_input';
    final isLimited = pane.rateLimit != null;

    final subtitle = isLimited
        ? '${pane.rateLimit!.fromProfile} hit 5h limit · resets in ${pane.rateLimit!.resetsInLabel}'
        : (pane.message ?? pane.statusLabel);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAsk ? c.input.withValues(alpha: 0.28) : c.lineSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProjectAvatar(name: pane.projectName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusGlyph(
                              status: pane.effectiveStatus,
                              size: 13,
                              animate: false,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                pane.projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SlateTypography.body(c,
                                    weight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(pane.label, style: SlateTypography.data(c)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SlateTypography.body2(c),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(pane.age, style: SlateTypography.data(c)),
                ],
              ),
              if (isAsk) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Row(
                    children: [
                      SlateButton(
                        label: 'Approve',
                        height: 30,
                        variant: SlateButtonVariant.primary,
                        onPressed: onApprove,
                      ),
                      const SizedBox(width: 7),
                      SlateButton(
                        label: 'Reject',
                        height: 30,
                        variant: SlateButtonVariant.secondary,
                        onPressed: onReject,
                      ),
                    ],
                  ),
                ),
              ] else if (isLimited) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Row(
                    children: [
                      if (nextProfile != null) ...[
                        SlateButton(
                          label: 'Resume on ${nextProfile!.id}',
                          height: 30,
                          variant: SlateButtonVariant.primary,
                          onPressed: () => onFailover(nextProfile!.id),
                        ),
                        const SizedBox(width: 7),
                      ],
                      SlateButton(
                        label: 'Dismiss',
                        height: 30,
                        variant: SlateButtonVariant.secondary,
                        onPressed: onDismissLimit,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({
    required this.project,
    required this.who,
    required this.summary,
    required this.age,
    required this.onTap,
  });

  final String project;
  final String who;
  final String summary;
  final String age;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.lineSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectAvatar(name: project),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const StatusGlyph(
                            status: 'done', size: 13, animate: false),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            project,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SlateTypography.body(c,
                                weight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(who, style: SlateTypography.data(c)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.body2(c),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(age, style: SlateTypography.data(c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaughtUpBox extends StatelessWidget {
  const _CaughtUpBox({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.hover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.lineSubtle),
            ),
            child: Icon(PhosphorIconsRegular.checkCircle,
                size: 22, color: c.done),
          ),
          const SizedBox(height: 12),
          Text(title, style: SlateTypography.body(c, weight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: SlateTypography.body2(c),
          ),
        ],
      ),
    );
  }
}
