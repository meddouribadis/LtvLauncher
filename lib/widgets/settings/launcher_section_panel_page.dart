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

import 'dart:async';

import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../models/category.dart';

// Section name presets for TV remote-friendly selection
const List<String> sectionNamePresets = [
  'All Apps',            // Auto: all non-hidden apps
  'Movies & Shows',
  'Music',
  'Games',
  'Entertainment',
  'Live TV',
  'Sports',
  'News',
  'Tools',
  'Favorites',
  'Custom...',
];

class _SettingsState extends ChangeNotifier
{
  bool _changed;
  bool _creating;
  bool _deleted;
  bool _valid;
  LauncherSection? _section;
  LauncherSectionType _sectionType;

  void Function()? onSave;

  bool get changed => _changed;
  bool get creating => _creating;
  bool get deleted => _deleted;
  bool get valid => _valid;
  LauncherSection? get launcherSection => _section;
  LauncherSectionType get sectionType => _sectionType;

  _SettingsState(AppsService appsService, int? sectionIndex):
      _changed = false,
      _creating = false,
      _deleted = false,
      _valid = false,
      _sectionType = LauncherSectionType.Category
  {
    LauncherSection? launcherSection;
    List<LauncherSection> sections = appsService.launcherSections;
    if (sectionIndex != null && sectionIndex < sections.length) {
      launcherSection = sections[sectionIndex];
    }

    setLauncherSection(launcherSection, shouldNotifyListeners: false);
  }

  void setDeleted() {
    _deleted = true;
  }

  void setFlags(bool valid, bool changed)
  {
    if (_valid != valid || _changed != changed) {
      _valid = valid;
      _changed = changed;

      notifyListeners();
    }
  }

  void setLauncherSection(LauncherSection? section, {bool shouldNotifyListeners = true})
  {
    _section = section;

    _changed = false;
    _creating = false;
    _valid = false;
    _sectionType = LauncherSectionType.Category;

    if (section == null) {
      _creating = true;
    }
    else if (section is LauncherSpacer) {
      _sectionType = LauncherSectionType.Spacer;
    }

    _valid = false;
    _changed = creating;

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  void setSectionType(LauncherSectionType sectionType)
  {
    assert(_creating);

    _changed = false;
    _valid = false;

    if (_sectionType != sectionType) {
      _sectionType = sectionType;

      if (sectionType == LauncherSectionType.Spacer) {
        _changed = true;
        _valid = true;
      }

      notifyListeners();
    }
  }
}

class LauncherSectionPanelPage extends StatelessWidget
{
  static const String routeName = "section_panel";

  final int? sectionIndex;

  LauncherSectionPanelPage({Key? key, this.sectionIndex}): super(key: key);

  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return ChangeNotifierProvider(
      create: (_) {
        AppsService service = context.read();
        return _SettingsState(service, sectionIndex);
      },
      builder: (context, _) => Selector<_SettingsState, LauncherSectionType>(
        selector: (_, state) => state.sectionType,
        builder: (_, sectionType, __)  {
          _SettingsState state = context.read();
          LauncherSection? launcherSection = state.launcherSection;

          if (state.deleted) {
            return Container();
          }

          bool creating = state.creating;
          Widget sectionSpecificSettings;

          if (sectionType == LauncherSectionType.Category) {
            sectionSpecificSettings = _CategorySettings(
              category: launcherSection as Category?,
            );
          }
          else {
            sectionSpecificSettings = _LauncherSpacerSettings(
                spacer: launcherSection as LauncherSpacer?
            );
          }

          String title = localizations.newSection;
          if (!creating) {
            title = localizations.modifySection;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                Divider(),
                sectionSpecificSettings,
                Divider(),
              Selector<_SettingsState, bool>(
                selector: (context, state) => (state.valid && state.changed),
                builder: (context, canSave, _) {
                  void Function()? onSavePressed;
                  if (canSave) {
                    onSavePressed = () {
                      if (state.onSave != null) {
                        state.onSave!();
                      }
                    };
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.white10;
                          }
                          return Color(0xFF6366F1); // Indigo (Modern Primary)
                        }),
                        foregroundColor: MaterialStateProperty.resolveWith((states) {
                           if (states.contains(MaterialState.disabled)) {
                             return Colors.white38;
                           }
                           return Colors.white;
                        }),
                        shape: MaterialStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        side: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.focused)) {
                            return BorderSide(color: Colors.white, width: 2);
                          }
                          return null;
                        }),
                        elevation: MaterialStatePropertyAll(0),
                        padding: MaterialStatePropertyAll(EdgeInsets.symmetric(vertical: 12))
                      ),
                      onPressed: onSavePressed,
                      child: Text(localizations.save),
                    )
                  );
                }
              ),

              if (!creating)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStatePropertyAll(Color(0xFF27272A)), // Zinc 800
                      foregroundColor: MaterialStatePropertyAll(Color(0xFFEF4444)), // Red 500
                      shape: MaterialStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      side: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.focused)) {
                          return BorderSide(color: Colors.white, width: 2);
                        }
                        return null;
                      }),
                      elevation: MaterialStatePropertyAll(0),
                      padding: MaterialStatePropertyAll(EdgeInsets.symmetric(vertical: 12))
                    ),
                    onPressed: () async {
                      state.setDeleted();
                      await context.read<AppsService>().deleteSection(sectionIndex!);
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.delete),
                  )
                )
              ]
            ),
          );
        }
      )
    );
  }
}

class _CategorySettings extends StatefulWidget
{
  final Category? category;

  const _CategorySettings({
    this.category
  });

  @override
  State<StatefulWidget> createState() => _CategorySettingsState();
}

class _CategorySettingsState extends State<_CategorySettings>
{
  final FocusNode _textFieldFocusNode;
  
  late final TextEditingController _nameController;
  
  bool _ignoreTextFieldKeyEvent;
  CategorySort _categorySort;
  CategoryType _categoryType;
  int _columnsCount;
  int _rowHeight;
  String _name;

  late Category? _category;

  late bool _creating;

  _CategorySettingsState():
        _ignoreTextFieldKeyEvent = false,
        _categorySort = Category.Sort,
        _categoryType = Category.Type,
        _columnsCount = Category.ColumnsCount,
        _rowHeight = Category.RowHeight,
        _name = "",
        _textFieldFocusNode = FocusNode();

  @override
  void dispose() {
    super.dispose();

    _nameController.dispose();
    _textFieldFocusNode.dispose();
  }

  @override
  void initState() {
    super.initState();

    _category = widget.category;
    _creating = _category == null;

    if (!_creating) {
      _name = _category!.name;
      _categorySort = _category!.sort;
      _categoryType = _category!.type;
      _columnsCount = _category!.columnsCount;
      _rowHeight = _category!.rowHeight;
    } else {
      // Default to "Favorites" when creating a new section
      _name = 'Favorites';
    }

    _nameController = TextEditingController(text: _name);

    _SettingsState state = context.read();
    state.onSave = _save;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final FocusScopeNode focusScopeNode = FocusScope.of(context);
    focusScopeNode.onKeyEvent = (node, keyEvent) {
      if (_textFieldFocusNode.hasFocus && (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp || keyEvent.logicalKey == LogicalKeyboardKey.arrowDown)) {
        if (!_ignoreTextFieldKeyEvent) {
          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
            _textFieldFocusNode.previousFocus();
          }
          if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
            _textFieldFocusNode.nextFocus();
          }
        }

        _ignoreTextFieldKeyEvent = false;
      }
      else {
        _ignoreTextFieldKeyEvent = true;
      }

      return KeyEventResult.ignored;
    };
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        _listTile(
          context,
          Text(localizations.name),
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              autofocus: _creating,
              isDense: true,
              isExpanded: true,
              value: sectionNamePresets.contains(_name) ? _name : 'Custom...',
              hint: Text(_name.isEmpty ? 'Select a name' : _name, style: Theme.of(context).textTheme.bodySmall),
              onChanged: (value) {
                setState(() {
                  if (value == 'Custom...') {
                    _name = '';
                    _nameController.text = '';
                  } else if (value != null) {
                    _name = value;
                    _nameController.text = value;
                  }
                });
                _notifyChange();
              },
              items: sectionNamePresets.map((name) => DropdownMenuItem(
                value: name,
                child: Text(name, style: Theme.of(context).textTheme.bodySmall),
              )).toList(),
            )
          )
        ),
        if (!sectionNamePresets.contains(_name) || _name.isEmpty)
          _listTile(
            context,
            Text('Custom Name'),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: TextFormField(
                controller: _nameController,
                focusNode: _textFieldFocusNode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  _name = value;
                  _notifyChange();
                },
              )
            )
          ),
        _listTile(
          context,
          Text(localizations.sort),
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: DropdownButtonFormField<CategorySort>(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isDense: true,
              isExpanded: true,
              value: _categorySort,
              onChanged: (value) {
                setState(() {
                  _categorySort = value!;
                });
                _notifyChange();
              },
              items: [
                DropdownMenuItem(
                  value: CategorySort.alphabetical,
                  child: Text(localizations.alphabetical, style: Theme.of(context).textTheme.bodySmall),
                ),
                DropdownMenuItem(
                  value: CategorySort.manual,
                  child: Text(localizations.manual, style: Theme.of(context).textTheme.bodySmall),
                ),
                DropdownMenuItem(
                  value: CategorySort.lastUsed,
                  child: Text('Last Used', style: Theme.of(context).textTheme.bodySmall),
                )
              ]
            )
          )
        ),
        _listTile(
          context,
          Text(localizations.layout),
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: DropdownButtonFormField<CategoryType>(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: _categoryType,
              onChanged: (value) {
                setState(() {
                  _categoryType = value!;
                });
                _notifyChange();
              },
              isDense: true,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: CategoryType.row,
                  child: Text(localizations.row, style: Theme.of(context).textTheme.bodySmall)
                ),
                DropdownMenuItem(
                  value: CategoryType.grid,
                  child: Text(localizations.grid, style: Theme.of(context).textTheme.bodySmall)
                )
              ]
            )
          )
        ),
        if (_categoryType == CategoryType.grid)
          _listTile(
            context,
            Text(localizations.columnCount),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _columnsCount,
                isDense: true,
                isExpanded: true,
                items: [for (int i = 5; i <= 10; i++) i]
                    .map(
                      (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.toString(), style: Theme.of(context).textTheme.bodySmall),
                  ),
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    _columnsCount = value!;
                  });
                  _notifyChange();
                }
              )
            )
          ),
        if (_categoryType == CategoryType.row)
          _listTile(
            context,
            Text(localizations.rowHeight),
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _rowHeight,
                isDense: true,
                isExpanded: true,
                items: [for (int i = 80; i <= 150; i += 10) i]
                    .map(
                      (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.toString(), style: Theme.of(context).textTheme.bodySmall),
                  ),
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    _rowHeight = value!;
                  });
                  _notifyChange();
                }
              )
            )
          )
      ]
    );
  }

  void _notifyChange()
  {

    String initialName = "";
    CategorySort initialSort = Category.Sort;
    CategoryType initialType = Category.Type;
    int initialColumnsCount = Category.ColumnsCount;
    int initialRowHeight = Category.RowHeight;
    if (_category != null) {
      initialName = _category!.name;
      initialSort = _category!.sort;
      initialType = _category!.type;
      initialColumnsCount = _category!.columnsCount;
      initialRowHeight = _category!.rowHeight;
    }

    bool dirty = initialSort != _categorySort || initialType != _categoryType
        || initialColumnsCount != _columnsCount
        || initialRowHeight != _rowHeight || initialName != _name ;

    _SettingsState state = context.read();
    state.setFlags(_name.isNotEmpty, dirty);
  }

  Future<void> _save() async
  {
    final AppsService service = context.read();
    if (_creating) {
      int categoryId = await service.addCategory(_name, sort: _categorySort, type: _categoryType,
          columnsCount: _columnsCount, rowHeight: _rowHeight
      );

      // Auto-populate special categories
      if (_name == 'All Apps') {
        try {
          // Find the actual category object using the ID we just got
          final createdCategory = service.categories.firstWhere((c) => c.id == categoryId);
          await service.autoPopulateCategory(createdCategory);
        } catch (e) {
          // Ignore error if category not found immediately
        }
      }

      _SettingsState state = context.read();
      try {
         // Try to find the section we just created to set it as active
         final createdSection = service.launcherSections.firstWhere((s) => s is Category && s.id == categoryId);
         state.setLauncherSection(createdSection);
      } catch (e) {
         // Fallback to first section
         state.setLauncherSection(service.launcherSections[0]);
      }
    }
    else {
      await service.updateCategory(_category!.id, _name, _categorySort,
          _categoryType, _columnsCount, _rowHeight
      );

      _notifyChange();
    }
  }
}

class _LauncherSpacerSettings extends StatefulWidget
{
  final LauncherSpacer? spacer;

  const _LauncherSpacerSettings({this.spacer});

  @override
  State<StatefulWidget> createState() => _LauncherSpacerSettingsState();
}

class _LauncherSpacerSettingsState extends State<_LauncherSpacerSettings>
{
  int _numberValue;
  LauncherSpacer? _spacer;

  late bool _creating;
  
  // Need preset values for the dropdown
  final List<int> _spacerHeightPresets = [10, 20, 30, 40, 50, 75, 100, 150];

  _LauncherSpacerSettingsState():
    _numberValue = 10;

  @override
  void initState() {
    super.initState();

    _spacer = widget.spacer;
    _creating = _spacer == null;

    int height = 10;
    if (_spacer != null) {
      height = _spacer!.height;
    }

    _numberValue = height;
    
    // Ensure the current value is in our presets, if not add it
    if (!_spacerHeightPresets.contains(_numberValue)) {
      _spacerHeightPresets.add(_numberValue);
      _spacerHeightPresets.sort();
    }
    
    context.read<_SettingsState>().onSave = _save;
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return _listTile(
      context,
      Text(localizations.height),
      Padding(
        padding: EdgeInsets.only(top: 4),
        child: DropdownButtonFormField<int>(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isDense: true,
          isExpanded: true,
          value: _numberValue,
          onChanged: (value) {
            setState(() {
              _numberValue = value!;
            });
            _notifyChange();
          },
          items: _spacerHeightPresets.map((height) {
            return DropdownMenuItem<int>(
              value: height,
              child: Text(height.toString(), style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
        )
      )
    );
  }

  void _notifyChange()
  {
    context.read<_SettingsState>().setFlags(true, _numberValue != _spacer?.height);
  }

  Future<void> _save() async
  {
    AppsService service = context.read();
    if (_creating) {
      await service.addSpacer(_numberValue);

      _SettingsState state = context.read();
      int index = service.launcherSections.length - 1;
      state.setLauncherSection(service.launcherSections[index]);
    }
    else {
      assert(_spacer != null);
      await service.updateSpacerHeight(_spacer!, _numberValue);

      _notifyChange();
    }
  }
}

Widget _listTile(BuildContext context, Widget title, Widget subtitle, {Widget? trailing}) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      dense: true,
      minVerticalPadding: 8,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    )
);
