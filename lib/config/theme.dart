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

/// Radius sudut konsisten. Kartu 22, tombol/field/tile 16, chip pill.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double card = 22;
  static const double xl = 24;
  static const double pill = 999;
}

/// Gradien standar Dribbble-style biru korporat.
abstract final class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2349C9), Color(0xFF4C74F5)],
  );

  static const LinearGradient softBlueBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF3FF), Color(0xFFF5F7FC)],
  );
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
    success: Color(0xFF12A06E),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDFF5EA),
    onSuccessContainer: Color(0xFF0B5A41),
    warning: Color(0xFF6240D9),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFEFE9FF),
    onWarningContainer: Color(0xFF4C2BB0),
    info: Color(0xFF2349C9),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFE6EDFF),
    onInfoContainer: Color(0xFF163299),
    neutral: Color(0xFF5B6785),
    onNeutral: Color(0xFFFFFFFF),
    neutralContainer: Color(0xFFF1F4FB),
    onNeutralContainer: Color(0xFF0F1B3D),
    plateBackground: Color(0xFFFFFFFF),
    plateForeground: Color(0xFF0F1B3D),
    plateBorder: Color(0xFF0F1B3D),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF34D399),
    onSuccess: Color(0xFF063B29),
    successContainer: Color(0xFF10382C),
    onSuccessContainer: Color(0xFFA7F3D0),
    warning: Color(0xFFA78BFA),
    onWarning: Color(0xFF24125E),
    warningContainer: Color(0xFF281D4D),
    onWarningContainer: Color(0xFFDDD6FE),
    info: Color(0xFF6C92FF),
    onInfo: Color(0xFF0B1F66),
    infoContainer: Color(0xFF192B5C),
    onInfoContainer: Color(0xFFDCE6FF),
    neutral: Color(0xFF9FB0D1),
    onNeutral: Color(0xFF0F1B3D),
    neutralContainer: Color(0xFF182442),
    onNeutralContainer: Color(0xFFD9E3FA),
    plateBackground: Color(0xFFFFFFFF),
    plateForeground: Color(0xFF0F1B3D),
    plateBorder: Color(0xFF0F1B3D),
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
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
      neutralContainer: Color.lerp(
        neutralContainer,
        other.neutralContainer,
        t,
      )!,
      onNeutralContainer: Color.lerp(
        onNeutralContainer,
        other.onNeutralContainer,
        t,
      )!,
      plateBackground: Color.lerp(plateBackground, other.plateBackground, t)!,
      plateForeground: Color.lerp(plateForeground, other.plateForeground, t)!,
      plateBorder: Color.lerp(plateBorder, other.plateBorder, t)!,
    );
  }
}

/// Bayangan lembut biru-korporat: 0 8 24 rgba(35,73,201,.08).
abstract final class AppShadows {
  static List<BoxShadow> soft(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: const Color(0xFF2349C9).withValues(alpha: isDark ? 0.24 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> raised(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: const Color(0xFF2349C9).withValues(alpha: isDark ? 0.34 : 0.14),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ];
  }

  /// Dipakai pada sticky dock di bawah layar (bayangan mengarah ke atas).
  static List<BoxShadow> top(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: const Color(0xFF2349C9).withValues(alpha: isDark ? 0.28 : 0.08),
        blurRadius: 22,
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

  // Brand & token warna utama (tanpa amber/kuning/oranye dan tanpa hitam pekat).
  static const Color navyDark = Color(0xFF0F1B3D);
  static const Color corporateNavy = Color(0xFF0F1B3D);
  static const Color corporateBlue = Color(0xFF2349C9);
  static const Color gradientBlueEnd = Color(0xFF4C74F5);
  static const Color primaryTint = Color(0xFFE6EDFF);
  static const Color amberGold = Color(0xFF4C74F5);
  static const Color amberLight = Color(0xFFE6EDFF);

  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F7FC);
  static const Color cardBorder = Color(0xFFE1E7F5);

  static const Color textPrimary = Color(0xFF0F1B3D);
  static const Color textSecondary = Color(0xFF5B6785);
  static const Color textMuted = Color(0xFF8B97B3);

  static const Color successGreen = Color(0xFF12A06E);
  static const Color successLight = Color(0xFFDFF5EA);
  static const Color errorRed = Color(0xFFD92D5A);
  static const Color errorLight = Color(0xFFFEE4EC);

  // -------------------------------------------------------------------------
  // Color schemes
  // -------------------------------------------------------------------------

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2349C9),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6EDFF),
    onPrimaryContainer: Color(0xFF163299),
    secondary: Color(0xFF4C74F5),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEEF2FB),
    onSecondaryContainer: Color(0xFF0F1B3D),
    tertiary: Color(0xFF6240D9),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFEFE9FF),
    onTertiaryContainer: Color(0xFF4C2BB0),
    error: Color(0xFFD92D5A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE4EC),
    onErrorContainer: Color(0xFF881337),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F1B3D),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F7FC),
    surfaceContainer: Color(0xFFF1F4FB),
    surfaceContainerHigh: Color(0xFFE9EEF9),
    surfaceContainerHighest: Color(0xFFE1E7F5),
    onSurfaceVariant: Color(0xFF5B6785),
    outline: Color(0xFFD5DCEE),
    outlineVariant: Color(0xFFE1E7F5),
    shadow: Color(0xFF2349C9),
    scrim: Color(0xFF0F1B3D),
    inverseSurface: Color(0xFF0F1B3D),
    onInverseSurface: Color(0xFFF5F7FC),
    inversePrimary: Color(0xFFA7BFFF),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF4C74F5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF192B5C),
    onPrimaryContainer: Color(0xFFDCE6FF),
    secondary: Color(0xFF7B9BFF),
    onSecondary: Color(0xFF0B1942),
    secondaryContainer: Color(0xFF182442),
    onSecondaryContainer: Color(0xFFD9E3FA),
    tertiary: Color(0xFFA78BFA),
    onTertiary: Color(0xFF24125E),
    tertiaryContainer: Color(0xFF281D4D),
    onTertiaryContainer: Color(0xFFDDD6FE),
    error: Color(0xFFFF6B8B),
    onError: Color(0xFF4C0519),
    errorContainer: Color(0xFF5E1127),
    onErrorContainer: Color(0xFFFFD6DF),
    surface: Color(0xFF131E3A),
    onSurface: Color(0xFFEEF3FF),
    surfaceContainerLowest: Color(0xFF0B1326),
    surfaceContainerLow: Color(0xFF0D162C),
    surfaceContainer: Color(0xFF182442),
    surfaceContainerHigh: Color(0xFF1F2D50),
    surfaceContainerHighest: Color(0xFF283860),
    onSurfaceVariant: Color(0xFF9FB0D1),
    outline: Color(0xFF31436E),
    outlineVariant: Color(0xFF243358),
    shadow: Color(0xFF080E1E),
    scrim: Color(0xFF080E1E),
    inverseSurface: Color(0xFFEEF3FF),
    onInverseSurface: Color(0xFF0F1B3D),
    inversePrimary: Color(0xFF2349C9),
  );

  // -------------------------------------------------------------------------
  // ThemeData
  // -------------------------------------------------------------------------

  static final ThemeData lightTheme = _build(
    lightScheme,
    AppSemanticColors.light,
  );
  static final ThemeData darkTheme = _build(darkScheme, AppSemanticColors.dark);

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final textTheme = _textTheme(scheme);
    final fieldFill = scheme.surfaceContainer;
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperMaxLines: 2,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
        errorMaxLines: 3,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        disabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
        errorBorder: _inputBorder(scheme.error, width: 1.2),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.5),
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
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
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
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
    final surface =
        scheme?.surface ?? (isDark ? darkScheme.surface : lightScheme.surface);

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
