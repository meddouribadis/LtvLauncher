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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const longPressableKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

class FocusKeyboardListener extends StatefulWidget {
  final Widget child;
  final KeyEventResult Function(LogicalKeyboardKey)? onPressed;
  final KeyEventResult Function(LogicalKeyboardKey)? onLongPress;

  FocusKeyboardListener({
    Key? key,
    required this.child,
    this.onPressed,
    this.onLongPress,
  }) : super(key: key);

  @override
  _FocusKeyboardListenerState createState() => _FocusKeyboardListenerState();
}

class _FocusKeyboardListenerState extends State<FocusKeyboardListener> {
  int? _keyDownAt;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        // Using "onKeyEvent", in favor of the deprecated "onKey"
        // seems to break the fix for issue #21 so, keep using the old property
        onKey: (_, rawKeyEvent) => _handleKey(context, rawKeyEvent),
        child: widget.child,
      );

  KeyEventResult _handleKey(BuildContext context, RawKeyEvent rawKeyEvent) {
    switch (rawKeyEvent.runtimeType) {
      case RawKeyDownEvent:
        return _keyDownEvent(context, rawKeyEvent.logicalKey);
      case RawKeyUpEvent:
        return _keyUpEvent(context, rawKeyEvent.logicalKey);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _keyDownEvent(BuildContext context, LogicalKeyboardKey key) {
    if (!longPressableKeys.contains(key)) {
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }
    if (_keyDownAt == null) {
      _keyDownAt = DateTime.now().millisecondsSinceEpoch;
      return KeyEventResult.handled;
    } else if (_longPress()) {
      _keyDownAt = null;
      return widget.onLongPress?.call(key) ?? KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _keyUpEvent(BuildContext context, LogicalKeyboardKey key) {
    if (_keyDownAt != null) {
      _keyDownAt = null;
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _longPress() => _keyDownAt != null && DateTime.now().millisecondsSinceEpoch - _keyDownAt! >= 500;
}
