/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
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

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../../providers/settings_service.dart';

class StatusBarPanelPage extends StatelessWidget {
  static const String routeName = "status_bar_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
        children: [
          Text(localizations.statusBar, style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                RoundedSwitchListTile(
                  autofocus: true,
                  value: settingsService.autoHideAppBarEnabled,
                  onChanged: (value) => settingsService.setAutoHideAppBarEnabled(value),
                  title: Text(localizations.autoHideAppBar, style: Theme.of(context).textTheme.bodyMedium),
                  secondary: Icon(Icons.visibility_off_outlined),
                ),
                Divider(),
                RoundedSwitchListTile(
                  value: settingsService.showDateInStatusBar,
                  onChanged: (value) => settingsService.setShowDateInStatusBar(value),
                  title: Text(localizations.date),
                  secondary: Icon(Icons.calendar_today_outlined)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showTimeInStatusBar,
                  onChanged: (value) => settingsService.setShowTimeInStatusBar(value),
                  title: Text(localizations.time),
                  secondary: Icon(Icons.watch_later_outlined)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showWifiWidgetInStatusBar,
                  onChanged: (value) => settingsService.setShowWifiWidgetInStatusBar(value),
                  title: Text('WiFi Usage'),
                  secondary: Icon(Icons.wifi)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showNetworkIndicatorInStatusBar,
                  onChanged: (value) => settingsService.setShowNetworkIndicatorInStatusBar(value),
                  title: Text('Network Indicator'),
                  secondary: Icon(Icons.signal_wifi_4_bar)
                ),
              ],
            ),
          ),
        ],
      );
  }
}
