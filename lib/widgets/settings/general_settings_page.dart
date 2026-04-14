/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'focusable_settings_tile.dart';
import 'brightness_settings_page.dart';
import 'date_time_format_page.dart';
import 'back_button_action_page.dart';
import 'wifi_usage_period_page.dart';
import 'screensaver_clock_style_page.dart';


class GeneralSettingsPage extends StatelessWidget {
  static const String routeName = "general_settings_panel";

  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text('System', style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.brightness_6),
                  title: Text('Brightness Scheduler', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(BrightnessSettingsPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.screenshot_monitor),
                  title: Text('Screensaver Settings', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => _openScreensaverSettings(),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.watch_later_outlined),
                  title: Text('Screensaver Clock Style', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(ScreensaverClockStylePage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(localizations.dateAndTimeFormat, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(DateTimeFormatPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.arrow_back),
                  title: Text(localizations.backButtonAction, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(BackButtonActionPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.wifi),
                  title: Text('WiFi Usage Period', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(WifiUsagePeriodPage.routeName),
                ),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openScreensaverSettings() async {
    const platform = MethodChannel('me.efesser.flauncher/method');
    platform.invokeMethod('openScreensaverSettings');
  }
}
