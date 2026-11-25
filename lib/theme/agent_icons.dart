import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'slate_tokens.dart';

/// Brand vector SVGs for agents whose marks are crisp monochrome/brand vectors.
class AgentBrandSvg {
  static const String claude =
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#D97757" d="m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"/></svg>';

  static const String codex =
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#FFFFFF" d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"/></svg>';

  static const String opencode =
      '<svg viewBox="0 0 240 300" xmlns="http://www.w3.org/2000/svg"><path fill="#FFFFFF" d="M180 60H60V240H180V60ZM240 300H0V0H240V300Z"/><path fill="#FFFFFF" fill-opacity=".28" d="M180 240H60V120H180V240Z"/></svg>';
}

/// Colour + shape paired status glyph matching TernaryCode's Slate spec.
class StatusGlyph extends StatefulWidget {
  const StatusGlyph({
    super.key,
    required this.status,
    this.size = 13,
    this.animate = true,
  });

  final String status;
  final double size;
  final bool animate;

  @override
  State<StatusGlyph> createState() => _StatusGlyphState();
}

class _StatusGlyphState extends State<StatusGlyph>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  bool get _shouldSpin => widget.status == 'running' && widget.animate;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant StatusGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.animate != widget.animate) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (_shouldSpin) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat();
    } else {
      _ctrl?.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'running':
        return PhosphorIconsRegular.circleNotch;
      case 'needs_input':
        return PhosphorIconsFill.chatCircleDots;
      case 'done':
        return PhosphorIconsFill.checkCircle;
      case 'failed':
      case 'error':
        return PhosphorIconsFill.xCircle;
      case 'rate_limited':
        return PhosphorIconsRegular.hourglassMedium;
      case 'cooldown':
        return PhosphorIconsRegular.clock;
      default:
        return PhosphorIconsRegular.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final (fg, _) = c.statusTone(widget.status);
    final icon = Icon(_iconFor(widget.status), size: widget.size, color: fg);

    if (_ctrl == null) return icon;
    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (_, child) =>
          Transform.rotate(angle: _ctrl!.value * 2 * math.pi, child: child),
      child: icon,
    );
  }
}

/// Compact pill with paired colour + shape status glyph.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    required this.label,
    this.animate = true,
  });

  final String status;
  final String label;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final (fg, tint) = c.statusTone(status);
    return Container(
      height: 21,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusGlyph(status: status, size: 12, animate: animate),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 22×22 rounded square holding the authentic agent brand logo.
class AgentTile extends StatelessWidget {
  const AgentTile({super.key, required this.agent, this.size = 22});

  final String agent;
  final double size;

  static String normalizeAgent(String? raw) {
    final v = (raw ?? '').toLowerCase();
    if (v.contains('claude')) return 'claude';
    if (v.contains('codex') || v.contains('chatgpt') || v.contains('openai')) {
      return 'codex';
    }
    if (v.contains('opencode')) return 'opencode';
    if (v.contains('antigravity') || v.contains('agy')) return 'antigravity';
    if (v.contains('gemini')) return 'gemini';
    return 'shell';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final kind = normalizeAgent(agent);
    final inner = size * 0.60;

    Widget child;
    if (kind == 'claude') {
      child = SvgPicture.string(
        AgentBrandSvg.claude,
        width: inner,
        height: inner,
      );
    } else if (kind == 'codex') {
      child = SvgPicture.string(
        AgentBrandSvg.codex,
        width: inner,
        height: inner,
        colorFilter: ColorFilter.mode(c.text, BlendMode.srcIn),
      );
    } else if (kind == 'opencode') {
      child = SvgPicture.string(
        AgentBrandSvg.opencode,
        width: inner,
        height: inner,
        colorFilter: ColorFilter.mode(c.text, BlendMode.srcIn),
      );
    } else if (kind == 'antigravity') {
      child = Image.asset(
        'assets/brand/antigravity.png',
        width: inner,
        height: inner,
        fit: BoxFit.contain,
      );
    } else if (kind == 'gemini') {
      child = Icon(PhosphorIconsRegular.sparkle, size: inner, color: c.accentText);
    } else {
      child = Icon(PhosphorIconsRegular.terminalWindow, size: inner, color: c.text2);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.hover,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.lineSubtle, width: 1),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Deterministic Slate letter avatar (`S`, `T`, `A`, `M`, ...) with soft hue tint.
class ProjectAvatar extends StatelessWidget {
  const ProjectAvatar({
    super.key,
    required this.name,
    this.size = 24,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final (fg, bg) = c.projectHue(name);
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size <= 20 ? 5 : 6),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: size <= 20 ? 10.5 : 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// App logo tile (TernaryCode vector icon).
class TernaryCodeMark extends StatelessWidget {
  const TernaryCodeMark({super.key, this.size = 52, this.radius = 12});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SvgPicture.asset(
        'assets/brand/icon.svg',
        width: size,
        height: size,
      ),
    );
  }
}
