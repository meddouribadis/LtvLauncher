/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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

import 'dart:io';

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

// Date format presets
const List<(String format, String example)> dateFormatPresets = [
  ('EEEE d', 'Friday 17'),
  ('E d', 'Fri 17'),
  ('dd/MM/y', '17/01/2026'),
  ('MMM d, y', 'Jan 17, 2026'),
  ('d MMMM', '17 January'),
  ('M/d/y', '1/17/2026'),
];

// Time format presets (using 3:45 PM / 15:45 for clear 12h/24h distinction)
const List<(String format, String example)> timeFormatPresets = [
  ('H:mm', '3:45'),
  ('hh:mm', '03:45'),
  ('h:mm a', '3:45 PM'),
  ('hh:mm a', '03:45 PM'),
  ('HH:mm', '15:45'),
];

class DateTimeFormatPage extends StatefulWidget {
  static const String routeName = "date_time_format_panel";

  const DateTimeFormatPage({Key? key}) : super(key: key);

  @override
  State<DateTimeFormatPage> createState() => _DateTimeFormatPageState();
}

class _DateTimeFormatPageState extends State<DateTimeFormatPage> {
  // We read formatting directly from service, UI updates via Consumer if needed, 
  // but since we push updates immediately, local state is redundant if using Consumer.
  // However, for immediate feedback while typing/selecting, local state is fine or just read from provider.
  // Let's use Consumer for the whole page.

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    
    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.dateAndTimeFormat, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildPreview(context, service.dateFormat, service.timeFormat),
                  const SizedBox(height: 24),
                  const Divider(),
                  
                  // Date format section
                  Text(
                    localizations.date,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  ...dateFormatPresets.asMap().entries.map((entry) {
                    final isSelected = service.dateFormat == entry.value.$1;
                    return FocusableSettingsTile(
                      autofocus: entry.key == 0,
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value.$2),
                          Text(entry.value.$1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      onPressed: () => service.setDateTimeFormat(entry.value.$1, service.timeFormat),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Time format section
                  Text(
                    localizations.time,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  ...timeFormatPresets.map((preset) {
                    final isSelected = service.timeFormat == preset.$1;
                    return FocusableSettingsTile(
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.$2),
                          Text(preset.$1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      onPressed: () => service.setDateTimeFormat(service.dateFormat, preset.$1),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildPreview(BuildContext context, String dateFormat, String timeFormat) {
    final now = DateTime.now();
    String preview = '';

    try {
      if (dateFormat.isNotEmpty) {
        preview = DateFormat(dateFormat, Platform.localeName).format(now);
      }
      if (timeFormat.isNotEmpty) {
        if (preview.isNotEmpty) preview += ' — ';
        preview += DateFormat(timeFormat, Platform.localeName).format(now);
      }
    } catch (e) {
      preview = 'Invalid format';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        preview.isEmpty ? 'Select formats below' : preview,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
