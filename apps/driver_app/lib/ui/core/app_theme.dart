import 'package:flutter/material.dart';

/// Uber design tokens: a strict black/white/gray system with pill-shaped
/// interactive elements and whisper-soft elevation.
///
/// Screens and widgets take every colour, radius and spacing value from here —
/// no view should reach for `Colors.green` or a raw `BorderRadius.circular`.
class UberColors {
  UberColors._();

  /// The defining brand colour: true black. Primary buttons, headlines, and
  /// every inverted (active/selected) surface.
  static const Color black = Color(0xFF000000);

  /// Primary surface and inverse text.
  static const Color white = Color(0xFFFFFFFF);

  /// Secondary text. A true mid-gray with no warm or cool bias.
  static const Color bodyGray = Color(0xFF4B4B4B);

  /// Tertiary text, placeholders, and inactive icons.
  static const Color mutedGray = Color(0xFFAFAFAF);

  /// Background for secondary buttons, filter chips, and inactive pills.
  static const Color chipGray = Color(0xFFEFEFEF);

  /// Hover/pressed feedback for white surfaces.
  static const Color hoverGray = Color(0xFFE2E2E2);

  /// Softer hover feedback for already-elevated white surfaces.
  static const Color hoverLight = Color(0xFFF3F3F3);

  /// In-card separator. Structural rules (rail, header dividers) use [black]
  /// at 1px; this lighter rule only separates rows inside a card.
  static const Color hairline = Color(0xFFE8E8E8);

  /// Press overlay for flat surfaces: `rgba(0,0,0,0.08)`.
  static const Color pressedOverlay = Color(0x14000000);

  /// The only non-monochrome colour in the system, reserved for destructive
  /// actions and failed states (cancellations, rejections, request errors).
  /// It never appears as decoration.
  static const Color danger = Color(0xFFD32F2F);

  /// Tinted backdrop paired with [danger] for banners and badges.
  static const Color dangerSurface = Color(0xFFFDECEA);
}

/// Uber's elevation is structural, never decorative: black at 8–16% opacity,
/// moderate blur, no coloured or layered shadow stacks.
class UberShadows {
  UberShadows._();

  /// Standard card lift: `rgba(0,0,0,0.12) 0 4 16`.
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Elevated cards and overlays: `rgba(0,0,0,0.16) 0 4 16`.
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Floating controls: `rgba(0,0,0,0.16) 0 2 8`.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x29000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

/// The 8px grid. Uber's whitespace is functional — enough to separate, never
/// enough to feel empty.
class UberSpacing {
  UberSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 64;
}

/// Corner radii. Interactive elements are always full pills (`StadiumBorder`);
/// containers use 8px, featured containers 12px.
class UberRadii {
  UberRadii._();
  static const double card = 8;
  static const double featured = 12;
  static const double input = 8;
}

/// Typographic scale from the design system.
///
/// UberMove / UberMoveText are proprietary, so the system font stack is used
/// with the geometric faces below as fallbacks. Headlines are exclusively
/// weight 700; body and UI text sit at 400–500.
class UberTypography {
  UberTypography._();

  /// Fallbacks tried in order when the platform lacks the primary face.
  static const List<String> fallback = <String>[
    'UberMoveText',
    'Inter',
    'Helvetica Neue',
    'Arial',
  ];

  static const TextStyle display = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1.23,
    color: UberColors.black,
  );
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.22,
    color: UberColors.black,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: UberColors.black,
  );
  static const TextStyle subHeading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.33,
    color: UberColors.black,
  );
  static const TextStyle smallHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: UberColors.black,
  );
  static const TextStyle uiLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.33,
    color: UberColors.black,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: UberColors.black,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    color: UberColors.bodyGray,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.67,
    color: UberColors.mutedGray,
  );

  /// Money and other figures the driver scans first: black, bold, tight.
  static const TextStyle figure = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: UberColors.black,
  );
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: UberColors.black,
    onPrimary: UberColors.white,
    secondary: UberColors.black,
    onSecondary: UberColors.white,
    surface: UberColors.white,
    onSurface: UberColors.black,
    surfaceContainerHighest: UberColors.chipGray,
    outline: UberColors.black,
    error: UberColors.danger,
    onError: UberColors.white,
  ),
  scaffoldBackgroundColor: UberColors.white,
  // Uber's own faces are unavailable here; 'Tajawal' is the geometric Arabic
  // stand-in, with the system stack behind it.
  fontFamily: 'Tajawal',
  fontFamilyFallback: UberTypography.fallback,
  // Uber answers a press with a flat overlay, not a circular ink ripple.
  splashFactory: NoSplash.splashFactory,
  highlightColor: UberColors.pressedOverlay,
  visualDensity: VisualDensity.standard,
  textTheme: const TextTheme(
    displayLarge: UberTypography.display,
    displayMedium: UberTypography.sectionHeading,
    displaySmall: UberTypography.cardTitle,
    headlineMedium: UberTypography.subHeading,
    headlineSmall: UberTypography.smallHeading,
    titleLarge: UberTypography.uiLarge,
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.25, color: UberColors.black),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.29, color: UberColors.black),
    bodyLarge: UberTypography.body,
    bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.25, color: UberColors.bodyGray),
    bodySmall: UberTypography.caption,
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.25, color: UberColors.black),
    labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.14, color: UberColors.black),
    labelSmall: UberTypography.micro,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: UberColors.white,
    foregroundColor: UberColors.black,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: UberSpacing.lg,
    titleTextStyle: TextStyle(
      fontFamily: 'Tajawal',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: UberColors.black,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: UberColors.black,
      foregroundColor: UberColors.white,
      disabledBackgroundColor: UberColors.chipGray,
      disabledForegroundColor: UberColors.mutedGray,
      elevation: 0,
      shadowColor: Colors.transparent,
      // 44px minimum keeps every primary action touch-friendly regardless of
      // label length; width is left free since buttons are usually full-width.
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: UberColors.black,
      side: const BorderSide(color: UberColors.black, width: 1),
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: UberColors.black,
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: UberColors.black,
      minimumSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
  ),
  iconTheme: const IconThemeData(color: UberColors.black, size: 24),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: UberColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.black, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.black, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.black, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.danger, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(UberRadii.input),
      borderSide: const BorderSide(color: UberColors.mutedGray, width: 1),
    ),
    labelStyle: const TextStyle(color: UberColors.bodyGray, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: UberColors.black, fontSize: 14, fontWeight: FontWeight.w500),
    hintStyle: const TextStyle(color: UberColors.mutedGray, fontSize: 14),
    errorStyle: const TextStyle(color: UberColors.danger, fontSize: 12, fontWeight: FontWeight.w500),
    prefixStyle: const TextStyle(color: UberColors.black, fontSize: 16),
    suffixStyle: const TextStyle(color: UberColors.bodyGray, fontSize: 14),
    iconColor: UberColors.bodyGray,
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: UberColors.black,
    selectionColor: Color(0x1F000000),
    selectionHandleColor: UberColors.black,
  ),
  cardTheme: CardThemeData(
    color: UberColors.white,
    // Depth comes from [UberShadows.subtle] on UberCard; a Material elevation
    // here would render a heavier, tinted shadow than the system allows.
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UberRadii.card)),
    shadowColor: Colors.transparent,
    margin: const EdgeInsets.all(UberSpacing.sm),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: UberColors.chipGray,
    selectedColor: UberColors.black,
    disabledColor: UberColors.hoverLight,
    labelStyle: const TextStyle(color: UberColors.black, fontSize: 14, fontWeight: FontWeight.w500),
    secondaryLabelStyle: const TextStyle(color: UberColors.white, fontSize: 14, fontWeight: FontWeight.w500),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    side: BorderSide.none,
    showCheckmark: false,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.xs),
    iconColor: UberColors.black,
    titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
    subtitleTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: UberColors.bodyGray),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UberRadii.card)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: UberColors.black,
    linearTrackColor: UberColors.chipGray,
    circularTrackColor: Colors.transparent,
  ),
  dividerTheme: const DividerThemeData(
    color: UberColors.black,
    thickness: 1,
    space: 16,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: UberColors.white,
    foregroundColor: UberColors.black,
    elevation: 2,
    focusElevation: 4,
    hoverElevation: 4,
    highlightElevation: 2,
    shape: StadiumBorder(),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: UberColors.black,
    contentTextStyle: const TextStyle(color: UberColors.white, fontSize: 14),
    actionTextColor: UberColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UberRadii.card)),
    behavior: SnackBarBehavior.floating,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: UberColors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(UberRadii.featured)),
    ),
    titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
    contentTextStyle: TextStyle(fontSize: 16, height: 1.5, color: UberColors.bodyGray),
  ),
  // Bottom navigation: white bar, black pill behind the active icon — the same
  // inversion the category pills use.
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: UberColors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: UberColors.black,
    indicatorShape: const StadiumBorder(),
    elevation: 0,
    height: 68,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      return IconThemeData(
        size: 24,
        color: states.contains(WidgetState.selected) ? UberColors.white : UberColors.bodyGray,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? UberColors.black : UberColors.bodyGray,
      );
    }),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: UberColors.white,
    selectedItemColor: UberColors.black,
    unselectedItemColor: UberColors.mutedGray,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: UberColors.white,
    elevation: 0,
    indicatorColor: UberColors.black,
    indicatorShape: const StadiumBorder(),
    useIndicator: true,
    selectedIconTheme: const IconThemeData(color: UberColors.white, size: 24),
    unselectedIconTheme: const IconThemeData(color: UberColors.bodyGray, size: 24),
    selectedLabelTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UberColors.black),
    unselectedLabelTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: UberColors.bodyGray),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: UberColors.black,
      borderRadius: BorderRadius.circular(UberRadii.card),
    ),
    textStyle: const TextStyle(color: UberColors.white, fontSize: 12),
  ),
);
