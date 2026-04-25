import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_service.dart';
import 'daily_data_usage_widget.dart';
import 'date_time_widget.dart';
import 'network_widget.dart';

class FocusAwareAppBar extends StatefulWidget implements PreferredSizeWidget
{
  const FocusAwareAppBar({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return FocusAwareAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class FocusAwareAppBarState extends State<FocusAwareAppBar>
{
  bool focused = false;
  late FocusNode _settingsFocusNode;

  @override
  void initState() {
    super.initState();
    _settingsFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    super.dispose();
  }

  void focusSettings() {
    _settingsFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsService, bool>(
      selector: (_, settings) => settings.autoHideAppBarEnabled,
      builder: (context, autoHide, widget) {
        if (autoHide) {
          return Focus(
            canRequestFocus: false,
            child: AnimatedContainer(
              curve: Curves.decelerate,
              duration: Duration(milliseconds: 150),
              height: focused ? kToolbarHeight : 0,
              child: widget!
            ),
            onFocusChange: (hasFocus) {
              this.setState(() {
                focused = hasFocus;
              });
            }
          );
        }

        return widget!;
      },
      child: RepaintBoundary(
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          // Left side: Settings, Network indicator, WiFi usage
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Settings button (moved to left side)
              _FocusableIconButton(
                icon: Icons.settings_outlined,
                focusNode: _settingsFocusNode,
                onPressed: () => showDialog(context: context, builder: (_) => const SettingsPanel()),
              ),
              const SizedBox(width: 16),
              // Network indicator (conditionally shown)
              Selector<SettingsService, bool>(
                selector: (_, settings) => settings.showNetworkIndicatorInStatusBar,
                builder: (context, showNetwork, _) => showNetwork
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _FocusableNetworkWidget(),
                    )
                  : const SizedBox.shrink(),
              ),
              // Data usage widget
              Selector<SettingsService, bool>(
                selector: (_, settings) => settings.showDataWidgetInStatusBar,
                builder: (context, showData, _) => showData
                  ? const DailyDataUsageWidget()
                  : const SizedBox.shrink(),
              ),
            ],
          ),
          // Right side: Date/Time only
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 32),
              child: Selector<SettingsService,
                  ({
                    bool showDateInStatusBar,
                    bool showTimeInStatusBar,
                    String dateFormat,
                    String timeFormat })>(
                selector: (context, service) => (
                showDateInStatusBar: service.showDateInStatusBar,
                showTimeInStatusBar: service.showTimeInStatusBar,
                dateFormat: service.dateFormat,
                timeFormat: service.timeFormat),
                builder: (context, dateTimeSettings, _) {
                  // Define standard text style
                  const textStyle = TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                    ],
                  );

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date
                      if (dateTimeSettings.showDateInStatusBar)
                        DateTimeWidget(
                          dateTimeSettings.dateFormat,
                          key: const Key("statusbar_date"),
                          updateInterval: const Duration(minutes: 1),
                          textStyle: textStyle,
                        ),
                      
                      if (dateTimeSettings.showDateInStatusBar && dateTimeSettings.showTimeInStatusBar)
                          const SizedBox(width: 16),

                      // Clock
                      if (dateTimeSettings.showTimeInStatusBar)
                        DateTimeWidget(
                          dateTimeSettings.timeFormat,
                          key: const Key("statusbar_clock"),
                          textStyle: textStyle.copyWith(fontWeight: FontWeight.bold),
                        ),
                    ]
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable focusable icon button with consistent outline focus indicator
class _FocusableIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _FocusableIconButton({required this.icon, required this.onPressed, this.focusNode});

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),  // Match network indicator padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: _focused
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
              boxShadow: _focused
                ? const [BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1)]
                : null,
            ),
            child: Icon(widget.icon,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Network widget with consistent focus indicator
class _FocusableNetworkWidget extends StatefulWidget {
  @override
  State<_FocusableNetworkWidget> createState() => _FocusableNetworkWidgetState();
}

class _FocusableNetworkWidgetState extends State<_FocusableNetworkWidget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _focused
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
          boxShadow: _focused
            ? const [BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1)]
            : null,
        ),
        child: const NetworkWidget(),
      ),
    );
  }
}