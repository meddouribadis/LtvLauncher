
import 'dart:typed_data';

import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/add_to_category_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class AppDetailsPage extends StatelessWidget {
  static const String routeName = "app_details_page";

  final App application;

  const AppDetailsPage({Key? key, required this.application}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    AppsService appsService = context.watch<AppsService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FutureBuilder<Uint8List>(
              future: appsService.getAppIcon(application.packageName),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data!, width: 50, height: 50);
                }
                return const Icon(Icons.android, size: 50);
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    "v${application.version}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        Expanded(
          child: ListView(
            children: [
              _buildListTile(
                context,
                icon: Icons.open_in_new,
                title: localizations.open,
                onTap: () async {
                  await appsService.launchApp(application);
                  Navigator.of(context).pop(); // Close settings after launch? Or stay? Dialog behavior was close.
                },
              ),
              _buildListTile(
                context,
                icon: appsService.isAppInFavorites(application) ? Icons.star : Icons.star_border,
                title: appsService.isAppInFavorites(application) ? 'Remove from Fav' : 'Add to Fav',
                onTap: () => appsService.toggleFavorite(application),
              ),
              _buildListTile(
                context,
                icon: application.hidden ? Icons.visibility : Icons.visibility_off_outlined,
                title: application.hidden ? localizations.show : localizations.hide,
                onTap: () {
                   if (application.hidden) {
                     appsService.showApplication(application);
                   } else {
                     appsService.hideApplication(application);
                   }
                },
              ),
              if (!application.hidden)
                _buildListTile(
                  context,
                  icon: Icons.add_box_outlined,
                  title: "Add to Category", // Need localization or string
                  onTap: () => showDialog<Category>(
                    context: context,
                    builder: (_) => AddToCategoryDialog(application),
                  ),
                ),
              const Divider(),
              _buildListTile(
                context,
                icon: Icons.info_outlined,
                title: localizations.appInfo,
                onTap: () => appsService.openAppInfo(application),
              ),
              _buildListTile(
                context,
                icon: Icons.delete_outlined,
                title: localizations.uninstall,
                onTap: () async {
                    await appsService.uninstallApp(application);
                    Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // Add hover/focus color if needed, but default ListTile focus usually works.
      // We can enhance it later if the user requests specific aesthetics for these details too.
    );
  }
}
