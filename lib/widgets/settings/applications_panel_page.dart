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

import 'dart:typed_data';

import 'package:flauncher/providers/apps_service.dart';

import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/widgets/settings/app_details_page.dart';
import 'package:flutter/services.dart';

import '../../models/app.dart';
import '../../models/category.dart';

class ApplicationsPanelPage extends StatefulWidget {
  static const String routeName = "applications_panel";

  const ApplicationsPanelPage({super.key});

  @override
  State<ApplicationsPanelPage> createState() => _ApplicationsPanelPageState();
}

class _ApplicationsPanelPageState extends State<ApplicationsPanelPage> {
  int _selectedIndex = 0;
  String _title = "";
  bool _isSwitchingViaKeyboard = false;

  final List<_TabData> _tabs = [
    _TabData(0, Icons.apps, (l) => l.allApplications),
    _TabData(1, Icons.star, (l) => l.favoriteApps),
    _TabData(2, Icons.visibility_off_outlined, (l) => l.hiddenApplications),
  ];
  
  late List<FocusNode> _tabFocusNodes;

  @override
  void initState() {
    super.initState();
    _tabFocusNodes = List.generate(_tabs.length, (index) => FocusNode());
  }

  @override
  void dispose() {
    for (var node in _tabFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    if (_title.isEmpty) {
      _title = _tabs[0].getTitle(localizations);
    }

    return Column(
      children: [
        Text(_title, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _tabs.map((tab) => _buildTabButton(tab.index, tab.icon, tab.getTitle(localizations))).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.arrowLeft): const ChangeTabIntent(-1),
              LogicalKeySet(LogicalKeyboardKey.arrowRight): const ChangeTabIntent(1),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ChangeTabIntent: ChangeTabAction(this),
                MoveFocusToTabIntent: MoveFocusToTabAction(this),
              },
              child: _buildCurrentTab(),
            ),
          ),
        ),
      ],
    );
  }

  void _selectTab(int index, String title) {

    if (_selectedIndex != index) {
      if (mounted) {
        setState(() {
          _selectedIndex = index;
          _title = title;
        });
      }
    }
  }


  void changeTab(int direction) {
    // ... (existing code, ensure it matches previous edits)

    final newIndex = (_selectedIndex + direction).clamp(0, _tabs.length - 1);
    if (newIndex != _selectedIndex) {
      final localizations = AppLocalizations.of(context)!;

      
      _isSwitchingViaKeyboard = true;
      _selectTab(newIndex, _tabs[newIndex].getTitle(localizations));
      

      _tabFocusNodes[newIndex].requestFocus();
      
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
           _isSwitchingViaKeyboard = false;
        }
      });
    }
  }

  void focusCurrentTab() {

    _tabFocusNodes[_selectedIndex].requestFocus();
  }

  Widget _buildTabButton(int index, IconData icon, String title) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Focus(
          focusNode: _tabFocusNodes[index],
          onFocusChange: (focused) {
            if (focused) {
              if (_isSwitchingViaKeyboard) {

                return;
              }

              _selectTab(index, title);
            }
          },
          child: Builder(builder: (context) {
            final focused = Focus.of(context).hasFocus;
            final selected = _selectedIndex == index;
            return navButton(selected, focused, index, title, icon);
          }),
        ),
      ),
    );
  }

  Widget navButton(bool selected, bool focused, int index, String title, IconData icon) {
    // ... (same)
    return InkWell(
      onTap: () {
        _selectTab(index, title);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.15)
              : (focused ? Colors.white.withOpacity(0.1) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: focused ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Icon(
          icon,
          color: (selected || focused) ? Colors.white : Colors.white60,
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
     // ... (same)
    switch (_selectedIndex) {
      case 0: return _AllAppsTab();
      case 1: return _FavoritesTab();
      case 2: return _HiddenTab();
      default: return Container();
    }
  }
}

class _TabData {
  final int index;
  final IconData icon;
  final String Function(AppLocalizations) getTitle;

  _TabData(this.index, this.icon, this.getTitle);
}


class MoveFocusToTabIntent extends Intent {
  const MoveFocusToTabIntent();
}

class MoveFocusToTabAction extends Action<MoveFocusToTabIntent> {
  final _ApplicationsPanelPageState state;
  MoveFocusToTabAction(this.state);
  @override
  Object? invoke(MoveFocusToTabIntent intent) {
    state.focusCurrentTab();
    return null;
  }
}

class ChangeTabIntent extends Intent {
  final int direction;
  const ChangeTabIntent(this.direction);
}

class ChangeTabAction extends Action<ChangeTabIntent> {
  final _ApplicationsPanelPageState state;

  ChangeTabAction(this.state);

  @override
  Object? invoke(ChangeTabIntent intent) {
    state.changeTab(intent.direction);
    return null;
  }
}


class _AllAppsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) => appsService.applications.where((app) => !app.hidden).toList(),
        builder: (context, applications, _) {
          if (applications.isEmpty) {
            return const _EmptyListPlaceholder("No applications found", autofocus: true);
          }
          return ListView(
            children: applications
                .asMap()
                .entries
                .map((entry) => EnsureVisible(
                      alignment: 0.5,
                      child: _AppListItem(entry.value, autofocus: entry.key == 0, isFirst: entry.key == 0),
                    ))
                .toList(),
          );
        },
      );
}

class _FavoritesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) {
           final favorites = appsService.categories.firstWhere(
            (category) => category.name == 'Favorites',
            orElse: () => Category(name: 'Favorites'),
          );
          return favorites.applications.where((app) => !app.hidden).toList();
        },
        builder: (context, applications, _) {
          if (applications.isEmpty) {
            return const _EmptyListPlaceholder("No applications found", autofocus: true);
          }
          return ListView(
            children: applications
                .asMap()
                .entries
                .map((entry) => EnsureVisible(
                      alignment: 0.5,
                      child: _AppListItem(entry.value, autofocus: entry.key == 0, isFirst: entry.key == 0),
                    ))
                .toList(),
          );
        },
      );
}

class _HiddenTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) => appsService.applications.where((app) => app.hidden).toList(),
        builder: (context, applications, _) {
          if (applications.isEmpty) {
            return const _EmptyListPlaceholder("No applications found", autofocus: true);
          }
          return ListView(
            children: applications
                .asMap()
                .entries
                .map((entry) => EnsureVisible(
                      alignment: 0.5,
                      child: _AppListItem(entry.value, autofocus: entry.key == 0, isFirst: entry.key == 0),
                    ))
                .toList(),
          );
        },
      );
}

class _EmptyListPlaceholder extends StatefulWidget {
  final String message;
  final bool autofocus;

  const _EmptyListPlaceholder(this.message, {this.autofocus = false});

  @override
  State<_EmptyListPlaceholder> createState() => _EmptyListPlaceholderState();
}

class _EmptyListPlaceholderState extends State<_EmptyListPlaceholder> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {

        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const MoveFocusToTabIntent(),
      },
      child: Focus(
        focusNode: _focusNode,
        child: Center(
          child: Text(
            widget.message,
            style: const TextStyle(color: Colors.white60), // Basic styling
          ),
        ),
      ),
    );
  }
}

class _AppListItem extends StatefulWidget
{
  final App application;
  final bool autofocus;
  final bool isFirst;

  const _AppListItem(this.application, {this.autofocus = false, this.isFirst = false});

  @override
  State<StatefulWidget> createState() => _AppListItemState();
}

class _AppListItemState extends State<_AppListItem>
{
  late Future<ImageProvider> _iconLoadFuture;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _iconLoadFuture = _loadAppIcon(Provider.of<AppsService>(context, listen: false));

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {

        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _openAppDetails() {
    Navigator.of(context).pushNamed(AppDetailsPage.routeName, arguments: widget.application);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _openAppDetails()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _openAppDetails()),
        },
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (widget.isFirst && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {

              Actions.invoke(context, const MoveFocusToTabIntent());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onFocusChange: (hasFocus) {

             setState(() {});
          },
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              final primaryColor = Theme.of(context).colorScheme.primary;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                decoration: BoxDecoration(
                  color: focused ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.05), // Keep background consistent or same logic
                  borderRadius: BorderRadius.circular(12),
                  border: focused
                      ? Border.all(color: primaryColor, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                  boxShadow: focused
                      ? const [BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
                child: Material( // Needed for InkWell to show ripple on top of container color if needed, or inside.
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                  onTap: _openAppDetails,
                  child: FutureBuilder(
                    future: _iconLoadFuture,
                    builder: (context, snapshot) {
                      Widget appIcon;
                      
                      if (snapshot.hasData) {
                        appIcon = Image(image: snapshot.data!, height: 40);
                      }
                      else if (snapshot.hasError) {
                        appIcon = const Icon(Icons.warning);
                      }
                      else {
                        appIcon = const SizedBox(
                          height: 40,
                          width: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        );
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          widget.application.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: focused ? FontWeight.bold : FontWeight.normal
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: appIcon,
                        trailing: Icon(
                          Icons.chevron_right, 
                          size: 20, 
                          color: focused ? primaryColor : Colors.white30
                        ),
                      );
                    },
                  ),
                )
              ));
            }
          ),
        ),
      ),
    );
  }

  Future<ImageProvider> _loadAppIcon(AppsService service) async {
    Uint8List bytes = await service.getAppIcon(widget.application.packageName);
    return MemoryImage(bytes);
  }
}
