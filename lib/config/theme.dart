import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
/// DESIGN TOKENS
/// ---------------------------------------------------------------------------

/// Skala jarak (spacing) 4-based yang dipakai konsisten di seluruh aplikasi.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radius sudut konsisten. Target desain: 16-20 untuk permukaan utama.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// Durasi animasi standar agar micro-interaction terasa seragam.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

/// Warna semantik yang tidak disediakan langsung oleh [ColorScheme].
///
/// Semua status (berhasil, peringatan, informasi, netral, plat nomor)
/// diambil dari sini agar tidak ada warna hardcoded di view/widget.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.neutral,
    required this.onNeutral,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.plateBackground,
    required this.plateForeground,
    required this.plateBorder,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  final Color neutral;
  final Color onNeutral;
  final Color neutralContainer;
  final Color onNeutralContainer;

  final Color plateBackground;
  final Color plateForeground;
  final Color plateBorder;

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF15803D),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: Color(0xFFB45309),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    info: Color(0xFF1D4ED8),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDBEAFE),
    onInfoContainer: Color(0xFF1E3A8A),
    neutral: Color(0xFF475569),
    onNeutral: Color(0xFFFFFFFF),
    neutralContainer: Color(0xFFF1F5F9),
    onNeutralContainer: Color(0xFF334155),
    plateBackground: Color(0xFFFFFFFF),
    plateForeground: Color(0xFF0F172A),
    plateBorder: Color(0xFFCBD5E1),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF123B26),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF3B2300),
    warningContainer: Color(0xFF4A3208),
    onWarningContainer: Color(0xFFFDE68A),
    info: Color(0xFF93C5FD),
    onInfo: Color(0xFF0A2540),
    infoContainer: Color(0xFF16345C),
    onInfoContainer: Color(0xFFDBEAFE),
    neutral: Color(0xFFB6C4D5),
    onNeutral: Color(0xFF122033),
    neutralContainer: Color(0xFF1A2C43),
    onNeutralContainer: Color(0xFFD5E1F0),
    plateBackground: Color(0xFF020A14),
    plateForeground: Color(0xFFFFFFFF),
    plateBorder: Color(0xFF334155),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? neutral,
    Color? onNeutral,
    Color? neutralContainer,
    Color? onNeutralContainer,
    Color? plateBackground,
    Color? plateForeground,
    Color? plateBorder,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
      plateBackground: plateBackground ?? this.plateBackground,
      plateForeground: plateForeground ?? this.plateForeground,
      plateBorder: plateBorder ?? this.plateBorder,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
      neutralContainer: Color.lerp(neutralContainer, other.neutralContainer, t)!,
      onNeutralContainer: Color.lerp(onNeutralContainer, other.onNeutralContainer, t)!,
      plateBackground: Color.lerp(plateBackground, other.plateBackground, t)!,
      plateForeground: Color.lerp(plateForeground, other.plateForeground, t)!,
      plateBorder: Color.lerp(plateBorder, other.plateBorder, t)!,
    );
  }
}

/// Bayangan lembut yang mengikuti tema (lebih gelap di dark mode).
abstract final class AppShadows {
  static List<BoxShadow> soft(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: isDark ? 0.30 : 0.06),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> raised(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: isDark ? 0.40 : 0.12),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ];
  }

  /// Dipakai pada sticky bar di bawah layar (bayangan mengarah ke atas).
  static List<BoxShadow> top(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: isDark ? 0.32 : 0.07),
        blurRadius: 18,
        offset: const Offset(0, -6),
      ),
    ];
  }
}

/// Akses cepat ke token tema dari [BuildContext].
extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// ---------------------------------------------------------------------------
/// APP THEME
/// ---------------------------------------------------------------------------

class AppTheme {
  const AppTheme._();

  // Brand colors (tetap dipertahankan agar identitas tidak berubah).
  static const Color navyDark = Color(0xFF0F172A);
  static const Color corporateNavy = Color(0xFF0A2540);
  static const Color corporateBlue = Color(0xFF2563EB);
  static const Color amberGold = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFEF3C7);

  // Token lama yang masih dipakai view sebelum migrasi bertahap.
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF6F8FB);
  static const Color cardBorder = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color successGreen = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);

  // -------------------------------------------------------------------------
  // Color schemes
  // -------------------------------------------------------------------------

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: amberGold,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFEF0C7),
    onSecondaryContainer: Color(0xFF7A4100),
    tertiary: Color(0xFF0284C7),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDBEAFE),
    onTertiaryContainer: Color(0xFF1E3A8A),
    error: Color(0xFFD92D20),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE4E2),
    onErrorContainer: Color(0xFF7A271A),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F8FB),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE9EFF6),
    surfaceContainerHighest: Color(0xFFDFE7F0),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8F0),
    shadow: Color(0xFF0A2540),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF0F172A),
    onInverseSurface: Color(0xFFF8FAFC),
    inversePrimary: Color(0xFF9DC1F0),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF2B357),
    onPrimary: Color(0xFF2B1B00),
    primaryContainer: Color(0xFF4A3208),
    onPrimaryContainer: Color(0xFFFFDFA8),
    secondary: Color(0xFF9DC1F0),
    onSecondary: Color(0xFF06203A),
    secondaryContainer: Color(0xFF1B3A5C),
    onSecondaryContainer: Color(0xFFD6E6FF),
    tertiary: Color(0xFF93C5FD),
    onTertiary: Color(0xFF0A2540),
    tertiaryContainer: Color(0xFF16345C),
    onTertiaryContainer: Color(0xFFDBEAFE),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0B1828),
    onSurface: Color(0xFFE6EEF8),
    surfaceContainerLowest: Color(0xFF071220),
    surfaceContainerLow: Color(0xFF081523),
    surfaceContainer: Color(0xFF102033),
    surfaceContainerHigh: Color(0xFF172A40),
    surfaceContainerHighest: Color(0xFF1F344C),
    onSurfaceVariant: Color(0xFFA7B7CA),
    outline: Color(0xFF3A4E68),
    outlineVariant: Color(0xFF243650),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6EEF8),
    onInverseSurface: Color(0xFF0B1828),
    inversePrimary: Color(0xFF0A2540),
  );

  // -------------------------------------------------------------------------
  // ThemeData
  // -------------------------------------------------------------------------

  static final ThemeData lightTheme = _build(lightScheme, AppSemanticColors.light);
  static final ThemeData darkTheme = _build(darkScheme, AppSemanticColors.dark);

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(scheme);
    final fieldFill = isDark ? scheme.surfaceContainer : scheme.surface;
    final overlay = overlayStyle(scheme.brightness, scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      applyElevationOverlayColor: false,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[semantic],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: AppSpacing.lg,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        systemOverlayStyle: overlay,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        helperMaxLines: 2,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
        errorMaxLines: 3,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outline),
        disabledBorder: _inputBorder(scheme.outlineVariant.withValues(alpha: 0.6)),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          side: BorderSide(color: scheme.outline, width: 1.5),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        linearMinHeight: 6,
        circularTrackColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: textTheme.labelSmall,
        smallSize: 8,
        largeSize: 18,
      ),
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      focusColor: scheme.primary.withValues(alpha: 0.10),
      hoverColor: scheme.primary.withValues(alpha: 0.05),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    final color = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    TextStyle? style(
      TextStyle? source, {
      required FontWeight weight,
      required double size,
      double? height,
      double? letterSpacing,
      Color? textColor,
    }) {
      if (source == null) return null;
      return GoogleFonts.plusJakartaSans(
        textStyle: source,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      ).copyWith(color: textColor ?? color);
    }

    return TextTheme(
      displayLarge: style(
        base.displayLarge,
        weight: FontWeight.w800,
        size: 40,
        height: 1.12,
        letterSpacing: -1.2,
      ),
      displayMedium: style(
        base.displayMedium,
        weight: FontWeight.w800,
        size: 34,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      displaySmall: style(
        base.displaySmall,
        weight: FontWeight.w800,
        size: 30,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineLarge: style(
        base.headlineLarge,
        weight: FontWeight.w800,
        size: 26,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      headlineMedium: style(
        base.headlineMedium,
        weight: FontWeight.w700,
        size: 22,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      headlineSmall: style(
        base.headlineSmall,
        weight: FontWeight.w700,
        size: 20,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleLarge: style(
        base.titleLarge,
        weight: FontWeight.w700,
        size: 18,
        height: 1.35,
        letterSpacing: -0.2,
      ),
      titleMedium: style(
        base.titleMedium,
        weight: FontWeight.w700,
        size: 16,
        height: 1.4,
      ),
      titleSmall: style(
        base.titleSmall,
        weight: FontWeight.w600,
        size: 14,
        height: 1.4,
      ),
      bodyLarge: style(
        base.bodyLarge,
        weight: FontWeight.w400,
        size: 16,
        height: 1.5,
      ),
      bodyMedium: style(
        base.bodyMedium,
        weight: FontWeight.w400,
        size: 14,
        height: 1.5,
      ),
      bodySmall: style(
        base.bodySmall,
        weight: FontWeight.w400,
        size: 12,
        height: 1.45,
        textColor: muted,
      ),
      labelLarge: style(
        base.labelLarge,
        weight: FontWeight.w700,
        size: 14,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      labelMedium: style(
        base.labelMedium,
        weight: FontWeight.w600,
        size: 12,
        height: 1.2,
        letterSpacing: 0.2,
        textColor: muted,
      ),
      labelSmall: style(
        base.labelSmall,
        weight: FontWeight.w700,
        size: 11,
        height: 1.2,
        letterSpacing: 0.4,
        textColor: muted,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Gaya plat nomor: Chivo, tegas, angka tabular. Warna diwarisi dari parent.
  static TextStyle plateStyle({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w800,
    double letterSpacing = 1.6,
  }) {
    return GoogleFonts.chivo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1.2,
    );
  }

  /// Status bar & navigation bar mengikuti brightness tema aktif.
  static SystemUiOverlayStyle overlayStyle(
    Brightness brightness, [
    ColorScheme? scheme,
  ]) {
    final isDark = brightness == Brightness.dark;
    final surface = scheme?.surface ??
        (isDark ? darkScheme.surface : lightScheme.surface);

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
