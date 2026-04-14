import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../models/app.dart';
import '../models/category.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';

class AddToCategoryDialog extends StatelessWidget {
  final App selectedApplication;

  AddToCategoryDialog(this.selectedApplication);

  @override
  Widget build(BuildContext context) => Selector<AppsService, List<Category>>(
        selector: (_, appsService) => appsService.categories
            .where((category) => !category.applications.any((application) => application.packageName == selectedApplication.packageName))
            .toList(),
        builder: (context, categories, _) {
          AppLocalizations localizations = AppLocalizations.of(context)!;

          return SidePanelDialog(
            width: 300,
            isRightSide: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.withEllipsisAddTo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () async {
                            await context.read<AppsService>().addToCategory(selectedApplication, category);
                            Navigator.of(context).pop();
                          },
                          title: Text(category.name),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
}
