import 'package:flutter/material.dart';

/// Logical-pixel breakpoints shared by every screen in the app.
///
/// * [mobile] — the design baseline (375px, e.g. iPhone SE / small Android).
/// * [tablet] — the point at which single-column layouts start switching to
///   side-by-side or multi-column layouts (768px).
/// * [desktop] — the point at which content is additionally width-constrained
///   and typography stops growing (1280px).
class Breakpoints {
  Breakpoints._();
  static const double mobile = 375;
  static const double tablet = 768;
  static const double desktop = 1280;
}

enum DeviceSize { mobile, tablet, desktop }

DeviceSize deviceSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.desktop) return DeviceSize.desktop;
  if (width >= Breakpoints.tablet) return DeviceSize.tablet;
  return DeviceSize.mobile;
}

/// Dart equivalent of CSS `clamp(min, preferred, max)`.
double clampValue(double value, {required double min, required double max}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Fluid value that interpolates linearly between [min] and [max] as the
/// viewport width moves between [minViewport] and [maxViewport], then clamps
/// the result to `[min, max]` — the same curve CSS `clamp()` produces when the
/// preferred value is expressed in `vw` units.
double fluidValue(
  double width, {
  required double min,
  required double max,
  double minViewport = Breakpoints.mobile,
  double maxViewport = Breakpoints.desktop,
}) {
  if (maxViewport == minViewport) return min;
  final t = ((width - minViewport) / (maxViewport - minViewport)).clamp(0.0, 1.0);
  return clampValue(min + (max - min) * t, min: min, max: max);
}

/// Fluid font size, clamped between [min] and [max] across the standard
/// mobile→desktop breakpoint range.
double fluidFontSize(
  BuildContext context, {
  required double min,
  required double max,
}) {
  return fluidValue(MediaQuery.sizeOf(context).width, min: min, max: max);
}

/// Picks a value per [DeviceSize], falling back to the next-smallest tier when
/// a tier isn't specified (e.g. `desktop` unset reuses `tablet`).
T responsiveValue<T>(BuildContext context, {required T mobile, T? tablet, T? desktop}) {
  switch (deviceSizeOf(context)) {
    case DeviceSize.desktop:
      return desktop ?? tablet ?? mobile;
    case DeviceSize.tablet:
      return tablet ?? mobile;
    case DeviceSize.mobile:
      return mobile;
  }
}

/// Responsive horizontal/vertical padding for standard screen gutters.
EdgeInsets buildResponsivePadding(BuildContext context) {
  final all = responsiveValue<double>(context, mobile: 16, tablet: 24, desktop: 32);
  return EdgeInsets.all(all);
}

/// Centers [child] and stops it from stretching edge-to-edge on wide
/// viewports, which keeps line lengths readable on tablet/desktop.
class ContentMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentMaxWidth({required this.child, this.maxWidth = 720, super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Builds a different widget per [DeviceSize], falling back to [mobile] when
/// a larger-tier builder isn't given. Use this for genuinely different layouts
/// (e.g. a list on mobile vs. a grid on tablet/desktop); prefer
/// [responsiveValue] for small differences like spacing or column counts.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveLayout({required this.mobile, this.tablet, this.desktop, super.key});

  @override
  Widget build(BuildContext context) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.desktop:
        return (desktop ?? tablet ?? mobile)(context);
      case DeviceSize.tablet:
        return (tablet ?? mobile)(context);
      case DeviceSize.mobile:
        return mobile(context);
    }
  }
}

/// Number of columns a card/grid section should use at the current width.
int responsiveColumnCount(BuildContext context) {
  return responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2);
}

extension ResponsiveContextX on BuildContext {
  DeviceSize get deviceSize => deviceSizeOf(this);
  double get viewportWidth => MediaQuery.sizeOf(this).width;
  EdgeInsets get responsivePadding => buildResponsivePadding(this);
}
