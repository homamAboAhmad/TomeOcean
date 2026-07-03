import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/HomePage.dart';
import 'package:golden_shamela/UI/Search/search_window_route.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/core/app_state.dart';

/// مسؤول عن إدارة التوجيه في التطبيق
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomePage(),
      search: (context) => const SearchWindowRoute(),
    };
  }
}

/// تطبيق Flutter الرئيسي
class MyApp extends StatefulWidget {
  final String? initialRoute;

  const MyApp({Key? key, this.initialRoute}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final appState = AppState();

    return AnimatedBuilder(
      animation: Listenable.merge([
        AppFontSettings.instance,
        AppColorSettings.instance,
        AppOtherSettings.instance,
      ]),
      builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المكتبة',
      theme: _appTheme(),
      navigatorKey: appState.navigatorKey,
      initialRoute: widget.initialRoute ?? AppRoutes.home,
      routes: AppRoutes.getRoutes(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      ),
    );
  }

  ThemeData _appTheme() {
    final base = ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        tertiary: actionColor,
        surface: surfaceColor,
        onSurface: accentColor,
        error: destructiveColor,
        outline: borderColor,
      ),
      scaffoldBackgroundColor: bgColor,
    );
    final textTheme = AppTypography.textTheme(base.textTheme);
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: AppTypography.textTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor.withOpacity(0.75),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: accentColor.withOpacity(0.62),
        ),
        labelStyle: textTheme.bodyMedium,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
          borderSide: AppChrome.borderSide(),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
          borderSide: const BorderSide(color: destructiveColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppChrome.radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppChrome.radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppChrome.radius),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: primaryColor,
        selectedColor: primaryColor,
        selectedTileColor: organicHighlightColor,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: accentColor.withOpacity(0.72),
        indicatorColor: actionColor,
        dividerColor: borderColor,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.18),
        thumbColor: actionColor,
        overlayColor: actionColor.withOpacity(0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
