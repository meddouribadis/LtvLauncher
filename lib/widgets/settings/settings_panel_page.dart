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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/interface_settings_page.dart';
import 'package:flauncher/widgets/settings/update_dialogs.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'focusable_settings_tile.dart';

class SettingsPanelPage extends StatelessWidget {
  static const String routeName = "settings_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(localizations.settings, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.apps),
                  title: Text(localizations.applications, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(ApplicationsPanelPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.auto_awesome_mosaic_outlined),
                  title: Text('Interface', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(InterfaceSettingsPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.settings_suggest_outlined),
                  title: Text('System', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(GeneralSettingsPage.routeName),
                ),
                const Divider(),
                FocusableSettingsTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(localizations.systemSettings, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => context.read<AppsService>().openSettings(),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: Text(localizations.updateCheck, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => _checkForUpdates(context),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(localizations.aboutFlauncher, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && snapshot.hasData
                          ? LTvLauncherAboutDialog(packageInfo: snapshot.data!)
                          : Container(),
                    )))
      ])))
    ]);
  }
}

Future<void> _checkForUpdates(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final updateService = UpdateService();
  final navigator = Navigator.of(context, rootNavigator: true);

  showUpdateProgressDialog(
    context,
    label: localizations.updateCheck,
  );

  try {
    final update = await updateService.checkForUpdate();
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }

    if (!update.updateAvailable) {
      await showNoUpdateDialog(
        context,
        localizations,
        currentVersion: update.currentVersion,
      );
      return;
    }

    final download = await showUpdateAvailableDialog(
      context,
      localizations,
      latestVersion: update.latestVersion,
      currentVersion: update.currentVersion,
    );

    if (!download) {
      return;
    }

    showUpdateProgressDialog(
      context,
      label: localizations.updateDownloadButton,
    );

    final downloadedApk = await updateService.downloadApk(update);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }

    final install = await showReadyToInstallDialog(
      context,
      localizations,
      latestVersion: downloadedApk.version,
    );

    if (!install) {
      return;
    }

    final installerOpened = await updateService.installApk(downloadedApk.path);
    if (!context.mounted || installerOpened) {
      return;
    }

    await showInstallPermissionDialog(
      context,
      localizations,
      onOpenPermissionSettings: () =>
          updateService.requestInstallUnknownAppsPermission(),
    );
  } catch (_) {
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.updateErrorGeneric)),
    );
  }
}
