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


import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'models/app.dart';
import 'models/category.dart';

class FLauncher extends StatefulWidget {
  const FLauncher({super.key});

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> {
  final GlobalKey<FocusAwareAppBarState> _appBarKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
        onInvoke: (_) => _appBarKey.currentState?.focusSettings(),
      ),
    },
    child: FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(
        children: [
          RepaintBoundary(
            child: Consumer<WallpaperService>(
              builder: (_, wallpaperService, __) => _wallpaper(context, wallpaperService)
            ),
          ),
          Consumer<LauncherState>(
            builder: (_, state, child) => Visibility(
              child: child!,
              replacement: const Center(
                child: AlternativeLauncherView()
              ),
              visible: state.launcherVisible
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: FocusAwareAppBar(key: _appBarKey),
              body: Consumer<AppsService>(
                builder: (context, appsService, _) {
                  if (appsService.initialized) {
                    return _tvOSLayout(appsService);
                  }
                  else {
                    return _emptyState(context);
                  }
                }
              )
            )
          )
        ]
      )
    ),
  );

  Widget _tvOSLayout(AppsService appsService) {
    final favoritesCategory = appsService.categories.firstWhereOrNull((c) => c.name == 'Favorites');
    final favoriteApps = favoritesCategory?.applications ?? [];

    final otherSections = appsService.launcherSections.where((section) {
      if (section is Category && section.name == 'Favorites') return false;
      return true;
    }).toList();

    if (favoriteApps.isEmpty && otherSections.isEmpty) return _emptyState(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          if (favoriteApps.isNotEmpty) ...[
            // Pushes the dock to the bottom of the screen initially
            SizedBox(height: MediaQuery.of(context).size.height - 150),
            _dock(favoritesCategory!, favoriteApps, appsService)
          ],
          // Other apps sections
          _sections(otherSections, firstCategoryAlreadyFound: favoriteApps.isNotEmpty),
          
          const SizedBox(height: 64), // Bottom padding
        ],
      ),
    );
  }

  Widget _dock(Category favoritesCategory, List<App> favoriteApps, AppsService appsService) {

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: favoriteApps.asMap().entries.map((entry) {
                int index = entry.key;
                App app = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 200,
                    child: AppCard(
                      application: app,
                      category: favoritesCategory!,
                      autofocus: index == 0,
                      handleUpNavigationToSettings: true,
                      scrollAlignment: 0.9, // Force the scroll to return to the initial position (bottom)
                      onMove: (direction) {
                        int newIndex = -1;
                        if (direction == AxisDirection.right && index < favoriteApps.length - 1) {
                          newIndex = index + 1;
                        } else if (direction == AxisDirection.left && index > 0) {
                          newIndex = index - 1;
                        }
                        if (newIndex != -1) {
                          appsService.reorderApplication(favoritesCategory!, index, newIndex);
                          appsService.setPendingReorderFocus(app.packageName, favoritesCategory!.id);
                        }
                      },
                      onMoveEnd: () => appsService.saveApplicationOrderInCategory(favoritesCategory!),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sections(List<LauncherSection> sections, {bool firstCategoryAlreadyFound = false}) {
    List<Widget> children = [];
    bool firstCategoryFound = firstCategoryAlreadyFound;

    for (var section in sections) {
      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        children.add(SizedBox(key: sectionKey, height: section.height.toDouble()));
        continue;
      }

      Category category = section as Category;
      if (category.applications.isEmpty) continue;

      Widget categoryWidget;

      // Pass isFirstSection only to the first category found
      bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;

      switch (category.type) {
        case CategoryType.row:
          categoryWidget = CategoryRow(
              key: sectionKey,
              category: category,
              applications: category.applications,
              isFirstSection: isFirstSection
          );
          break;
        case CategoryType.grid:
          categoryWidget = AppsGrid(
              key: sectionKey,
              category: category,
              applications: category.applications,
              isFirstSection: isFirstSection
          );
          break;
      }

      children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: categoryWidget
      ));
    }

    return Column(children: children);
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    if (wallpaperService.wallpaper != null) {
      final physicalSize = MediaQuery.sizeOf(context);
      return Image(
        image: wallpaperService.wallpaper!,
        key: const Key("background"),
        fit: BoxFit.cover,
        height: physicalSize.height,
        width: physicalSize.width
      );
    }
    else {
      return Container(key: const Key("background"), decoration: BoxDecoration(gradient: wallpaperService.gradient.gradient));
    }
  }

  Widget _emptyState(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
