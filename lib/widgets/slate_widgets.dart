import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';

enum SlateButtonVariant { primary, raised, secondary, danger, ghost }

/// Thumb-sized Slate action button (44px default, 36px `sm`, 28px `xs`).
class SlateButton extends StatelessWidget {
  const SlateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SlateButtonVariant.primary,
    this.icon,
    this.height = 44,
    this.expanded = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final SlateButtonVariant variant;
  final IconData? icon;
  final double height;
  final bool expanded;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final disabled = onPressed == null || busy;

    Color bg;
    Color fg;
    Border? border;
    switch (variant) {
      case SlateButtonVariant.primary:
        bg = c.accent;
        fg = c.onAccent;
        border = null;
      case SlateButtonVariant.raised:
        bg = c.raised;
        fg = c.text;
        border = Border.all(color: c.lineSubtle);
      case SlateButtonVariant.secondary:
        bg = c.raised;
        fg = c.text;
        border = Border.all(color: c.line);
      case SlateButtonVariant.danger:
        bg = c.failedTint;
        fg = c.failed;
        border = Border.all(color: c.failed.withValues(alpha: 0.22));
      case SlateButtonVariant.ghost:
        bg = c.hover;
        fg = c.text2;
        border = null;
    }

    final radius = height <= 28 ? 7.0 : (height <= 36 ? 8.0 : 10.0);
    final fontSize = height <= 28 ? 12.0 : (height <= 36 ? 12.5 : 13.0);

    Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: fg,
            ),
          ),
          const SizedBox(width: 7),
        ] else if (icon != null) ...[
          Icon(icon, size: height <= 28 ? 13 : 16, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ],
    );

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height <= 28 ? 10 : 13),
          decoration: BoxDecoration(
            color: disabled ? bg.withValues(alpha: 0.55) : bg,
            borderRadius: BorderRadius.circular(radius),
            border: border,
          ),
          child: Center(widthFactor: expanded ? null : 1, child: content),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Crisp 32×32 (or 26×26 small) square icon button.
class SlateIconButton extends StatelessWidget {
  const SlateIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.small = false,
    this.active = false,
    this.label,
  });

  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool small;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final dim = small ? 28.0 : 34.0;
    final rad = small ? 6.0 : 8.0;

    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(rad),
        child: Ink(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            color: active ? c.accentTint : c.hover,
            borderRadius: BorderRadius.circular(rad),
          ),
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: SlateTypography.data(
                      c,
                      size: 11,
                      weight: FontWeight.w600,
                      color: active ? c.accentText : c.text2,
                    ),
                  )
                : Icon(
                    icon,
                    size: small ? 15 : 18,
                    color: active ? c.accentText : c.text2,
                  ),
          ),
        ),
      ),
    );

    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Neutral raised surface card with 1px translucent hairline.
class SlateCard extends StatelessWidget {
  const SlateCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.backgroundColor,
    this.radius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.raised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.lineSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Hairline-separated list row inside a [SlateCard].
class SlateRow extends StatelessWidget {
  const SlateRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.monoSubtitle,
    this.trailing,
    this.onTap,
    this.showTopDivider = false,
    this.backgroundColor,
    this.minHeight = 52,
  });

  final Widget? leading;
  final Widget title;
  final String? subtitle;
  final String? monoSubtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showTopDivider;
  final Color? backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final inner = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showTopDivider
            ? Border(top: BorderSide(color: c.lineSubtle, width: 1))
            : null,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlateTypography.body2(c),
                  ),
                ],
                if (monoSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    monoSubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlateTypography.data(c),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: inner),
    );
  }
}

/// Top screen header with bold Slate title, live host switcher pill, and Settings gear.
class SlateTopHeader extends StatelessWidget {
  const SlateTopHeader({
    super.key,
    required this.title,
    required this.hostName,
    required this.hostOnline,
    this.hostReconnecting = false,
    this.hasUpdateBadge = false,
    required this.onTapHost,
    required this.onTapSettings,
  });

  final String title;
  final String hostName;
  final bool hostOnline;
  final bool hostReconnecting;
  final bool hasUpdateBadge;
  final VoidCallback onTapHost;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final dotColor = hostOnline
        ? c.done
        : (hostReconnecting ? c.input : c.failed);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(title, style: SlateTypography.title(c)),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapHost,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.lineSubtle),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 165),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SlateTypography.data(c, color: c.text2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(PhosphorIconsRegular.caretDown,
                              size: 12, color: c.text3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SlateIconButton(
                icon: PhosphorIconsRegular.gearSix,
                tooltip: 'Settings',
                onPressed: onTapSettings,
              ),
              if (hasUpdateBadge)
                Positioned(
                  top: 3,
                  right: 3,
                  child: IgnorePointer(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.window, width: 1.2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tinted semantic notice banner (Needs input / Rate limit / Failed).
class SlateNotice extends StatelessWidget {
  const SlateNotice({
    super.key,
    required this.status,
    required this.title,
    required this.body,
    required this.leading,
    this.trailing,
  });

  final String status;
  final String title;
  final String body;
  final Widget leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final (fg, tint) = c.statusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: leading,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    height: 17 / 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: SlateTypography.data(c, color: c.text2),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Inset text field with crisp Slate focus ring.
class SlateTextField extends StatelessWidget {
  const SlateTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.mono = false,
    this.error = false,
    this.compact = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool mono;
  final bool error;
  final bool compact;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final rad = compact ? 8.0 : 9.0;
    final minH = compact ? 38.0 : 42.0;
    final field = TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: mono
          ? SlateTypography.data(c, size: 12.5, color: c.text)
          : SlateTypography.body(c),
      cursorColor: c.accent,
      decoration: InputDecoration(
        filled: true,
        fillColor: c.inset,
        hintText: hint,
        hintStyle: mono
            ? SlateTypography.data(c, size: 12, color: c.text3)
            : TextStyle(fontFamily: 'Inter', fontSize: 13, color: c.text3),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 15, color: c.text3),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rad),
          borderSide: BorderSide(color: error ? c.failed : c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rad),
          borderSide: BorderSide(color: error ? c.failed : c.accent, width: 1.2),
        ),
      ),
    );
    if (maxLines == 1) {
      return SizedBox(height: minH, child: field);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: field,
    );
  }
}

/// Compact mono tag chip (`MAX`, `PRO`, `Live`, `Active`, `Automatic`).
class SlateTag extends StatelessWidget {
  const SlateTag({
    super.key,
    required this.label,
    this.fg,
    this.bg,
  });

  final String label;
  final Color? fg;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg ?? c.accentTint,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: SlateTypography.data(
          c,
          size: 10.5,
          weight: FontWeight.w600,
          color: fg ?? c.accentText,
        ),
      ),
    );
  }
}

/// Compact outlined inline action button (`Resume`, `Check`, `Use`).
class SlateGoButton extends StatelessWidget {
  const SlateGoButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Ink(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: c.window,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: c.text2),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inset segmented control (`All / Needs you / Finished` or `Dark / Light`).
class SlateSegmented<T> extends StatelessWidget {
  const SlateSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T id, String label, int? count)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.lineSubtle),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: value == item.$1 ? c.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: value == item.$1
                        ? Border.all(color: c.lineSubtle)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: value == item.$1 ? c.text : c.text3,
                          ),
                        ),
                      ),
                      if (item.$3 != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${item.$3}',
                          style: SlateTypography.data(c, size: 10.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Crisp Slate 38×22 toggle switch (no bloated Material 3 thumb halo).
class SlateSwitch extends StatelessWidget {
  const SlateSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? c.accent : c.lineStrong,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5h / Weekly quota progress meter with tabular numerals and reset countdown.
class SlateQuotaMeter extends StatelessWidget {
  const SlateQuotaMeter({
    super.key,
    required this.label,
    this.usedPct,
    required this.tokensLabel,
    this.resetLabel,
  });

  final String label;
  final double? usedPct;
  final String tokensLabel;
  final String? resetLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final pct = usedPct?.clamp(0.0, 100.0);
    final barColor = pct == null
        ? c.accent
        : pct >= 90
            ? c.limited
            : pct >= 70
                ? c.input
                : c.accent;

    if (pct == null) {
      // Local-telemetry-only window (e.g. Antigravity CLI): clean label + tokens without a fake 0% bar.
      return Row(
        children: [
          Text(label, style: SlateTypography.data(c)),
          const Spacer(),
          Text(
            tokensLabel,
            style: SlateTypography.data(c, color: c.text2),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: SlateTypography.data(c)),
            const Spacer(),
            Text(
              '${pct.round()}% · $tokensLabel',
              style: SlateTypography.data(
                c,
                color: pct >= 70 ? barColor : c.text2,
                weight: pct >= 70 ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            if (resetLabel != null && resetLabel!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(
                PhosphorIconsRegular.clockCounterClockwise,
                size: 11,
                color: c.text3,
              ),
              const SizedBox(width: 3),
              Text(resetLabel!, style: SlateTypography.data(c)),
            ],
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            color: c.active,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct / 100.0,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Uppercase Slate section label.
class SlateSectionLabel extends StatelessWidget {
  const SlateSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: SlateTypography.section(context.slate),
    );
  }
}
