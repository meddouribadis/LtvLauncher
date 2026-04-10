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
  DateTime? _lastMoveAt;
  late FocusNode _focusNode;

  // late Future<(AppImageType, ImageProvider)> _appImageLoadFuture;
  (AppImageType, ImageProvider)? _loadedImage;
  bool _imageLoadError = false;

  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1200,
    ),
  );

  late final CurvedAnimation _curvedAnimation =  CurvedAnimation(parent: _animation, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
    _loadAppImage(Provider.of<AppsService>(context, listen: false));

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

    final appsService = Provider.of<AppsService>(context, listen: false);

    if (oldWidget.application.packageName != widget.application.packageName) {
      _loadedImage = null;
      _imageLoadError = false;
      _loadAppImage(appsService);
    } else if (appsService.consumeDirtyImage(widget.application.packageName)) {
      _loadAppImage(appsService);
    }
    
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
    _curvedAnimation.dispose();
    _animation.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showAppNames = context.select<SettingsService, bool>((s) => s.showAppNamesBelowIcons);
    final appImageWidget = _appImage();

    return FocusKeyboardListener(
      onPressed: _onPressed,
      onLongPress: _onLongPress,
      builder: (context) {
        final bool shouldHighlight = _shouldHighlight(context);

        return AnimatedScale(
          scale: _clicked ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _clicked ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RepaintBoundary(
                      child: AnimatedScale(
                        scale: !_moving && shouldHighlight ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        curve: Curves.easeInOut,
                        //transformAlignment: Alignment.center,
                        //transform: _scaleTransform(context),
                        child: Material(
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          elevation: shouldHighlight ? 16 : 4,
                          shadowColor: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                focusNode: _focusNode,
                                autofocus: widget.autofocus,
                                focusColor: Colors.transparent,
                                child: appImageWidget,
                                onTap: () => _onPressed(LogicalKeyboardKey.enter),
                                onLongPress: () => _onLongPress(LogicalKeyboardKey.enter),
                                onFocusChange: (focused) {
                                  Scrollable.ensureVisible(
                                    context,
                                    // This specific alignment value is not only
                                    // to center the focused card in the row while
                                    // scrolling, but to prevent the topmost category
                                    // title to be hidden by the content above it when
                                    // scrolling from the app bar. How it relates to this,
                                    // I don't know
                                    alignment: widget.scrollAlignment,
                                    curve: Curves.easeInOut,
                                    duration: const Duration(milliseconds: 300)
                                  );
                                },

                              ),
                              if (_moving) ..._arrows(),
                              // const IgnorePointer(
                              //   child: DecoratedBox(
                              //     decoration: BoxDecoration(
                              //       gradient: LinearGradient(
                              //         begin: Alignment.topCenter,
                              //         end: Alignment.bottomCenter,
                              //         stops: [0.0, 0.5, 1.0],
                              //         colors: [
                              //           Color(0x1AFFFFFF),
                              //           Color(0xDFFFFFF),
                              //           Colors.black12,
                              //         ],
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  opacity: shouldHighlight ? 0.0 : 1.0,
                                  child: const ColoredBox(color: Color(0x1A000000)),
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
                                        animation: _curvedAnimation,
                                        builder: (context, child) {
                                          final opacity = 0.4 + (_animation.value * 0.6);

                                          return IgnorePointer(
                                            child: RepaintBoundary(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  // Outer outline (Accent Color)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: accentColor.withOpacity(opacity),
                                                        width: 1
                                                      ),
                                                    ),
                                                  ),
                                                  // Inner outline (Black)
                                                  //Padding(
                                                  //  padding: const EdgeInsets.all(2),
                                                  //  child: Container(
                                                  //    decoration: BoxDecoration(
                                                  //      borderRadius: BorderRadius.circular(6),
                                                  //      border: Border.all(
                                                  //        color: Colors.black.withOpacity(opacity),
                                                  //        width: 2
                                                  //      ),
                                                  //    ),
                                                  //  ),
                                                  //),
                                                ],
                                              ),
                                            )
                                          );
                                        },
                                      );
                                    } else {
                                      _animation.stop();
                                      return IgnorePointer(
                                        child: RepaintBoundary(
                                          child :Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: accentColor,
                                                    width: 1
                                                  ),
                                                ),
                                              ),
                                              // Padding(
                                              //   padding: const EdgeInsets.all(2),
                                              //   child: DecoratedBox(
                                              //     decoration: BoxDecoration(
                                              //       borderRadius: BorderRadius.circular(6),
                                              //       border: Border.all(
                                              //         color: Colors.black,
                                              //         width: 2
                                              //       ),
                                              //     ),
                                              //   ),
                                              // ),
                                            ],
                                          ),
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
                if (showAppNames)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.application.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<(AppImageType, ImageProvider)> _loadAppBannerOrIcon(AppsService service) async {
    Uint8List bytes = Uint8List(0);

    bytes = await service.getAppBanner(widget.application.packageName);
    AppImageType type = AppImageType.Banner;

    if (bytes.isEmpty) {
      type = AppImageType.Icon;
      bytes = await service.getAppIcon(widget.application.packageName);
    }

    return (type, ResizeImage(MemoryImage(bytes), width: 480));
  }

  Future<void> _loadAppImage(AppsService service) async {
    try {
      Uint8List bytes = Uint8List(0);

      bytes = await service.getAppBanner(widget.application.packageName);
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

  Widget _appImage()
  {
    App app = widget.application;

    if(_loadedImage != null) {
      final (type, image) = _loadedImage!;
      if (type == AppImageType.Banner) {
        return Ink.image(image: image, fit: BoxFit.cover);
      }
      else {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Ink.image(
                  image: image,
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
    else if (_imageLoadError) {
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
    // Old way to load app images
    // return FutureBuilder(
    //   future: _appImageLoadFuture,
    //   builder: (context, snapshot) {
    //     if (snapshot.hasData) {
    //       (AppImageType, ImageProvider) record = snapshot.data!;
    //
    //       if (record.$1 == AppImageType.Banner) {
    //         return Ink.image(image: record.$2, fit: BoxFit.cover);
    //       }
    //       else {
    //         return Padding(
    //           padding: const EdgeInsets.all(8),
    //           child: Row(
    //             children: [
    //               Expanded(
    //                 flex: 2,
    //                 child: Ink.image(
    //                   image: record.$2,
    //                   height: double.maxFinite,
    //                 ),
    //               ),
    //               Flexible(
    //                 flex: 3,
    //                 child: Padding(
    //                   padding: const EdgeInsets.only(left: 8),
    //                   child: Text(
    //                     app.name,
    //                     style: Theme.of(context).textTheme.bodySmall,
    //                     overflow: TextOverflow.ellipsis,
    //                     maxLines: 3,
    //                   ),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         );
    //       }
    //     }
    //     else if (snapshot.hasError) {
    //       return Padding(
    //         padding: const EdgeInsets.all(8),
    //         child: Center(
    //           child: Text(
    //             app.name,
    //             style: Theme.of(context).textTheme.bodySmall,
    //             overflow: TextOverflow.ellipsis,
    //             maxLines: 3,
    //           )
    //         ),
    //       );
    //     }
    //     else {
    //       return const Padding(
    //         padding: EdgeInsets.all(8),
    //         child: Row(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           children: [
    //             CircularProgressIndicator(),
    //             SizedBox(height: 0, width: 16),
    //             Text("Loading")
    //           ],
    //         ),
    //       );
    //     }
    //   }
    // );
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

  KeyEventResult _onPressed(LogicalKeyboardKey? key) {
    if (_moving) {
      if (_validationKeys.contains(key) || key == LogicalKeyboardKey.escape) {
        _lastMoveAt = null;
        setState(() => _moving = false);
        widget.onMoveEnd();
      } else {
        final now = DateTime.now();
        if (_lastMoveAt != null &&
            now.difference(_lastMoveAt!).inMilliseconds < 60) {
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onMove(AxisDirection.left);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          widget.onMove(AxisDirection.up);
        } else if (key == LogicalKeyboardKey.arrowRight) {
          widget.onMove(AxisDirection.right);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          widget.onMove(AxisDirection.down);
        } else {
          return KeyEventResult.ignored;
        }

        _lastMoveAt = now;
        WidgetsBinding.instance.addPostFrameCallback((_) => Scrollable.ensureVisible(context,
            alignment: 0.1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
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

  KeyEventResult _onLongPress(LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key))) {
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
