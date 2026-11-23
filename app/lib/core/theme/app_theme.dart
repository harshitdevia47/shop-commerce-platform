import 'package:material_ui/material_ui.dart';

import '../config/client_config.dart';

/// Builds the app theme from the client's brand colours. No hard-coded brand colours elsewhere.
ThemeData buildAppTheme(ClientConfig client, {Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(seedColor: client.primaryColor, brightness: brightness).copyWith(
    primary: brightness == Brightness.light ? client.primaryColor : null,
    secondary: client.secondaryColor,
    surface: brightness == Brightness.light ? client.surfaceColor : null,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, centerTitle: false),
    // Tabs sit in the brand-coloured app bar.
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onPrimary,
      unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
      indicatorColor: scheme.onPrimary,
      dividerColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))),
  );
}
