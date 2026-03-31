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

import 'dart:collection';

import 'app.dart';

enum LauncherSectionType
{
  Category,
  Spacer
}

enum CategorySort
{
  manual,
  alphabetical,
  lastUsed,
}

enum CategoryType
{
  row,
  grid,
}

class LauncherSection
{
  final int id;

  int order;

  LauncherSection({
    this.id = 0,
    this.order = 0
  });
}

class Category extends LauncherSection
{
  static const int          ColumnsCount  = 6;
  static const int          RowHeight     = 110;
  static const CategorySort Sort          = CategorySort.manual;
  static const CategoryType Type          = CategoryType.grid;

  int columnsCount;

  int rowHeight;

  String name;

  CategorySort sort;

  CategoryType type;

  final List<App> applications;

  Category({
    required this.name,
    int id = 0,
    int order = 0,
    this.columnsCount = Category.ColumnsCount,
    this.rowHeight = Category.RowHeight,
    this.sort = Category.Sort,
    this.type = Category.Type
  }):   applications = [],
        super(id: id, order: order);

  Category.withApplications({
    required this.name,
    required this.applications,
    int id = 0,
    int order = 0,
    this.columnsCount = Category.ColumnsCount,
    this.rowHeight = Category.RowHeight,
    this.sort = Category.Sort,
    this.type = Category.Type
  }): super(id: id, order: order);

  Category unmodifiable() {
    return Category.withApplications(
      name: name,
      id: id,
      order: order,
      columnsCount: columnsCount,
      rowHeight: rowHeight,
      sort: sort,
      type: type,
      applications: UnmodifiableListView(applications));
  }
}

class LauncherSpacer extends LauncherSection
{
  int height;

  LauncherSpacer({
    int id = 0,
    int order = 0,
    this.height = 0
  }): super(id: id, order: order);
}