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

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:collection/collection.dart' as collection;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart' hide Category;

import '../models/app.dart';
import '../models/category.dart';

class AppsService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final FLauncherDatabase _database;

  bool _initialized = false;

  List<LauncherSection> _launcherSections = List.empty(growable: true);
  Map<String, App> _applications = Map();
  Map<String, Uint8List> _iconCache = Map();
  Map<String, Uint8List> _bannerCache = Map();

  Map<int, Category> _categoriesById = Map();

  // Cached SharedPreferences instance to avoid repeated disk I/O
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _prefsAsync async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool get initialized => _initialized;

  String? _pendingReorderFocusPackage;
  int? _pendingReorderFocusCategoryId;
  String? get pendingReorderFocusPackage => _pendingReorderFocusPackage;
  int? get pendingReorderFocusCategoryId => _pendingReorderFocusCategoryId;
  void clearPendingReorderFocusPackage() {
    _pendingReorderFocusPackage = null;
    _pendingReorderFocusCategoryId = null;
  }

  void setPendingReorderFocus(String packageName, int categoryId) {
    _pendingReorderFocusPackage = packageName;
    _pendingReorderFocusCategoryId = categoryId;
  }

  List<App> get applications => UnmodifiableListView(
      _applications.values.sortedBy((application) => application.name));

  List<LauncherSection> get launcherSections =>
      List.unmodifiable(_launcherSections);
  List<Category> get categories => _categoriesById.values
      .map((category) => category.unmodifiable())
      .toList(growable: false);

  AppsService(this._fLauncherChannel, this._database) {
    _init();
  }

  Future<void> _init() async {
    await _refreshState(shouldNotifyListeners: false);
    if (_database.wasCreated) {
      await _initDefaultCategories();
    }

    _fLauncherChannel.addAppsChangedListener((event) async {
      String? changedPackageName;
      if (event.containsKey('packageName')) {
        changedPackageName = event['packageName'];
      } else if (event.containsKey('activityInfo')) {
        changedPackageName = event['activityInfo']['packageName'];
      }

      if (changedPackageName != null) {
        _iconCache.remove(changedPackageName);
        _bannerCache.remove(changedPackageName);
      }

      switch (event["action"]) {
        case "PACKAGE_ADDED":
        case "PACKAGE_CHANGED":
          Map<dynamic, dynamic> applicationInfo = event['activityInfo'];
          await _database.persistApps([_buildAppCompanion(applicationInfo)]);

          App newApp = App.fromSystem(applicationInfo);
          App? existingApp = _applications[newApp.packageName];

          if (existingApp != null) {
            newApp.hidden = existingApp.hidden;
            newApp.categoryOrders = Map.from(existingApp.categoryOrders);
            for (int categoryId in newApp.categoryOrders.keys) {
              final category = _categoriesById[categoryId];
              if (category != null) {
                int index = category.applications.indexOf(existingApp);
                if (index != -1) {
                  category.applications[index] = newApp;
                } else {
                  category.applications.add(newApp);
                }
              }
            }
            _applications[newApp.packageName] = newApp;
          } else {
            _applications[newApp.packageName] = newApp;
            final targetCategory =
                _findTargetCategoryForNewApp(newApp.sideloaded);
            if (targetCategory != null) {
              await addToCategory(newApp, targetCategory,
                  shouldNotifyListeners: false);
            }
          }
          break;
        case "PACKAGES_AVAILABLE":
          List<dynamic> applicationsInfo = event["activitiesInfo"];
          await _database
              .persistApps((applicationsInfo).map(_buildAppCompanion));

          for (Map<dynamic, dynamic> applicationInfo in applicationsInfo) {
            App newApp = App.fromSystem(applicationInfo);
            App? existingApp = _applications[newApp.packageName];

            if (existingApp != null) {
              newApp.hidden = existingApp.hidden;
              newApp.categoryOrders = Map.from(existingApp.categoryOrders);
              for (int categoryId in newApp.categoryOrders.keys) {
                final category = _categoriesById[categoryId];
                if (category != null) {
                  int index = category.applications.indexOf(existingApp);
                  if (index != -1) {
                    category.applications[index] = newApp;
                  } else {
                    category.applications.add(newApp);
                  }
                }
              }
              _applications[newApp.packageName] = newApp;
            } else {
              _applications[newApp.packageName] = newApp;
            }
            _iconCache.remove(newApp.packageName);
            _bannerCache.remove(newApp.packageName);
          }
          break;
        case "PACKAGE_REMOVED":
          String packageName = event['packageName'];
          await _database.deleteApps([packageName]);

          // Clear icon cache for removed app
          _iconCache.remove(packageName);
          _bannerCache.remove(packageName);

          App? application = _applications.remove(packageName);

          if (application != null) {
            for (int categoryId in application.categoryOrders.keys) {
              final category = _categoriesById[categoryId];
              if (category != null) {
                category.applications.remove(application);
              }
            }
          }
          break;
      }

      notifyListeners();
    });

    _initialized = true;
    notifyListeners();

    // Pre-cache icons for visible apps
    _preCacheIcons();
  }

  Future<void> _preCacheIcons() async {
    // Only cache apps that are not hidden
    final visibleApps =
        _applications.values.where((app) => !app.hidden).toList();
    for (var app in visibleApps) {
      // Don't await, let it run in background
      getAppIcon(app.packageName);
      // Also cache banner if it's likely to be needed soon
      getAppBanner(app.packageName);
    }
  }

  AppsCompanion _buildAppCompanion(dynamic data) {
    String? version = data["version"];
    if (version == null) {
      version = "";
    }

    return AppsCompanion(
        packageName: Value(data["packageName"]),
        name: Value(data["name"]),
        version: Value(version),
        hidden: const Value.absent());
  }

  Future<void> _initDefaultCategories() {
    final tvApplications = _applications.values
        .where((application) => application.sideloaded == false);
    final nonTvApplications = _applications.values
        .where((application) => application.sideloaded == true);

    return _database.transaction(() async {
      if (nonTvApplications.isNotEmpty) {
        int categoryId = await addCategory(
          "Non-TV Apps",
          shouldNotifyListeners: false,
        );
        Category nonTvAppsCategory = _categoriesById[categoryId]!;
        for (final app in nonTvApplications) {
          await addToCategory(app, nonTvAppsCategory,
              shouldNotifyListeners: false);
        }
      }

      if (tvApplications.isNotEmpty) {
        int categoryId = await addCategory("TV Apps",
            type: CategoryType.grid, shouldNotifyListeners: false);

        Category tvAppsCategory = _categoriesById[categoryId]!;
        for (final app in tvApplications) {
          await addToCategory(app, tvAppsCategory,
              shouldNotifyListeners: false);
        }
      }

      await addCategory("Favorites", shouldNotifyListeners: false);
    });
  }

  Future<void> _refreshState({bool shouldNotifyListeners = true}) async {
    Future<List<App>> appsFromDatabaseFuture = _database.getApplications();
    Future<List<AppCategory>> appsCategoriesFuture =
        _database.getAppsCategories();
    Future<List<Category>> categoriesFuture = _database.getCategories();
    Future<List<LauncherSpacer>> spacersFuture = _database.getLauncherSpacers();
    List<Map<dynamic, dynamic>> appsFromSystem =
        await _fLauncherChannel.getApplications();
    Iterable<MapEntry<String, (Map, AppsCompanion)>> appEntries =
        appsFromSystem.map((appFromSystem) => new MapEntry(
            appFromSystem['packageName'],
            (appFromSystem, _buildAppCompanion(appFromSystem))));
    Map<String, (Map, AppsCompanion)> appsFromSystemByPackageName =
        Map.fromEntries(appEntries);

    List<App> appsFromDatabase = await appsFromDatabaseFuture;
    final Iterable<App> appsRemovedFromSystem = appsFromDatabase.where(
        (app) => !appsFromSystemByPackageName.containsKey(app.packageName));

    final List<String> uninstalledApplications =
        appsRemovedFromSystem.map((app) => app.packageName).toList();

    await _database.transaction(() async {
      await _database.persistApps(
          appsFromSystemByPackageName.values.map((record) => record.$2));
      await _database.deleteApps(uninstalledApplications);
    });

    appsFromDatabaseFuture = _database.getApplications();

    await Future.wait([
      appsFromDatabaseFuture,
      appsCategoriesFuture,
      categoriesFuture,
      spacersFuture
    ]);

    appsFromDatabase = await appsFromDatabaseFuture;
    List<AppCategory> appsCategories = await appsCategoriesFuture;
    List<Category> categories = await categoriesFuture;
    List<LauncherSpacer> spacers = await spacersFuture;

    _categoriesById = Map.fromEntries(
        categories.map((category) => MapEntry(category.id, category)));
    _applications = Map.fromEntries(appsFromDatabase
        .map((application) => MapEntry(application.packageName, application)));

    _launcherSections.clear();
    _launcherSections.addAll(categories);
    _launcherSections.addAll(spacers);
    _launcherSections.sort((ls0, ls1) => ls0.order.compareTo(ls1.order));

    Map<String, List<AppCategory>> appsCategoriesByPackage = {};
    if (appsCategories.isNotEmpty) {
      for (AppCategory appCategory in appsCategories) {
        (appsCategoriesByPackage[appCategory.appPackageName] ??= [])
            .add(appCategory);
      }
    }

    for (App application in _applications.values) {
      Map? applicationFromSystem =
          appsFromSystemByPackageName[application.packageName]?.$1;

      if (applicationFromSystem != null) {
        if (applicationFromSystem.containsKey('action')) {
          application.action = applicationFromSystem['action'];
        }
        if (applicationFromSystem.containsKey('sideloaded')) {
          application.sideloaded = applicationFromSystem['sideloaded'];
        }
      }

      if (appsCategories.isNotEmpty && !application.hidden) {
        List<AppCategory>? currentApplicationCategories =
            appsCategoriesByPackage[application.packageName];

        if (currentApplicationCategories != null) {
          for (AppCategory appCategory in currentApplicationCategories) {
            final category = _categoriesById[appCategory.categoryId];
            if (category != null) {
              application.categoryOrders[category.id] = appCategory.order;
              category.applications.add(application);
            }
          }
        }
      }
    }

    for (Category category in _categoriesById.values) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  void sortCategory(Category category) {
    if (category.sort == CategorySort.alphabetical) {
      category.applications.sortBy((application) => application.name);
    } else if (category.sort == CategorySort.lastUsed) {
      category.applications.sort((a, b) {
        final aTime =
            a.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // Descending (newest first)
      });
    } else {
      category.applications.sortBy<num>(
          (application) => application.categoryOrders[category.id]!);
    }
  }

  /// Finds the appropriate category for a newly installed app.
  /// Returns "TV Apps" for TV apps, "Non-TV Apps" for sideloaded apps,
  /// or falls back to first non-Favorites category if defaults don't exist.
  Category? _findTargetCategoryForNewApp(bool isSideloaded) {
    final targetName = isSideloaded ? "non-tv apps" : "tv apps";
    return _categoriesById.values.firstWhere(
      (c) => c.name.toLowerCase() == targetName,
      orElse: () {
        // Fallback: first non-favorites category
        return _categoriesById.values.firstWhere(
          (c) => c.name.toLowerCase() != 'favorites',
          orElse: () => _categoriesById.values.first,
        );
      },
    );
  }

  Future<Uint8List> getAppBanner(String packageName) async {
    if (_bannerCache.containsKey(packageName)) {
      return _bannerCache[packageName]!;
    }

    try {
      final prefs = await _prefsAsync;
      final customBannerPath = prefs.getString('custom_banner_$packageName');
      if (customBannerPath != null) {
        final file = File(customBannerPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _bannerCache[packageName] = bytes;
          return bytes;
        }
      }
    } on FileSystemException {
      // File was deleted between check and read - clear stale reference
      final prefs = await _prefsAsync;
      await prefs.remove('custom_banner_$packageName');
    } catch (_) {
      // Ignore other errors reading custom banner
    }

    final bytes = await _fLauncherChannel.getApplicationBanner(packageName);
    if (bytes.isNotEmpty) {
      _bannerCache[packageName] = bytes;
    }
    return bytes;
  }

  Future<void> setCustomAppBanner(String packageName, String imagePath) async {
    final prefs = await _prefsAsync;
    await prefs.setString('custom_banner_$packageName', imagePath);
    _bannerCache.remove(packageName);
    notifyListeners();
  }

  Future<void> removeCustomAppBanner(String packageName) async {
    final prefs = await _prefsAsync;
    final customBannerPath = prefs.getString('custom_banner_$packageName');
    if (customBannerPath != null) {
      try {
        await File(customBannerPath).delete();
      } catch (_) {
        // Ignore file deletion errors
      }
    }
    await prefs.remove('custom_banner_$packageName');
    _bannerCache.remove(packageName);
    notifyListeners();
  }

  Future<bool> hasCustomBanner(String packageName) async {
    final prefs = await _prefsAsync;
    return prefs.containsKey('custom_banner_$packageName');
  }

  Future<Uint8List> getAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName]!;
    }
    final bytes = await _fLauncherChannel.getApplicationIcon(packageName);
    if (bytes.isNotEmpty) {
      _iconCache[packageName] = bytes;
    }
    return bytes;
  }

  Future<void> launchApp(App app) async {
    app.lastLaunchedAt = DateTime.now();
    await _database.updateApp(app.packageName,
        AppsCompanion(lastLaunchedAt: Value(app.lastLaunchedAt)));
    notifyListeners();

    Future<void> future;
    if (app.action == null) {
      future = _fLauncherChannel.launchApp(app.packageName);
    } else {
      future = _fLauncherChannel.launchActivityFromAction(app.action!);
    }

    return future;
  }

  Future<void> openAppInfo(App app) =>
      _fLauncherChannel.openAppInfo(app.packageName);

  Future<void> uninstallApp(App app) =>
      _fLauncherChannel.uninstallApp(app.packageName);

  Future<void> openSettings() => _fLauncherChannel.openSettings();

  Future<bool> isDefaultLauncher() => _fLauncherChannel.isDefaultLauncher();

  Future<void> startAmbientMode() => _fLauncherChannel.startAmbientMode();

  Future<void> addToCategory(App app, Category category,
      {bool shouldNotifyListeners = true}) async {
    int index = await _database.nextAppCategoryOrder(category.id) ?? 0;
    await _database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: category.id,
        appPackageName: app.packageName,
        order: index,
      )
    ]);

    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      app.categoryOrders[categoryFound.id] = index;
      categoryFound.applications.add(app);

      if (shouldNotifyListeners) {
        sortCategory(categoryFound);
        notifyListeners();
      }
    }
  }

  Future<void> removeFromCategory(App application, Category category) async {
    await _database.deleteAppCategory(category.id, application.packageName);
    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      application.categoryOrders.remove(categoryFound.id);
      categoryFound.applications.remove(application);

      notifyListeners();
    }
  }

  /// Auto-populates a category based on its special name
  /// For TV Apps: adds all non-sideloaded apps
  /// For Non-TV Apps: adds all sideloaded apps
  Future<void> autoPopulateCategory(Category category) async {
    // Get the actual category from internal map
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    Category actualCategory = _categoriesById[category.id]!;

    Iterable<App> appsToAdd;

    switch (actualCategory.name) {
      case 'TV Apps':
        appsToAdd =
            _applications.values.where((app) => !app.sideloaded && !app.hidden);
        break;
      case 'Non-TV Apps':
        appsToAdd =
            _applications.values.where((app) => app.sideloaded && !app.hidden);
        break;
      default:
        return; // Not a special category
    }

    if (appsToAdd.isEmpty) {
      return;
    }

    int nextOrder =
        await _database.nextAppCategoryOrder(actualCategory.id) ?? 0;
    List<AppsCategoriesCompanion> batch = [];

    for (final app in appsToAdd) {
      batch.add(AppsCategoriesCompanion.insert(
        categoryId: actualCategory.id,
        appPackageName: app.packageName,
        order: nextOrder,
      ));
      app.categoryOrders[actualCategory.id] = nextOrder;
      actualCategory.applications.add(app);
      nextOrder++;
    }

    await _database.insertAppsCategories(batch);
    sortCategory(actualCategory);
    notifyListeners();
  }

  // === FAVORITES METHODS ===

  /// Gets the Favorites category, creating it if it doesn't exist
  Future<Category> getOrCreateFavoritesCategory() async {
    // Look for existing Favorites category
    Category? favorites = _categoriesById.values
        .firstWhereOrNull((category) => category.name == 'Favorites');

    if (favorites != null) {
      return favorites;
    }

    // Create Favorites category if it doesn't exist
    int categoryId =
        await addCategory('Favorites', shouldNotifyListeners: false);
    return _categoriesById[categoryId]!;
  }

  /// Checks if an app is in the Favorites category
  bool isAppInFavorites(App app) {
    Category? favorites = _categoriesById.values
        .firstWhereOrNull((category) => category.name == 'Favorites');

    if (favorites == null) {
      return false;
    }

    return favorites.applications.any((a) => a.packageName == app.packageName);
  }

  /// Adds an app to Favorites
  Future<void> addToFavorites(App app) async {
    Category favorites = await getOrCreateFavoritesCategory();

    // Check if already in favorites
    if (!favorites.applications.any((a) => a.packageName == app.packageName)) {
      await addToCategory(app, favorites);
    }
  }

  /// Removes an app from Favorites
  Future<void> removeFromFavorites(App app) async {
    Category? favorites = _categoriesById.values
        .firstWhereOrNull((category) => category.name == 'Favorites');

    if (favorites != null) {
      await removeFromCategory(app, favorites);
    }
  }

  /// Toggles an app in/out of Favorites
  Future<void> toggleFavorite(App app) async {
    if (isAppInFavorites(app)) {
      await removeFromFavorites(app);
    } else {
      await addToFavorites(app);
    }
  }

  Future<void> saveApplicationOrderInCategory(Category category) async {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }

    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    List<AppsCategoriesCompanion> orderedAppCategories = [];

    for (int i = 0; i < applications.length; ++i) {
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(categoryFound.id),
        appPackageName: Value(applications[i].packageName),
        order: Value(i),
      ));
    }
    await _database.replaceAppsCategories(orderedAppCategories);
    notifyListeners();
  }

  Future<void> moveAppToAdjacentCategory(
      App app, Category currentCategory, AxisDirection direction) async {
    int currentSectionIndex = _launcherSections.indexOf(currentCategory);
    if (currentSectionIndex == -1) {
      return;
    }

    int targetSectionIndex = -1;
    Category? targetCategory;

    // Find next valid category (skip spacers)
    if (direction == AxisDirection.down) {
      for (int i = currentSectionIndex + 1; i < _launcherSections.length; i++) {
        if (_launcherSections[i] is Category) {
          targetSectionIndex = i;
          targetCategory = _launcherSections[i] as Category;
          break;
        }
      }
    } else if (direction == AxisDirection.up) {
      for (int i = currentSectionIndex - 1; i >= 0; i--) {
        if (_launcherSections[i] is Category) {
          targetSectionIndex = i;
          targetCategory = _launcherSections[i] as Category;
          break;
        }
      }
    }

    if (targetCategory == null) {
      return;
    }

    // Remove from current
    await removeFromCategory(app, currentCategory);

    // Set pending focus package so AppCard can reclaim focus and reorder mode
    _pendingReorderFocusPackage = app.packageName;

    // Add to target
    int newIndex = 0;
    if (direction == AxisDirection.up) {
      // If moving UP (to previous section), append to BOTTOM
      newIndex = await _database.nextAppCategoryOrder(targetCategory.id) ?? 0;
    } else {
      // If moving DOWN (to next section), insert at TOP (index 0)
      newIndex = 0;
    }

    // DB Insert Logic
    // 1. Get current items in target
    List<App> targetApps = targetCategory.applications;

    // 2. Adjust local list
    if (direction == AxisDirection.down) {
      targetApps.insert(0, app); // Insert at top
    } else {
      targetApps.add(app); // Insert at bottom
    }

    // 3. Update orders for all items in target category
    List<AppsCategoriesCompanion> orderedAppCategories = [];
    for (int i = 0; i < targetApps.length; ++i) {
      App a = targetApps[i];
      a.categoryOrders[targetCategory.id] = i; // Update local map
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(targetCategory.id),
        appPackageName: Value(a.packageName),
        order: Value(i),
      ));
    }

    // 4. Batch DB update
    await _database.replaceAppsCategories(orderedAppCategories);

    notifyListeners();
  }

  void reorderApplication(Category category, int oldIndex, int newIndex) {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    App application = applications.removeAt(oldIndex);
    applications.insert(newIndex, application);

    notifyListeners();
  }

  Future<int> addCategory(String categoryName,
      {CategorySort sort = Category.Sort,
      CategoryType type = Category.Type,
      int columnsCount = Category.ColumnsCount,
      int rowHeight = Category.RowHeight,
      bool shouldNotifyListeners = true}) async {
    List<CategoriesCompanion> orderedCategories = [];
    int categoryOrder = 1, newCategoryId = -1;
    for (Category category in _categoriesById.values) {
      orderedCategories.add(CategoriesCompanion(
          id: Value(category.id), order: Value(categoryOrder++)));
    }

    try {
      newCategoryId = await _database.transaction(() async {
        int newCategoryId = await _database.insertCategory(
            CategoriesCompanion.insert(name: categoryName, order: 0));
        await _database.updateCategories(orderedCategories);

        return newCategoryId;
      });

      Map<int, Category> newCategories = Map();
      Category newCategory = Category(
          id: newCategoryId,
          name: categoryName,
          sort: sort,
          type: type,
          columnsCount: columnsCount,
          rowHeight: rowHeight,
          order: 0);
      newCategories[newCategoryId] = newCategory;

      categoryOrder = 1;
      for (Category category in _categoriesById.values) {
        newCategories[category.id] = category;
        category.order = categoryOrder++;
      }

      _categoriesById = newCategories;
      _launcherSections.add(newCategory);

      if (shouldNotifyListeners) {
        notifyListeners();
      }
    } catch (ex) {}

    return newCategoryId;
  }

  Future<void> updateCategory(int categoryId, String name, CategorySort sort,
      CategoryType type, int columnsCount, int rowHeight,
      {bool shouldNotifyListeners = true}) async {
    Category? category = _categoriesById[categoryId];
    assert(category != null);

    await _database.updateCategory(
        categoryId,
        CategoriesCompanion(
            name: Value(name),
            sort: Value(sort),
            type: Value(type),
            columnsCount: Value(columnsCount),
            rowHeight: Value(rowHeight)));

    CategorySort oldSort = category!.sort;

    category.name = name;
    category.sort = sort;
    category.type = type;
    category.columnsCount = columnsCount;
    category.rowHeight = rowHeight;

    if (oldSort != sort) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> addSpacer(int height) async {
    int order = launcherSections.length;
    int spacerId = await _database.insertSpacer(
        LauncherSpacersCompanion.insert(height: height, order: order));

    _launcherSections
        .add(LauncherSpacer(id: spacerId, height: height, order: order));

    notifyListeners();
  }

  Future<void> updateSpacerHeight(LauncherSpacer spacer, int height) async {
    await _database.updateSpacer(
        spacer.id, LauncherSpacersCompanion(height: Value(height)));

    spacer.height = height;
    notifyListeners();
  }

  Future<void> renameCategory(Category category, String categoryName) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(name: Value(categoryName)));

    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      categoryFound.name = categoryName;
      notifyListeners();
    }
  }

  Future<void> deleteSection(int index) async {
    assert(index < _launcherSections.length);

    LauncherSection section = _launcherSections[index];
    if (section is Category) {
      await _database.deleteCategory(section.id);
      _categoriesById.remove(section.id);
    } else {
      await _database.deleteSpacer(section.id);
    }

    _launcherSections.removeAt(index);

    notifyListeners();
  }

  void moveSectionInMemory(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _launcherSections.length ||
        newIndex < 0 ||
        newIndex >= _launcherSections.length) return;

    final section = _launcherSections.removeAt(oldIndex);
    _launcherSections.insert(newIndex, section);
    notifyListeners();
  }

  Future<void> persistSectionsOrder() async {
    List<CategoriesCompanion> orderedCategories = [];
    List<LauncherSpacersCompanion> orderedSpacers = [];

    for (int i = 0; i < _launcherSections.length; ++i) {
      LauncherSection section = _launcherSections[i];
      // Update the order property on the object itself
      if (section is Category)
        section.order = i;
      else if (section is LauncherSpacer) section.order = i;

      if (section is Category) {
        orderedCategories
            .add(CategoriesCompanion(id: Value(section.id), order: Value(i)));
      } else {
        orderedSpacers.add(
            LauncherSpacersCompanion(id: Value(section.id), order: Value(i)));
      }
    }

    await Future.wait([
      _database.updateCategories(orderedCategories),
      _database.updateSpacers(orderedSpacers)
    ]);
  }

  Future<void> moveSection(int oldIndex, int newIndex) async {
    moveSectionInMemory(oldIndex, newIndex);
    await persistSectionsOrder();
  }

  Future<void> hideApplication(App application) async {
    await _database.updateApp(
        application.packageName, const AppsCompanion(hidden: Value(true)));

    final applicationFound = _applications[application.packageName];
    if (applicationFound != null) {
      applicationFound.hidden = true;

      for (int categoryId in applicationFound.categoryOrders.keys) {
        final category = _categoriesById[categoryId];
        if (category != null) {
          category.applications.removeWhere((application0) =>
              application0.packageName == application.packageName);
        }
      }

      notifyListeners();
    }
  }

  Future<void> showApplication(App application) async {
    await _database.updateApp(
        application.packageName, const AppsCompanion(hidden: Value(false)));

    final applicationFound = _applications[application.packageName];
    if (applicationFound != null) {
      applicationFound.hidden = false;

      for (int categoryId in application.categoryOrders.keys) {
        final category = _categoriesById[categoryId];
        if (category != null) {
          category.applications.add(application);
          sortCategory(category);
        }
      }

      notifyListeners();
    }
  }

  Future<void> setCategoryType(Category category, CategoryType type,
      {bool shouldNotifyListeners = true}) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(type: Value(type)));

    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      categoryFound.type = type;

      if (shouldNotifyListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> setCategorySort(Category category, CategorySort sort) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(sort: Value(sort)));
    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      categoryFound.sort = sort;
      sortCategory(categoryFound);

      notifyListeners();
    }
  }

  Future<void> setCategoryColumnsCount(
      Category category, int columnsCount) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(columnsCount: Value(columnsCount)));

    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      categoryFound.columnsCount = columnsCount;

      notifyListeners();
    }
  }

  Future<void> setCategoryRowHeight(Category category, int rowHeight) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(rowHeight: Value(rowHeight)));

    final categoryFound = _categoriesById[category.id];
    if (categoryFound != null) {
      categoryFound.rowHeight = rowHeight;
      notifyListeners();
    }
  }
}
