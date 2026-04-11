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

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LTvLauncherAboutDialog extends StatelessWidget {
  final PackageInfo packageInfo;

  LTvLauncherAboutDialog({
    Key? key,
    required this.packageInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return AboutDialog(
      applicationName: "Arc Launcher",
      applicationVersion: "v${packageInfo.version} (${packageInfo.buildNumber})",
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset("assets/icon.png", height: 72),
      ),
      applicationLegalese: "Developed by Badis Meddouri\nBased on LTvLauncher © 2026 LeanBitLab",
      children: [
        SizedBox(height: 24),
        Text(localizations.textAboutDialog("https://github.com/meddouribadis/arclauncher"))
      ],
    );
  }
}
