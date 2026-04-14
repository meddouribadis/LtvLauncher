import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'ensure_visible.dart';

Widget categoryContainerEmptyState(BuildContext context) {
  AppLocalizations localizations = AppLocalizations.of(context)!;

  return SizedBox(
    height: 110,
    child: EnsureVisible(
      // This specific alignment value is not only
      // to center the focused card in the row while
      // scrolling, but to prevent the topmost category
      // title to be hidden by the content above it when
      // scrolling from the app bar. How it relates to this,
      // I don't know
      alignment: 0.5,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => SettingsPanel(initialRoute: LauncherSectionsPanelPage.routeName),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      localizations.textEmptyCategory,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
