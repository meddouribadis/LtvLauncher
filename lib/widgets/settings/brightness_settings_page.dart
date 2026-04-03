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

import '../../providers/brightness_service.dart';
import '../rounded_switch_list_tile.dart';

class BrightnessSettingsPage extends StatelessWidget {
  static const String routeName = "brightness_settings_panel";

  const BrightnessSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BrightnessService>(
      builder: (context, brightnessService, _) {
        final isEnabled = brightnessService.isEnabled;
        final currentSlot = brightnessService.getCurrentTimeSlot();
        
        return Column(
          children: [
            Text('Brightness Scheduler', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!brightnessService.hasPermission)
                      Card(
                        color: Colors.orange.withOpacity(0.1),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Permission Required',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('To control brightness on this device, you must grant permission via ADB:'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SelectableText(
                                  'adb shell appops set com.omeda.arc WRITE_SETTINGS allow', // Command for Manual Grant
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: brightnessService.requestPermission,
                                    icon: const Icon(Icons.settings),
                                    label: const Text('Grant Permission'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: brightnessService.checkPermission,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Check Status'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    // Enable/Disable toggle
                    RoundedSwitchListTile(
                      autofocus: true,
                      title: Text(
                        'Enable Scheduler',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      secondary: Icon(isEnabled ? Icons.schedule : Icons.schedule_outlined),
                      value: isEnabled,
                      onChanged: (value) => brightnessService.setEnabled(value),
                    ),
                    
                    if (isEnabled) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Current: ${currentSlot.label}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const Divider(),
                      
                      // Time slot sliders
                      ...TimeSlot.values.map((slot) => _TimeSlotSlider(
                        slot: slot,
                        isCurrentSlot: slot == currentSlot,
                        brightness: brightnessService.getBrightnessForSlot(slot),
                        onChanged: (value) => brightnessService.setBrightnessForSlot(slot, value),
                      )),
                    ],
                    
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.science_outlined, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'EXPERIMENTAL: This feature is untested and may be removed in future versions based on user feedback.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Note: Some Android TV devices may not support app-level brightness control.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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

class _TimeSlotSlider extends StatefulWidget {
  final TimeSlot slot;
  final bool isCurrentSlot;
  final int brightness;
  final ValueChanged<int> onChanged;

  const _TimeSlotSlider({
    required this.slot,
    required this.isCurrentSlot,
    required this.brightness,
    required this.onChanged,
  });

  @override
  State<_TimeSlotSlider> createState() => _TimeSlotSliderState();
}

class _TimeSlotSliderState extends State<_TimeSlotSlider> {
  late double _value;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _value = widget.brightness.toDouble();
  }

  @override
  void didUpdateWidget(_TimeSlotSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      _value = widget.brightness.toDouble();
    }
  }

  void _adjustValue(double delta) {
    final newValue = (_value + delta).clamp(5.0, 100.0);
    if (newValue != _value) {
      setState(() => _value = newValue);
      widget.onChanged(newValue.round());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        // Intercept left/right to control slider, let up/down pass through for navigation
        DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
          onInvoke: (intent) {
            switch (intent.direction) {
              case TraversalDirection.left:
                _adjustValue(-5);
                return null; // Consume the event
              case TraversalDirection.right:
                _adjustValue(5);
                return null; // Consume the event
              case TraversalDirection.up:
              case TraversalDirection.down:
                // Let these pass through to default focus traversal
                return Actions.invoke(context, intent);
            }
          },
        ),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _focused 
                ? Colors.white10 
                : (widget.isCurrentSlot ? Colors.white.withOpacity(0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrentSlot 
                ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getIconForSlot(widget.slot),
                        size: 18,
                        color: widget.isCurrentSlot 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.slot.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.isCurrentSlot ? FontWeight.bold : FontWeight.normal,
                          color: widget.isCurrentSlot 
                              ? Theme.of(context).colorScheme.primary 
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_value.round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _value,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  onChanged: (value) {
                    setState(() => _value = value);
                  },
                  onChangeEnd: (value) {
                    widget.onChanged(value.round());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSlot(TimeSlot slot) {
    switch (slot) {
      case TimeSlot.morning:
        return Icons.wb_twilight;
      case TimeSlot.day:
        return Icons.wb_sunny;
      case TimeSlot.afternoon:
        return Icons.sunny;
      case TimeSlot.evening:
        return Icons.nights_stay;
      case TimeSlot.night:
        return Icons.bedtime;
    }
  }
}
