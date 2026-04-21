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

import 'dart:math';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';
import '../providers/settings_service.dart';
import 'category_container_common.dart';

class AppsGrid extends StatelessWidget
{
  final Category category;
  final List<App> applications;

  final bool isFirstSection;

  AppsGrid({
    Key? key,
    required this.category,
    required this.applications,
    this.isFirstSection = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget categoryContent;
    if (applications.isEmpty) {
      categoryContent = categoryContainerEmptyState(context);
    }
    else {
      categoryContent = GridView.custom(
        primary: false,
        shrinkWrap: true,
        gridDelegate: _buildSliverGridDelegate(),
        padding: EdgeInsets.all(16),
        childrenDelegate: SliverChildBuilderDelegate(
          childCount: applications.length,
          findChildIndexCallback: _findChildIndex,
          (context, index) {
            final isFirstInRow = index % category.columnsCount == 0;
            final isLastInRow = index % category.columnsCount == category.columnsCount - 1 || index == applications.length - 1;

            return AppCard(
              key: Key(applications[index].packageName),
              category: category,
              application: applications[index],
              autofocus: index == 0,
              handleUpNavigationToSettings: isFirstSection && index < category.columnsCount,
              isFirstInRow: isFirstInRow,
              isLastInRow: isLastInRow,
              onMove: (direction) => _onMove(context, direction, index),
              onMoveEnd: () => _saveOrder(context)
            );
          }
        )
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selector<SettingsService, bool>(
          selector: (context, service) => service.showCategoryTitles,
          builder: (context, showCategoriesTitle, _) {
            if (showCategoriesTitle) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(category.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(shadows: [const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)])
                ),
              );
            }

            return SizedBox.shrink();
          }
        ),
        categoryContent
      ],
    );
  }


  int? _findChildIndex(Key key) {
    final valueKey = key as ValueKey<String>;
    final index = applications.indexWhere((app) => app.packageName == valueKey.value);
    return index >= 0 ? index : null;
  }

  void _onMove(BuildContext context, AxisDirection direction, int index) {
    final currentRow = (index / category.columnsCount).floor();
    final totalRows = ((applications.length - 1) / category.columnsCount).floor();

    int? newIndex;
    switch (direction) {
      case AxisDirection.up:
        if (currentRow > 0) {
          newIndex = index - category.columnsCount;
        }
        // At top boundary - do nothing
        break;
      case AxisDirection.right:
        if (index < applications.length - 1) {
          newIndex = index + 1;
        }
        break;
      case AxisDirection.down:
        if (currentRow < totalRows) {
          newIndex = min(index + category.columnsCount, applications.length - 1);
        }
        // At bottom boundary - do nothing
        break;
      case AxisDirection.left:
        if (index > 0) {
          newIndex = index - 1;
        }
        break;
    }
    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      final movingApp = applications[index];
      
      appsService.reorderApplication(category, index, newIndex);
      
      // Set pending focus so the app at the new position will request focus
      appsService.setPendingReorderFocus(movingApp.packageName, category.id);
    }
  }

  void _saveOrder(BuildContext context) {
    final appsService = context.read<AppsService>();
    appsService.saveApplicationOrderInCategory(category);
  }

  SliverGridDelegate _buildSliverGridDelegate() => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: category.columnsCount,
        childAspectRatio: 16 / 9,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      );

}
