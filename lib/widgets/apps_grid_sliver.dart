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

import '../models/category.dart';

class AppsGridSliver extends StatelessWidget {
  final Category category;
  final bool isFirstSection;

  const AppsGridSliver({
    super.key,
    required this.category,
    this.isFirstSection = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: category.columnsCount,
        childAspectRatio: 16 / 9,
        mainAxisSpacing: 12,
        crossAxisSpacing: 0,
      ),
      delegate: SliverChildBuilderDelegate(
        childCount: category.applications.length,
        findChildIndexCallback: (Key key) {
          final valueKey = key as ValueKey<String>;
          final index = category.applications
              .indexWhere((app) => app.packageName == valueKey.value);
          return index >= 0 ? index : null;
        },
        (context, index) => Padding(
          key: ValueKey(category.applications[index].packageName),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: RepaintBoundary(
            child: AppCard(
              category: category,
              application: category.applications[index],
              autofocus: index == 0,
              handleUpNavigationToSettings:
                  isFirstSection && index < category.columnsCount,
              onMove: (direction) => _onMove(context, index, direction),
              onMoveEnd: () => context
                  .read<AppsService>()
                  .saveApplicationOrderInCategory(category),
            ),
          ),
        ),
      ),
    );
  }

  void _onMove(BuildContext context, int index, AxisDirection direction) {
    final applications = category.applications;
    final currentRow = (index / category.columnsCount).floor();
    final totalRows =
        ((applications.length - 1) / category.columnsCount).floor();

    int? newIndex;
    switch (direction) {
      case AxisDirection.up:
        if (currentRow > 0) newIndex = index - category.columnsCount;
        break;
      case AxisDirection.right:
        if (index < applications.length - 1) newIndex = index + 1;
        break;
      case AxisDirection.down:
        if (currentRow < totalRows) {
          newIndex =
              min(index + category.columnsCount, applications.length - 1);
        }
        break;
      case AxisDirection.left:
        if (index > 0) newIndex = index - 1;
        break;
    }

    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      final movingApp = applications[index];
      appsService.reorderApplication(category, index, newIndex);
      appsService.setPendingReorderFocus(movingApp.packageName, category.id);
    }
  }
}
