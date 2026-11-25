import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Slate bottom sheet for spawning a new AI agent (or terminal) inside any project.
Future<void> showSpawnAgentSheet({
  required BuildContext context,
  required AppController controller,
  required CompanionProject project,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SpawnAgentBody(
      controller: controller,
      project: project,
    ),
  );
}

class _AgentOption {
  const _AgentOption(this.slug, this.label, this.supportsProfiles);
  final String slug;
  final String label;
  final bool supportsProfiles;
}

class _SpawnAgentBody extends StatefulWidget {
  const _SpawnAgentBody({
    required this.controller,
    required this.project,
  });

  final AppController controller;
  final CompanionProject project;

  @override
  State<_SpawnAgentBody> createState() => _SpawnAgentBodyState();
}

class _SpawnAgentBodyState extends State<_SpawnAgentBody> {
  static const List<_AgentOption> _agents = [
    _AgentOption('claude', 'Claude Code', true),
    _AgentOption('codex', 'Codex', true),
    _AgentOption('antigravity', 'Antigravity', true),
    _AgentOption('opencode', 'OpenCode', false),
    _AgentOption('gemini', 'Gemini CLI', false),
    _AgentOption('shell', 'Terminal', false),
  ];

  String _selectedAgent = 'claude';
  String? _selectedProfileId; // null = Auto (best healthy account)
  bool _starting = false;

  _AgentOption get _activeOption =>
      _agents.firstWhere((a) => a.slug == _selectedAgent);

  List<CompanionProfile> get _matchingProfiles {
    if (!_activeOption.supportsProfiles) return const [];
    return widget.controller.snapshot.profiles
        .where((p) => p.enabled && p.agentKey == _selectedAgent)
        .toList();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    Navigator.of(context).pop();
    await widget.controller.spawnAgent(
      project: widget.project,
      agent: _selectedAgent,
      profileId: _selectedProfileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final profiles = _matchingProfiles;
    final bottomPad = MediaQuery.of(context).padding.bottom;

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
              ProjectAvatar(name: widget.project.name, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New agent',
                      style: SlateTypography.title(c, size: 16),
                    ),
                    Text(
                      widget.project.branch != null &&
                              widget.project.branch!.isNotEmpty
                          ? '${widget.project.name} · ${widget.project.branch}'
                          : widget.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.data(c),
                    ),
                  ],
                ),
              ),
              SlateIconButton(
                icon: PhosphorIconsRegular.x,
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SlateSectionLabel('Agent'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.3,
            children: [
              for (final opt in _agents)
                Builder(builder: (_) {
                  final on = _selectedAgent == opt.slug;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAgent = opt.slug;
                          _selectedProfileId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: on ? c.accentTint : c.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: on ? c.accent : c.lineSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            AgentTile(agent: opt.slug, size: 24),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                opt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SlateTypography.body(
                                  c,
                                  weight:
                                      on ? FontWeight.w600 : FontWeight.w500,
                                ).copyWith(
                                  fontSize: 12.5,
                                  color: on ? c.text : c.text2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),

          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SlateSectionLabel('Account'),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ProfileChip(
                    label: 'Auto',
                    detail: 'best healthy',
                    selected: _selectedProfileId == null,
                    onTap: () => setState(() => _selectedProfileId = null),
                  ),
                  for (final pr in profiles) ...[
                    const SizedBox(width: 6),
                    _ProfileChip(
                      label: pr.id,
                      detail: pr.state == 'rate_limited'
                          ? 'limited'
                          : pr.window5h?.usedPct != null
                              ? '${pr.window5h!.usedPct!.round()}%'
                              : pr.statusPillLabel.toLowerCase(),
                      warn: pr.state == 'rate_limited',
                      selected: _selectedProfileId == pr.id,
                      onTap: () => setState(() => _selectedProfileId = pr.id),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          SlateButton(
            label: 'Start ${_activeOption.label}',
            icon: PhosphorIconsRegular.play,
            variant: SlateButtonVariant.primary,
            expanded: true,
            busy: _starting,
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : c.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.accent : c.lineSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: SlateTypography.data(
                  c,
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: selected ? c.accentText : c.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                detail,
                style: SlateTypography.data(
                  c,
                  size: 10.5,
                  color: warn ? c.limited : c.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
