import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Uber's surface primitive: white (or inverted black), 8px radius, and a
/// whisper-soft shadow instead of a border.
///
/// The design system defines cards by elevation, not by stroke — so this widget
/// deliberately has no `BorderSide` and no Material tint.
class UberCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Featured/promoted containers step up to a 12px radius.
  final bool featured;

  /// Inverts the surface to Uber Black, for hero panels and the active state of
  /// a section the driver is focused on.
  final bool inverted;

  /// Overrides the surface colour — Chip Gray for flat notice blocks.
  final Color? background;

  /// Flat surfaces (notices, inset blocks) drop the shadow entirely.
  final bool elevated;

  const UberCard({
    required this.child,
    this.padding,
    this.onTap,
    this.featured = false,
    this.inverted = false,
    this.background,
    this.elevated = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(featured ? UberRadii.featured : UberRadii.card);
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(UberSpacing.lg),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: inverted ? UberColors.black : (background ?? UberColors.white),
        borderRadius: radius,
        boxShadow: !elevated
            ? null
            : inverted
            ? UberShadows.medium
            : UberShadows.subtle,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: radius,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// A section anchor: bold heading on the left, optional action on the right.
class UberSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const UberSectionHeader({required this.title, this.action, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: UberSpacing.sm),
          action!,
        ],
      ],
    );
  }
}

/// Interactive pill (category/filter chip). Inactive is Chip Gray with black
/// text; active inverts to Uber Black with white text.
///
/// Always at least 44px tall so it stays a comfortable thumb target.
class UberPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onPressed;

  const UberPill({
    required this.label,
    this.icon,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? UberColors.white : UberColors.black;
    return Material(
      color: selected ? UberColors.black : UberColors.chipGray,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: UberSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual weight of a [UberStatusPill].
enum UberStatusTone {
  /// Passive/idle state — Chip Gray.
  neutral,

  /// Live or completed state — inverted Uber Black.
  active,

  /// Failed, rejected, or cancelled — the system's only tinted surface.
  danger,
}

/// Non-interactive state badge. Colour is used sparingly: the "on" state is
/// expressed by inverting to black rather than by introducing a green.
class UberStatusPill extends StatelessWidget {
  final String label;
  final UberStatusTone tone;

  const UberStatusPill({
    required this.label,
    this.tone = UberStatusTone.neutral,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      UberStatusTone.active => (UberColors.black, UberColors.white),
      UberStatusTone.danger => (UberColors.dangerSurface, UberColors.danger),
      UberStatusTone.neutral => (UberColors.chipGray, UberColors.black),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: UberSpacing.md, vertical: UberSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
      ),
    );
  }
}

/// `pickup → destination`, with the arrow mirrored for right-to-left locales.
class UberRouteLine extends StatelessWidget {
  final String pickup;
  final String destination;
  final Color color;
  final double fontSize;

  const UberRouteLine({
    required this.pickup,
    required this.destination,
    this.color = UberColors.black,
    this.fontSize = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: color);
    return Row(
      children: [
        Expanded(child: Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UberSpacing.sm),
          child: Icon(
            rtl ? Icons.arrow_back : Icons.arrow_forward,
            size: fontSize,
            color: UberColors.mutedGray,
          ),
        ),
        Expanded(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
  }
}

/// Label/value row for money and trip metrics. The emphasised row is the one
/// the driver cares about: black, bold, and separated by a light hairline.
class UberMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final bool divided;

  const UberMetricRow({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.divided = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: emphasis ? UberColors.black : UberColors.bodyGray,
    );
    final valueStyle = TextStyle(
      fontSize: emphasis ? 20 : 16,
      fontWeight: FontWeight.w700,
      color: UberColors.black,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divided) const Divider(height: UberSpacing.xl, thickness: 1, color: UberColors.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: UberSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
              ),
              const SizedBox(width: UberSpacing.sm),
              Text(value, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empty-list placeholder: muted glyph, one bold line, one explanatory line.
class UberEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const UberEmptyState({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UberSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: UberColors.mutedGray),
            const SizedBox(height: UberSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
            ),
            if (message != null) ...[
              const SizedBox(height: UberSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: UberTypography.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline request/validation error, in the single reserved danger colour.
class UberErrorText extends StatelessWidget {
  final String? message;

  const UberErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: UberSpacing.sm),
      child: Text(
        message!,
        style: const TextStyle(color: UberColors.danger, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
