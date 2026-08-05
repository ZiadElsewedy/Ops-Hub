// `CupertinoPageTransitionsBuilder` lives in the Cupertino library, not
// Material — it is the transition that carries the iOS back gesture.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.fontFamily,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.darkSurface,
          onPrimary: AppColors.onPrimary,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: AppTypography.h3,
        ),
        textTheme: _buildTextTheme(light: false),
        inputDecorationTheme: _buildInputTheme(light: false),
        elevatedButtonTheme: _buildButtonTheme(),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        datePickerTheme: _datePickerTheme,
        timePickerTheme: _timePickerTheme,
        pageTransitionsTheme: _pageTransitions,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.fontFamily,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.lightSurface,
          onPrimary: AppColors.white,
          onSurface: AppColors.textDark,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textDark),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        textTheme: _buildTextTheme(light: true),
        inputDecorationTheme: _buildInputTheme(light: true),
        elevatedButtonTheme: _buildButtonTheme(),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
        pageTransitionsTheme: _pageTransitions,
      );

  static TextTheme _buildTextTheme({required bool light}) {
    final bodyColor = light ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final headingColor = light ? AppColors.textDark : AppColors.textPrimary;
    return TextTheme(
      displayLarge: AppTypography.display.copyWith(color: headingColor),
      displayMedium: AppTypography.displayMedium.copyWith(color: headingColor),
      headlineLarge: AppTypography.h1.copyWith(color: headingColor),
      headlineMedium: AppTypography.h2.copyWith(color: headingColor),
      headlineSmall: AppTypography.h3.copyWith(color: headingColor),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: bodyColor),
      bodyMedium: AppTypography.body.copyWith(color: bodyColor),
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.labelLarge.copyWith(color: headingColor),
      labelMedium: AppTypography.label.copyWith(color: headingColor),
      labelSmall: AppTypography.labelSmall,
    );
  }

  static InputDecorationTheme _buildInputTheme({required bool light}) {
    final bg = light ? AppColors.lightSurface : AppColors.darkSurface;
    final border = light ? AppColors.lightBorder : AppColors.darkBorder;
    return InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: AppTypography.body,
      labelStyle: AppTypography.body,
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  static ElevatedButtonThemeData _buildButtonTheme() =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          elevation: 0,
          textStyle: AppTypography.labelLarge,
        ),
      );

  // ── Date / time pickers — bespoke monochrome instead of generic Material ──
  // The stock pickers are the most "default Flutter" surface in the create-task
  // flow. These themes dress them in the DROP language: a near-black elevated
  // sheet, a large radius, the white accent for the selected day/time, and the
  // neutral text ramp — so choosing a start/due time feels part of the product.
  static final DatePickerThemeData _datePickerTheme = DatePickerThemeData(
    backgroundColor: AppColors.darkSurfaceElevated,
    surfaceTintColor: AppColors.transparent,
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    headerBackgroundColor: AppColors.transparent,
    headerForegroundColor: AppColors.textSecondary,
    headerHeadlineStyle: AppTypography.h2,
    weekdayStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
    dayStyle: AppTypography.label,
    yearStyle: AppTypography.label,
    dividerColor: AppColors.darkBorder,
    todayBorder: const BorderSide(color: AppColors.textTertiary),
    dayForegroundColor: _pickerSelectable(AppColors.textPrimary),
    dayBackgroundColor: _pickerSelected(),
    todayForegroundColor: _pickerSelectable(AppColors.textPrimary),
    yearForegroundColor: _pickerSelectable(AppColors.textSecondary),
    yearBackgroundColor: _pickerSelected(),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
    ),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      textStyle: AppTypography.label,
    ),
  );

  static final TimePickerThemeData _timePickerTheme = TimePickerThemeData(
    backgroundColor: AppColors.darkSurfaceElevated,
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    hourMinuteColor: _timeFill(unselected: AppColors.darkSurface),
    hourMinuteTextColor: _timeFg(AppColors.textPrimary),
    hourMinuteTextStyle: AppTypography.display.copyWith(fontSize: 44),
    dayPeriodColor: _timeFill(unselected: AppColors.transparent),
    dayPeriodTextColor: _timeFg(AppColors.textSecondary),
    dayPeriodBorderSide: const BorderSide(color: AppColors.darkBorder),
    dialBackgroundColor: AppColors.darkSurface,
    dialHandColor: AppColors.primary,
    dialTextColor: _timeFg(AppColors.textPrimary),
    dialTextStyle: AppTypography.label,
    entryModeIconColor: AppColors.textSecondary,
    helpTextStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
    ),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      textStyle: AppTypography.label,
    ),
  );

  /// White accent fill when a day/time is selected, transparent (or [unselected])
  /// otherwise — the single "selected pill" treatment across both pickers.
  static WidgetStateProperty<Color?> _pickerSelected({Color? unselected}) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.primary
              : (unselected ?? AppColors.transparent));

  /// Foreground colour that flips to the dark [onFill] on a selected (white)
  /// pill and dims when disabled — keeps contrast correct in every state.
  static WidgetStateProperty<Color?> _pickerSelectable(
    Color base, {
    Color onFill = AppColors.onPrimary,
  }) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textQuaternary;
        }
        if (states.contains(WidgetState.selected)) return onFill;
        return base;
      });

  // The time-picker colour slots are plain `Color?` fields that accept a
  // `WidgetStateColor`, so they need a resolver that returns a non-null Color
  // (the date-picker uses `WidgetStateProperty<Color?>` instead).

  /// White accent fill when the hour/minute/period is selected, [unselected]
  /// otherwise.
  static WidgetStateColor _timeFill({required Color unselected}) =>
      WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.primary
              : unselected);

  /// Foreground that flips to dark on the selected white fill, dims when disabled.
  static WidgetStateColor _timeFg(Color base) =>
      WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textQuaternary;
        }
        if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
        return base;
      });

  /// iOS pushes use the Cupertino transition because it is the **only** builder
  /// that carries the interactive left-edge swipe-back — the sole way back on
  /// iOS now that the app bar draws no chevron (`core/routes/app_page_route.dart`).
  /// A `ZoomPageTransitionsBuilder` here would leave every `MaterialPageRoute`
  /// push with no button and no gesture. Android is untouched: the zoom
  /// transition, the app-bar back button and the system back gesture stay.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
