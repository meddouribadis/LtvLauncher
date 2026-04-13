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
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_clean_row.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/wallpaper_video_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'models/app.dart';
import 'models/category.dart';

const _kDockOuterPadding = EdgeInsets.only(left: 12, right: 12, bottom: 6);

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
                  builder: (_, wallpaperService, __) =>
                      _wallpaper(context, wallpaperService),
                ),
              ),
              Consumer<LauncherState>(
                builder: (_, state, child) => Visibility(
                  replacement: const Center(child: AlternativeLauncherView()),
                  visible: state.launcherVisible,
                  child: child!,
                ),
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: FocusAwareAppBar(key: _appBarKey),
                  body: Selector<AppsService, (bool, int)>(
                    selector: (_, service) =>
                        (service.initialized, service.layoutVersion),
                    builder: (context, data, _) {
                      if (data.$1) {
                        return _tvOSLayout(
                            context, context.read<AppsService>());
                      } else {
                        return _emptyState(context);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tvOSLayout(BuildContext context, AppsService appsService) {
    final favoritesCategory =
        appsService.categories.firstWhereOrNull((c) => c.name == 'Favorites');
    final favoriteApps = favoritesCategory?.applications ?? const [];

    final otherSections = appsService.launcherSections.where((section) {
      if (section is Category && section.name == 'Favorites') return false;
      return true;
    }).toList();

    if (favoriteApps.isEmpty && otherSections.isEmpty)
      return _emptyState(context);

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
              padding: _kDockOuterPadding,
              child: _dock(
                context,
                favoritesCategory!,
                favoriteApps,
                appsService,
              ),
            ),
          ),
        ],
        ..._buildSectionSlivers(otherSections,
            firstCategoryAlreadyFound: favoriteApps.isNotEmpty),
        const SliverToBoxAdapter(child: SizedBox(height: 64)),
      ],
    );
  }

  List<Widget> _buildSectionSlivers(List<LauncherSection> sections,
      {bool firstCategoryAlreadyFound = false}) {
    final List<Widget> slivers = [];
    bool firstCategoryFound = firstCategoryAlreadyFound;

    for (final section in sections) {
      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        slivers.add(SliverToBoxAdapter(
          key: sectionKey,
          child: SizedBox(height: section.height.toDouble()),
        ));
        continue;
      }

      final category = section as Category;
      final filteredApps = category.applications;
      if (filteredApps.isEmpty) continue;

      final bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;

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
                    shadows: const [
                      Shadow(
                          color: Colors.black54,
                          offset: Offset(1, 1),
                          blurRadius: 8),
                    ],
                  ),
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
                applications: filteredApps,
                isFirstSection: isFirstSection,
                showTitle: false,
              ),
            ),
          ));
          break;
        case CategoryType.grid:
          slivers.add(SliverPadding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
            sliver: SliverGrid(
              key: sectionKey,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: category.columnsCount,
                childAspectRatio: 16 / 9,
                mainAxisSpacing: 12,
                crossAxisSpacing: 0,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: filteredApps.length,
                findChildIndexCallback: (Key key) {
                  final valueKey = key as ValueKey<String>;
                  final index = filteredApps.indexWhere(
                    (app) => app.packageName == valueKey.value,
                  );
                  return index >= 0 ? index : null;
                },
                (context, index) => Padding(
                  key: Key(filteredApps[index].packageName),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: AppCard(
                    category: category,
                    application: filteredApps[index],
                    autofocus: index == 0,
                    handleUpNavigationToSettings:
                        isFirstSection && index < category.columnsCount,
                    onMove: (direction) => _onGridMove(
                        context, category, index, direction, filteredApps),
                    onMoveEnd: () => context
                        .read<AppsService>()
                        .saveApplicationOrderInCategory(category),
                  ),
                ),
              ),
            ),
          ));
          break;
      }
    }

    return slivers;
  }

  // TO DO : refractor duplicate _onMove code
  void _onGridMove(BuildContext context, Category category, int index,
      AxisDirection direction, List<App> filteredApps) {
    final currentRow = (index / category.columnsCount).floor();
    final totalRows =
        ((filteredApps.length - 1) / category.columnsCount).floor();

    int? newIndex;
    switch (direction) {
      case AxisDirection.up:
        if (currentRow > 0) newIndex = index - category.columnsCount;
        break;
      case AxisDirection.right:
        if (index < filteredApps.length - 1) newIndex = index + 1;
        break;
      case AxisDirection.down:
        if (currentRow < totalRows)
          newIndex =
              min(index + category.columnsCount, filteredApps.length - 1);
        break;
      case AxisDirection.left:
        if (index > 0) newIndex = index - 1;
        break;
    }

    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      final movingApp = filteredApps[index];
      final realOldIndex = category.applications.indexOf(movingApp);
      final realNewIndex =
          category.applications.indexOf(filteredApps[newIndex]);
      if (realOldIndex >= 0 && realNewIndex >= 0) {
        appsService.reorderApplication(category, realOldIndex, realNewIndex);
        appsService.setPendingReorderFocus(movingApp.packageName, category.id);
      }
    }
  }

  Widget _dock(
    BuildContext context,
    Category category,
    List<App> apps,
    AppsService appsService,
  ) {
    final backdropDisabled = context.select<SettingsService, bool>(
      (s) => s.dockBackdropFilterDisabled,
    );

    final content = Container(
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
        category: category,
        applications: apps,
        isFirstSection: false,
        scrollAlignment: 1.0,
      ),
    );

    return Center(
      //child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: backdropDisabled
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: content,
              ),
        //),
      ),
    );
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    final physicalSize = MediaQuery.sizeOf(context);
    final videoFile = wallpaperService.wallpaperVideoFile;
    if (videoFile != null) {
      return SizedBox(
        width: physicalSize.width,
        height: physicalSize.height,
        child: WallpaperVideoBackground(
            key: Key("background_video"), file: videoFile),
      );
    }
    if (wallpaperService.wallpaper != null) {
      return Image(
        image: wallpaperService.wallpaper!,
        key: const Key("background"),
        fit: BoxFit.cover,
        height: physicalSize.height,
        width: physicalSize.width,
      );
    } else {
      return Container(
        key: const Key("background"),
        decoration: BoxDecoration(gradient: wallpaperService.gradient.gradient),
      );
    }
  }

  Widget _emptyState(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
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
