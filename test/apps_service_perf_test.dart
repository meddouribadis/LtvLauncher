import 'package:flutter_test/flutter_test.dart';

import 'package:flauncher/database.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';

void main() {
  test('Benchmark apps categories grouping', () {
    int numApps = 2000;
    int numCategories = 10;

    List<AppCategory> appsCategories = [];
    Map<String, App> _applications = {};
    Map<int, Category> _categoriesById = {};

    for (int i = 0; i < numCategories; i++) {
      _categoriesById[i] = Category(
        id: i,
        name: "Cat $i",
        type: CategoryType.grid,
        sort: CategorySort.manual,
        columnsCount: 4,
        rowHeight: 100,
        order: i,
      );
    }

    for (int i = 0; i < numApps; i++) {
      String pkg = "com.example.app$i";
      _applications[pkg] = App(
        packageName: pkg,
        name: "App $i",
        version: "1.0",
        hidden: false,
      );
      appsCategories.add(AppCategory(
        categoryId: i % numCategories,
        appPackageName: pkg,
        order: i,
      ));
      appsCategories.add(AppCategory(
        categoryId: (i + 1) % numCategories,
        appPackageName: pkg,
        order: i,
      ));
    }

    // Original O(N*M)
    Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      for (App application in _applications.values) {
        if (appsCategories.isNotEmpty && !application.hidden) {
          Iterable<AppCategory> currentApplicationCategories = appsCategories
              .where((appCategory) => appCategory.appPackageName == application.packageName);

          for (AppCategory appCategory in currentApplicationCategories) {
            if (_categoriesById.containsKey(appCategory.categoryId)) {
              Category category = _categoriesById[appCategory.categoryId]!;
              application.categoryOrders[category.id] = appCategory.order;
            }
          }
        }
      }
    }
    sw.stop();
    print("Original time: " + sw.elapsedMilliseconds.toString() + " ms");

    // Optimized O(N+M)
    sw.reset();
    sw.start();
    for (int i = 0; i < 100; i++) {
      Map<String, List<AppCategory>> appsCategoriesByPackage = {};
      if (appsCategories.isNotEmpty) {
        for (AppCategory appCategory in appsCategories) {
          (appsCategoriesByPackage[appCategory.appPackageName] ??= []).add(appCategory);
        }
      }

      for (App application in _applications.values) {
        if (appsCategories.isNotEmpty && !application.hidden) {
          List<AppCategory>? currentApplicationCategories = appsCategoriesByPackage[application.packageName];

          if (currentApplicationCategories != null) {
            for (AppCategory appCategory in currentApplicationCategories) {
              if (_categoriesById.containsKey(appCategory.categoryId)) {
                Category category = _categoriesById[appCategory.categoryId]!;
                application.categoryOrders[category.id] = appCategory.order;
              }
            }
          }
        }
      }
    }
    sw.stop();
    print("Optimized time: " + sw.elapsedMilliseconds.toString() + " ms");
  });
}
