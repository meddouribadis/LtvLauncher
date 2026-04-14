/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/actions.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'flauncher.dart';

class FLauncherApp extends StatelessWidget
{
  static const PrioritizedIntents _backIntents = PrioritizedIntents(orderedIntents: [
    DismissIntent(),
    BackIntent()
  ]);

  const FLauncherApp();

  @override
  Widget build(BuildContext context) {
    AppsService appsService = context.read<AppsService>();
    LauncherState launcherState = context.read<LauncherState>();
    launcherState.refresh(appsService);

    return Selector<SettingsService, Color>(
      selector: (_, settings) => settings.accentColor,
      builder: (context, accentColor, _) {

        return MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): _backIntents,
        const SingleActivator(LogicalKeyboardKey.gameButtonB): _backIntents,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent()
      },
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: BackAction(context),
        DirectionalFocusIntent: SoundFeedbackDirectionalFocusAction(context)
      },
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'FLauncher',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          // Use ColorScheme based on accent color
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
            primary: accentColor,
            secondary: accentColor,
            surface: const Color(0xFF1E1E1E),
            background: const Color(0xFF121212),
          ),
          cardColor: const Color(0xFF1E1E1E), // Dark surface color
          canvasColor: const Color(0xFF121212), // Dark background
          dialogBackgroundColor: const Color(0xFF1E1E1E),
          scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // Revert to white for settings list
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              )
          ),
          dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFF1E1E1E),
            titleTextStyle: Typography.material2018().white.titleLarge,
            contentTextStyle: Typography.material2018().white.bodyMedium,
          ),
          appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent),
          typography: Typography.material2018(),
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            labelStyle: Typography.material2018().white.bodyMedium,
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: accentColor,
            selectionColor: accentColor.withOpacity(0.4),
            selectionHandleColor: accentColor,
          ),
          // Override indicator colors for focus
          indicatorColor: accentColor,
          progressIndicatorTheme: ProgressIndicatorThemeData(color: accentColor),
          sliderTheme: SliderThemeData(
            activeTrackColor: accentColor,
            thumbColor: accentColor,
            inactiveTrackColor: accentColor.withOpacity(0.3),
          ),
          toggleButtonsTheme: ToggleButtonsThemeData(
            selectedColor: accentColor,
            fillColor: accentColor.withOpacity(0.1),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor;
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor.withOpacity(0.5);
              return null;
            }),
          ),
        ),
      home: Builder(
        builder: (context) => PopScope(
          canPop: false,
          child: ExcludeSemantics(
            child: FLauncher(),
          ),
          onPopInvoked: (didPop) {
            LauncherState launcherState = context.read<LauncherState>();
            launcherState.handleBackNavigation(context);
          }
        )
      ),
      );
    });
  }
}
