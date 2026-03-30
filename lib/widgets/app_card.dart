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

import 'package:flauncher/actions.dart';
import 'package:flauncher/app_image_type.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';
import '../providers/settings_service.dart';

const _validationKeys = [
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.gameButtonA
];

class AppCard extends StatefulWidget {
  final App application;
  final Category category;
  final bool autofocus;
  final void Function(AxisDirection) onMove;
  final VoidCallback onMoveEnd;
  final bool handleUpNavigationToSettings;
  final double scrollAlignment;

  const AppCard({
    super.key,
    required this.application,
    required this.category,
    required this.autofocus,
    required this.onMove,
    required this.onMoveEnd,
    this.handleUpNavigationToSettings = false,
    this.scrollAlignment = 0.5,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _moving = false;
  bool _clicked = false;
  late FocusNode _focusNode;

  (AppImageType, ImageProvider)? _loadedImage;
  bool _imageLoadError = false;

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1200,
    ),
  );

  late final CurvedAnimation _curvedAnimation =
  CurvedAnimation(parent: _animation, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _loadAppImage(Provider.of<AppsService>(context, listen: false));

    // Check if we need to restore focus/reorder mode after a move
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appsService = Provider.of<AppsService>(context, listen: false);
      if (appsService.pendingReorderFocusPackage ==
              widget.application.packageName &&
          appsService.pendingReorderFocusCategoryId == widget.category.id) {
        appsService.clearPendingReorderFocusPackage();
        _focusNode.requestFocus();

        setState(() {
          _moving = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check for pending focus on update as well
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appsService = Provider.of<AppsService>(context, listen: false);
      if (appsService.pendingReorderFocusPackage ==
              widget.application.packageName &&
          appsService.pendingReorderFocusCategoryId == widget.category.id) {
        appsService.clearPendingReorderFocusPackage();
        _focusNode.requestFocus();

        if (!_moving) {
          setState(() {
            _moving = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance
        .removeHighlightModeListener(_focusHighlightModeChanged);
    _focusNode.dispose();
    _animation.dispose();
    _curvedAnimation.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: _onPressed,
        onLongPress: _onLongPress,
        builder: (context) {
          final bool shouldHighlight = _shouldHighlight(context);

          return AnimatedScale(
              scale: _clicked ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _clicked ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedScale(
                    scale: !_moving && shouldHighlight ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Unfocused shadow (static, fades out on focus)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: shouldHighlight ? 0.0 : 1.0,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Focused shadow (static, fades in on focus)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: shouldHighlight ? 1.0 : 0.0,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Card content
                        Material(
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          elevation: 0,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                focusNode: _focusNode,
                                autofocus: widget.autofocus,
                                focusColor: Colors.transparent,
                                child: _appImage(),
                                onTap: () =>
                                    _onPressed(LogicalKeyboardKey.enter),
                                onLongPress: () =>
                                    _onLongPress(LogicalKeyboardKey.enter),
                                onFocusChange: (focused) {
                                  if (focused) {
                                    Scrollable.ensureVisible(context,
                                        alignment: widget.scrollAlignment,
                                        curve: Curves.easeInOut,
                                        duration:
                                            const Duration(milliseconds: 300));
                                  }
                                },
                              ),
                              if (_moving) ..._arrows(),
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  opacity: shouldHighlight ? 0 : 0.05,
                                  child: Container(color: Colors.black),
                                ),
                              ),
                              Selector<SettingsService, (bool, String)>(
                                selector: (_, settingsService) => (
                                  settingsService.appHighlightAnimationEnabled,
                                  settingsService.accentColorHex
                                ),
                                builder: (context, settings, _) {
                                  final (animationEnabled, accentColorHex) =
                                      settings;
                                  //final accentColor = Color(
                                  //    int.parse('FF$accentColorHex', radix: 16));

                                  if (shouldHighlight) {
                                    return IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          gradient: RadialGradient(
                                            center: Alignment.topCenter,
                                            radius: 2.0,
                                            colors: [
                                              Colors.white.withOpacity(0.10),
                                              Colors.white.withOpacity(0.02),
                                            ],
                                            stops: [0.0, 1.5],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  _animation.stop();
                                  return const SizedBox();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
        },
      );

  Future<void> _loadAppImage(AppsService service) async {
    try {
      Uint8List bytes = await service.getAppBanner(widget.application.packageName);
      AppImageType type = AppImageType.Banner;

      if (bytes.isEmpty) {
        type = AppImageType.Icon;
        bytes = await service.getAppIcon(widget.application.packageName);
      }

      if (mounted) {
        setState(() {
          _loadedImage = (type, ResizeImage(MemoryImage(bytes), width: 480));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _imageLoadError = true);
      }
    }
  }

  Widget _appImage() {
    if (_loadedImage != null) {
      final (type, image) = _loadedImage!;
      if (type == AppImageType.Banner) {
        return Ink.image(image: image, fit: BoxFit.cover);
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Ink.image(image: image, height: double.maxFinite),
            ),
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  widget.application.name,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_imageLoadError) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(
            widget.application.name,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 0, width: 16),
          Text("Loading"),
        ],
      ),
    );
  }

  void _focusHighlightModeChanged(FocusHighlightMode mode) {
    //if (_focusNode.hasFocus) {
      setState(() {});
    //}
  }

  bool _shouldHighlight(BuildContext context) {
    return FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional &&
        Focus.of(context).hasFocus;
  }

  List<Widget> _arrows() {
    final arrows = <Widget>[
      _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left, () {
        widget.onMove(AxisDirection.left);
      }),
      _arrow(Alignment.centerRight, Icons.keyboard_arrow_right, () {
        widget.onMove(AxisDirection.right);
      }),
    ];

    // Only show Up/Down arrows for grid layouts
    if (widget.category.type == CategoryType.grid) {
      arrows.add(_arrow(Alignment.topCenter, Icons.keyboard_arrow_up, () {
        widget.onMove(AxisDirection.up);
      }));
      arrows.add(_arrow(Alignment.bottomCenter, Icons.keyboard_arrow_down, () {
        widget.onMove(AxisDirection.down);
      }));
    }

    return arrows;
  }

  Widget _arrow(Alignment alignment, IconData icon, VoidCallback onTap) =>
      Align(
          alignment: alignment,
          child: Ink(
              decoration: ShapeDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                  shape: CircleBorder()),
              child: SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                      icon: Icon(icon, size: 24),
                      onPressed: onTap,
                      padding: EdgeInsets.all(0)))));

  KeyEventResult _onPressed(LogicalKeyboardKey key) {
    if (_moving) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          Scrollable.ensureVisible(context,
              alignment: 0.1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut));
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        widget.onMove(AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        widget.onMove(AxisDirection.down);
      } else if (_validationKeys.contains(key) ||
          key == LogicalKeyboardKey.escape) {
        setState(() => _moving = false);
        widget.onMoveEnd();
      } else {
        return KeyEventResult.ignored;
      }

      return KeyEventResult.handled;
    } else if (_validationKeys.contains(key)) {
      if (!_clicked) {
        setState(() => _clicked = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          context.read<AppsService>().launchApp(widget.application);
          // Reset after a short delay so it looks normal when user returns
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _clicked = false);
            }
          });
        });
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp &&
        widget.handleUpNavigationToSettings) {
      Actions.invoke(context, const MoveFocusToSettingsIntent());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onLongPress(LogicalKeyboardKey key) {
    if (!_moving && longPressableKeys.contains(key)) {
      _showPanel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel() async {
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.application,
      ),
    );
    if (result == ApplicationInfoPanelResult.reorderApp) {
      setState(() => _moving = true);
    }
  }
}
