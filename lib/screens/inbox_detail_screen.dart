import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/terminal_view.dart';

/// Screen 10 · Inbox Item Detail (full command inspection + live terminal tail).
class InboxDetailScreen extends StatelessWidget {
  const InboxDetailScreen({
    super.key,
    required this.controller,
    required this.paneId,
  });

  final AppController controller;
  final int paneId;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pane = controller.snapshot.panes
                .where((p) => p.id == paneId)
                .firstOrNull ??
            controller.selectedPane;

        if (pane == null) {
          return Scaffold(
            backgroundColor: c.window,
            body: SafeArea(
              child: Center(
                child: SlateButton(
                  label: 'Back to Inbox',
                  variant: SlateButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          );
        }

        final healthy = controller.snapshot.healthyProfilesFor(pane);
        final rawMsg = pane.message ?? pane.statusLabel;
        final split = rawMsg.split('·');
        final toolTag = split.length > 1 ? split.first.trim() : pane.label;
        final cmdBody =
            split.length > 1 ? split.sublist(1).join('·').trim() : rawMsg;

        return Scaffold(
          backgroundColor: c.window,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SlateIconButton(
                        icon: PhosphorIconsRegular.arrowLeft,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      ProjectAvatar(name: pane.projectName, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pane.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SlateTypography.body(c,
                                  weight: FontWeight.w600)
                              .copyWith(fontSize: 14.5),
                        ),
                      ),
                      StatusPill(
                        status: pane.effectiveStatus,
                        label: pane.effectiveStatusLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    pane.rateLimit != null
                        ? '${pane.rateLimit!.fromProfile} hit its usage limit'
                        : pane.status == 'needs_input'
                            ? '${pane.label} wants to run a command'
                            : pane.statusLabel,
                    style: SlateTypography.title(c, size: 17),
                  ),
                  const SizedBox(height: 10),

                  // Command box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.inset,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.line),
                    ),
                    child: Row(
                      children: [
                        Text(r'$ ', style: SlateTypography.data(c, size: 12)),
                        Expanded(
                          child: Text(
                            pane.rateLimit?.reason ?? cmdBody,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SlateTypography.data(c,
                                size: 12, color: c.text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.hover,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            toolTag,
                            style: SlateTypography.data(c, size: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Asked ${pane.age} ago via ${pane.label} hooks · account ${pane.profile ?? 'default'}',
                    style: SlateTypography.data(c),
                  ),
                  const SizedBox(height: 14),

                  // Primary action controls
                  if (pane.status == 'needs_input')
                    Row(
                      children: [
                        Expanded(
                          child: SlateButton(
                            label: 'Approve',
                            variant: SlateButtonVariant.primary,
                            expanded: true,
                            onPressed: () async {
                              await controller.sendQuickAction(
                                  pane.id, 'approve');
                              if (context.mounted) {
                                controller.focusPane(pane.id);
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SlateButton(
                            label: 'Reject',
                            variant: SlateButtonVariant.secondary,
                            expanded: true,
                            onPressed: () async {
                              await controller.sendQuickAction(
                                  pane.id, 'reject');
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SlateButton(
                            label: 'Open Live',
                            variant: SlateButtonVariant.raised,
                            expanded: true,
                            onPressed: () {
                              controller.focusPane(pane.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    )
                  else if (pane.rateLimit != null && healthy.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: SlateButton(
                            label: 'Resume ${healthy.first.id}',
                            icon: PhosphorIconsRegular.arrowsLeftRight,
                            variant: SlateButtonVariant.primary,
                            expanded: true,
                            onPressed: () async {
                              await controller.switchProfile(
                                  pane.id, healthy.first.id);
                              if (context.mounted) {
                                controller.focusPane(pane.id);
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SlateButton(
                            label: 'Open Live',
                            variant: SlateButtonVariant.secondary,
                            expanded: true,
                            onPressed: () {
                              controller.focusPane(pane.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    SlateButton(
                      label: 'Open in Live',
                      variant: SlateButtonVariant.primary,
                      expanded: true,
                      onPressed: () {
                        controller.focusPane(pane.id);
                        Navigator.of(context).pop();
                      },
                    ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SlateSectionLabel('Last lines'),
                      const Spacer(),
                      Text(
                        '● live',
                        style: SlateTypography.data(c, color: c.accentText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: TerminalSheet(
                      pane: pane,
                      fontSize: controller.settings.termFontSize,
                      wrap: controller.settings.termWrap,
                      showHeader: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
