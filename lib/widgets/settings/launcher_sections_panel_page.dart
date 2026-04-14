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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../../models/category.dart';

class LauncherSectionsPanelPage extends StatefulWidget {
  static const String routeName = "launcher_sections_panel";

  @override
  State<LauncherSectionsPanelPage> createState() => _LauncherSectionsPanelPageState();
}

class _LauncherSectionsPanelPageState extends State<LauncherSectionsPanelPage> {
  int? _movingIndex;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(localizations.launcherSections, style: Theme.of(context).textTheme.titleLarge),
        Divider(),
        Consumer<AppsService>(
          builder: (_, service, __) {
            List<LauncherSection> sections = service.launcherSections;

            return Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: EdgeInsets.only(bottom: 80),
                itemCount: sections.length,
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  context.read<AppsService>().moveSection(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _section(context, section, index, sections.length);
                },
              ),
            );
          },
        ),
        SizedBox(height: 4, width: 0),
        FocusableSettingsTile(
          leading: Icon(Icons.add),
          title: Text(localizations.addSection, style: Theme.of(context).textTheme.bodyMedium),
          onPressed: () {
            Navigator.pushNamed(context, LauncherSectionPanelPage.routeName);
          },
        ),
      ],
    );
  }

  Widget _section(BuildContext context, LauncherSection section, int index, int totalCount) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title = localizations.spacer;
    if (section is Category) {
      title = section.name;

      if (title == localizations.spacer) {
        title = localizations.disambiguateCategoryTitle(title);
      }
    }

    final bool isMoving = _movingIndex == index;

    return Padding(
      // Use ObjectKey to ensure uniqueness even if IDs collide across different types
      key: ObjectKey(section),
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          if (isMoving) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (index > 0) {
                _move(index, index - 1);
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (index < totalCount - 1) {
                _move(index, index + 1);
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA ||
                event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _endMove();
              return KeyEventResult.handled;
            }
          } else {
            // Not Moving
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              setState(() {
                _movingIndex = index;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              Navigator.pushNamed(context, LauncherSectionPanelPage.routeName, arguments: index);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(builder: (context) {
            final bool focused = Focus.of(context).hasFocus;
            
            // Determine colors based on state
            final Color backgroundColor = isMoving 
                ? colorScheme.primaryContainer 
                : (focused ? Colors.white10 : Colors.transparent);
            
            final Color textColor = isMoving 
                ? colorScheme.onPrimaryContainer 
                : (focused ? Colors.white : Colors.white70);
            
            final Color iconColor = isMoving 
                ? colorScheme.onPrimaryContainer 
                : (focused ? colorScheme.primary : Colors.white38);

            return GestureDetector(
              onTap: () {
                   if (isMoving) {
                      _endMove();
                   } else {
                      Navigator.pushNamed(context, LauncherSectionPanelPage.routeName, arguments: index);
                   }
              },
              onLongPress: () {
                   if (!isMoving) {
                      setState(() {
                        _movingIndex = index;
                      });
                   }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: focused ? colorScheme.primary : (isMoving ? colorScheme.primary : Colors.transparent),
                    width: focused ? 2 : (isMoving ? 1 : 0),
                  ),
                  boxShadow: focused 
                      ? [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))] 
                      : null,
                ),
                child: Row(
                  children: [
                    // Drag Handle Icon
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        isMoving ? Icons.drag_indicator : Icons.drag_handle,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Section Title
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: focused || isMoving ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    
                    // Move Indicators
                    if (isMoving) ...[
                       Icon(Icons.keyboard_arrow_up, color: textColor),
                       const SizedBox(width: 4),
                       Icon(Icons.keyboard_arrow_down, color: textColor),
                    ] else ...[
                       Icon(Icons.chevron_right, color: Colors.white24),
                    ],
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }


  void _move(int oldIndex, int newIndex) {
    context.read<AppsService>().moveSectionInMemory(oldIndex, newIndex);
    setState(() {
      _movingIndex = newIndex;
    });
  }

  void _endMove() {
    context.read<AppsService>().persistSectionsOrder();
    setState(() {
      _movingIndex = null;
    });
  }
}
