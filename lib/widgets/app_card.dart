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

import 'dart:async';

import 'package:flauncher/actions.dart';
import 'package:flauncher/app_image_type.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';

const _validationKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

class AppCard extends StatefulWidget
{
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

  late Future<(AppImageType, ImageProvider)> _appImageLoadFuture;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1200,
    ),
  );

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    


    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _appImageLoadFuture = _loadAppBannerOrIcon(Provider.of<AppsService>(context, listen: false));

    // Check if we need to restore focus/reorder mode after a move
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final appsService = Provider.of<AppsService>(context, listen: false);
       if (appsService.pendingReorderFocusPackage == widget.application.packageName &&
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
       if (appsService.pendingReorderFocusPackage == widget.application.packageName &&
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
    FocusManager.instance.removeHighlightModeListener(_focusHighlightModeChanged);
    _animation.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
      onPressed: (key) => _onPressed(context, key),
      onLongPress: (key) => _onLongPress(context, key),
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
              child: RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  transformAlignment: Alignment.center,
                  transform: _scaleTransform(context),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(shouldHighlight ? 0.6 : 0.2),
                        blurRadius: shouldHighlight ? 32 : 6,
                        spreadRadius: shouldHighlight ? 2 : 0,
                        offset: Offset(0, shouldHighlight ? 16 : 4),
                      ),
                    ],
                  ),
                  child: Material(
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
                          onTap: () => _onPressed(context, LogicalKeyboardKey.enter),
                          onLongPress: () => _onLongPress(context, LogicalKeyboardKey.enter),
                          onFocusChange: (focused) {
                            if (focused) {
                              Scrollable.ensureVisible(
                                context,
                                alignment: widget.scrollAlignment,
                                curve: Curves.easeInOut,
                                duration: Duration(milliseconds: 100)
                              );
                            }
                          },

                        ),
                        if (_moving) ..._arrows(),
                        IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            opacity: shouldHighlight ? 0 : 0.10,
                            child: Container(color: Colors.black),
                          ),
                        ),
                        Selector<SettingsService, (bool, String)>(
                          selector: (_, settingsService) => (settingsService.appHighlightAnimationEnabled, settingsService.accentColorHex),
                          builder: (context, settings, _) {
                            final (animationEnabled, accentColorHex) = settings;
                            final accentColor = Color(int.parse('FF$accentColorHex', radix: 16));
                            
                            if (shouldHighlight) {
                              if (animationEnabled) {
                                _animation.repeat(reverse: true);
                                return AnimatedBuilder(
                                  animation: CurvedAnimation(parent: _animation, curve: Curves.easeInOut),
                                  builder: (context, child) {
                                    final opacity = 0.4 + (_animation.value * 0.6);
                                    
                                    return IgnorePointer(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Outer outline (Accent Color)
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: accentColor.withOpacity(opacity),
                                                width: 2
                                              ),
                                            ),
                                          ),
                                          // Inner outline (Black)
                                          Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.black.withOpacity(opacity),
                                                  width: 2
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else {
                                _animation.stop();
                                return IgnorePointer(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: accentColor,
                                            width: 2
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: 2
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }

                            _animation.stop();
                            return const SizedBox();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

  Future<(AppImageType, ImageProvider)> _loadAppBannerOrIcon(AppsService service) async {
    Uint8List bytes = Uint8List(0);

    bytes = await service.getAppBanner(widget.application.packageName);
    AppImageType type = AppImageType.Banner;

    if (bytes.isEmpty) {
      type = AppImageType.Icon;
      bytes = await service.getAppIcon(widget.application.packageName);
    }

    return (type, MemoryImage(bytes));
  }

  Widget _appImage()
  {
    App app = widget.application;

    return FutureBuilder(
      future: _appImageLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          (AppImageType, ImageProvider) record = snapshot.data!;

          if (record.$1 == AppImageType.Banner) {
            return Ink.image(image: record.$2, fit: BoxFit.cover);
          }
          else {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Ink.image(
                      image: record.$2,
                      height: double.maxFinite,
                    ),
                  ),
                  Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        app.name,
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
        }
        else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                app.name,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              )
            ),
          );
        }
        else {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 0, width: 16),
                Text("Loading")
              ],
            ),
          );
        }
      }
    );
  }

  void _focusHighlightModeChanged(FocusHighlightMode mode)
  {
    setState(() { });
  }

  bool _shouldHighlight(BuildContext context)
  {
    return FocusManager.instance.highlightMode == FocusHighlightMode.traditional && Focus.of(context).hasFocus;
  }

  Matrix4 _scaleTransform(BuildContext context) {
    double scale = 1.0;
    if (!_moving && _shouldHighlight(context)) {
      scale = 1.1;
    }
    return Matrix4.diagonal3Values(scale, scale, 1.0);
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
            shape: CircleBorder()
          ),
          child: SizedBox(
            height: 36,
            width: 36,
            child: IconButton(
              icon: Icon(icon, size: 24),
              onPressed: onTap,
              padding: EdgeInsets.all(0)
            )
          )
        )
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    if (_moving) {

      WidgetsBinding.instance.addPostFrameCallback((_) => Scrollable.ensureVisible(context,
          alignment: 0.1, duration: const Duration(milliseconds: 100), curve: Curves.easeInOut));
      if (key == LogicalKeyboardKey.arrowLeft) {

        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {

        widget.onMove(AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {

        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {

        widget.onMove(AxisDirection.down);
      } else if (_validationKeys.contains(key) || key == LogicalKeyboardKey.escape) {

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
    } else if (key == LogicalKeyboardKey.arrowUp && widget.handleUpNavigationToSettings) {
      Actions.invoke(context, const MoveFocusToSettingsIntent());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key))) {
      _showPanel(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel(BuildContext context) async {
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
