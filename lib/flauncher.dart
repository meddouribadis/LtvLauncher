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
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid_sliver.dart';
import 'package:flauncher/widgets/category_clean_row.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/foundation.dart' hide Category;
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
            child: Stack(children: [
              RepaintBoundary(
                child: Consumer<WallpaperService>(
                    builder: (_, wallpaperService, __) =>
                        _wallpaper(context, wallpaperService)),
              ),
              Consumer<LauncherState>(
                  builder: (_, state, child) => Visibility(
                      child: child!,
                      replacement:
                          const Center(child: AlternativeLauncherView()),
                      visible: state.launcherVisible),
                  child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: FocusAwareAppBar(key: _appBarKey),
                      body: Consumer<AppsService>(
                          builder: (context, appsService, _) {
                        if (appsService.initialized) {
                          return _tvOSLayout();
                        } else {
                          return _emptyState(context);
                        }
                      })))
            ])),
      );

  Widget _tvOSLayout() {
    return Selector<AppsService, _TVOSLayoutData>(
      selector: (_, svc) => _TVOSLayoutData(
        favoritesCategory:
            svc.categories.firstWhereOrNull((c) => c.name == 'Favorites'),
        otherSections: svc.launcherSections.where((section) {
          if (section is Category && section.name == 'Favorites') return false;
          return true;
        }).toList(),
      ),
      shouldRebuild: (prev, next) =>
          prev.favoritesCategory != next.favoritesCategory ||
          prev.otherSections != next.otherSections,
      builder: (context, data, _) {
        final favoriteApps = data.favoritesCategory?.applications ?? [];

        if (favoriteApps.isEmpty && data.otherSections.isEmpty) {
          return _emptyState(context);
        }

        return CustomScrollView(
          slivers: [
            if (favoriteApps.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      kToolbarHeight -
                      150,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 12, right: 12, bottom: 6),
                  child: _dock(data.favoritesCategory!, favoriteApps),
                ),
              ),
            ],
            ..._buildSectionSlivers(
              data.otherSections,
              firstCategoryAlreadyFound: favoriteApps.isNotEmpty,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 64)),
          ],
        );
      },
    );
  }

  Widget _dock(Category favoritesCategory, List<App> favoriteApps) {
    return RepaintBoundary(
        child: Center(
          child: ClipRect(
            // borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  //boxShadow: [
                  //  BoxShadow(
                  //    color: Colors.black.withOpacity(0.3),
                  //    blurRadius: 20,
                  //    offset: const Offset(0, 10),
                  //  )
                  //],
                ),
                child: CategoryCleanRow(
                  category: favoritesCategory,
                  applications: favoriteApps,
                  isFirstSection: false,
                  scrollAlignment: 1.0,
                ),
              ),
            ),
          ),
        ),
      );
  }

  List<Widget> _buildSectionSlivers(List<LauncherSection> sections,
      {bool firstCategoryAlreadyFound = false}) {
    List<Widget> slivers = [];
    bool firstCategoryFound = firstCategoryAlreadyFound;

    for (var section in sections) {
      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        slivers.add(SliverToBoxAdapter(
          key: sectionKey,
          child: SizedBox(height: section.height.toDouble()),
        ));
        continue;
      }

      Category category = section as Category;
      if (category.applications.isEmpty) continue;

      bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;

      // Category title
      slivers.add(SliverToBoxAdapter(
        child: Selector<SettingsService, bool>(
          selector: (context, service) => service.showCategoryTitles,
          builder: (context, showTitle, _) {
            if (showTitle) {
              return Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8, top: 8),
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      shadows: [
                        const Shadow(
                            color: Colors.black54,
                            offset: Offset(1, 1),
                            blurRadius: 8)
                      ]),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ));

      switch (category.type) {
        case CategoryType.row:
          slivers.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
              child: CategoryRow(
                key: sectionKey,
                category: category,
                applications: category.applications,
                isFirstSection: isFirstSection,
                showTitle: false,
              ),
            ),
          ));
          break;
        case CategoryType.grid:
          slivers.add(SliverPadding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
            sliver: AppsGridSliver(
              key: sectionKey,
              category: category,
              isFirstSection: isFirstSection,
            ),
          ));
          break;
      }
    }

    return slivers;
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    if (wallpaperService.wallpaper != null) {
      final physicalSize = MediaQuery.sizeOf(context);
      return Image(
          image: wallpaperService.wallpaper!,
          key: const Key("background"),
          fit: BoxFit.cover,
          height: physicalSize.height,
          width: physicalSize.width);
    } else {
      return Container(
          key: const Key("background"),
          decoration:
              BoxDecoration(gradient: wallpaperService.gradient.gradient));
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
          Text(localizations.loading,
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _TVOSLayoutData {
  final Category? favoritesCategory;
  final List<LauncherSection> otherSections;

  const _TVOSLayoutData({
    required this.favoritesCategory,
    required this.otherSections,
  });

  @override
  bool operator ==(Object other) =>
      other is _TVOSLayoutData &&
      other.favoritesCategory == favoritesCategory &&
      listEquals(other.otherSections, otherSections);

  @override
  int get hashCode => Object.hash(favoritesCategory, otherSections);
}
