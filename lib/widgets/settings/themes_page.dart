/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../providers/settings_service.dart';

class ThemesPage extends StatelessWidget {
  static const String routeName = "themes_panel";

  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Selector<SettingsService, String>(
      selector: (_, settingsService) => settingsService.themes,
      builder: (context, currentShape, _) {
        final settingsService = context.read<SettingsService>();

        return Column(
          children: [
            Text(localizations.themes, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ShapeRadioTile(
                      title: 'Google TV / Android TV',
                      subtitle: 'Rounded corners (8px)',
                      value: 'google_tv',
                      groupValue: currentShape,
                      onChanged: (value) => settingsService.setAppBannerShape(value!),
                      autofocus: currentShape == 'google_tv',
                    ),
                    _ShapeRadioTile(
                      title: 'Apple TV (tvOS)',
                      subtitle: 'Larger rounded corners (16px)',
                      value: 'apple_tv',
                      groupValue: currentShape,
                      onChanged: (value) => settingsService.setAppBannerShape(value!),
                      autofocus: currentShape == 'apple_tv',
                    ),
                    _ShapeRadioTile(
                      title: 'Roku OS / Fire OS',
                      subtitle: 'Square corners (0px)',
                      value: 'roku_os',
                      groupValue: currentShape,
                      onChanged: (value) => settingsService.setAppBannerShape(value!),
                      autofocus: currentShape == 'roku_os' || currentShape == 'fire_os',
                    ),
                    _ShapeRadioTile(
                      title: 'LG WebOS / Tizen',
                      subtitle: 'Circular / Pill shape',
                      value: 'web_os',
                      groupValue: currentShape,
                      onChanged: (value) => settingsService.setAppBannerShape(value!),
                      autofocus: currentShape == 'web_os',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShapeRadioTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final bool autofocus;

  const _ShapeRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  State<_ShapeRadioTile> createState() => _ShapeRadioTileState();
}

class _ShapeRadioTileState extends State<_ShapeRadioTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.value == widget.groupValue;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (hasFocus) {
            setState(() {
              _hasFocus = hasFocus;
            });
            if (hasFocus) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          },
          child: InkWell(
            onTap: () {
              widget.onChanged(widget.value);
            },
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _hasFocus ? Colors.white.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: _hasFocus
                    ? Border.all(color: primaryColor, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: primaryColor)
                  else
                    Icon(Icons.circle_outlined, color: Colors.white38),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
