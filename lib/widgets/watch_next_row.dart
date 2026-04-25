/*
 * FLauncher
 * Copyright (C) 2021 Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/models/watch_next_item.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void _playFocusSound(BuildContext context) {
  final settingsService = context.read<SettingsService>();
  if (settingsService.appKeyClickEnabled) {
    Feedback.forTap(context);
  } else {
    context.findRenderObject()?.sendSemanticsEvent(const TapSemanticEvent());
  }
}

const double _kWatchNextItemWidth = 400;
const double _kWatchNextItemHeight = 220;
const double _kWatchNextItemSpacing = 16;
const double _kWatchNextRowVerticalSlack = 8;

class WatchNextRow extends StatelessWidget {
  final bool isFirstSection;
  final bool isAboveDock;

  const WatchNextRow({
    super.key,
    this.isFirstSection = false,
    this.isAboveDock = false,
  });

  @override
  Widget build(BuildContext context) {
    final showWatchNext = context.select<SettingsService, bool>((s) => s.showWatchNextSection);

    if (!showWatchNext) {
      return const SizedBox.shrink();
    }

    return Selector<WatchNextService, ({bool isLoading, List<WatchNextItem> items})>(
      selector: (_, service) => (isLoading: service.isLoading, items: service.items),
      builder: (context, data, child) {
        if (data.isLoading) {
          return const SizedBox.shrink();
        }

        if (data.items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 8, top: 8),
              child: Text(
                'Watch Next',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(1, 1),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            _WatchNextCleanRow(
              items: data.items,
              isFirstSection: isFirstSection,
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _WatchNextCleanRow extends StatefulWidget {
  final List<WatchNextItem> items;
  final bool isFirstSection;

  const _WatchNextCleanRow({
    required this.items,
    this.isFirstSection = false,
  });

  @override
  State<_WatchNextCleanRow> createState() => _WatchNextCleanRowState();
}

class _WatchNextCleanRowState extends State<_WatchNextCleanRow> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _createFocusNodes();
  }

  @override
  void didUpdateWidget(covariant _WatchNextCleanRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _disposeFocusNodes();
      _createFocusNodes();
    }
  }

  void _createFocusNodes() {
    _focusNodes.clear();
    for (int i = 0; i < widget.items.length; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  void _disposeFocusNodes() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeFocusNodes();
    super.dispose();
  }

  KeyEventResult _handleNavigationKey(int index, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight && index < widget.items.length - 1) {
      _focusNodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChanged(int index, bool focused) {
    if (focused) {
      _scrollToIndex(index);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    final itemWidth = _kWatchNextItemWidth + _kWatchNextItemSpacing;
    final scrollOffset = (index * itemWidth) - 24;
    final targetOffset = scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    if ((_scrollController.offset - targetOffset).abs() < 8) {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kWatchNextItemHeight + 24 + _kWatchNextRowVerticalSlack,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemExtent: _kWatchNextItemWidth + _kWatchNextItemSpacing,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _WatchNextCard(
            item: item,
            focusNode: _focusNodes[index],
            autofocus: widget.isFirstSection && index == 0,
            onFocusChanged: (focused) => _onFocusChanged(index, focused),
            onNavigationKey: (key) => _handleNavigationKey(index, key),
          );
        },
      ),
    );
  }
}

class _WatchNextCard extends StatefulWidget {
  final WatchNextItem item;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<bool> onFocusChanged;
  final KeyEventResult Function(LogicalKeyboardKey key) onNavigationKey;

  const _WatchNextCard({
    required this.item,
    required this.focusNode,
    this.autofocus = false,
    required this.onFocusChanged,
    required this.onNavigationKey,
  });

  @override
  State<_WatchNextCard> createState() => _WatchNextCardState();
}

class _WatchNextCardState extends State<_WatchNextCard> {
  bool _isHovered = false;
  bool _clicked = false;

  @override
  void initState() {
    super.initState();
    context.read<WatchNextService>().ensurePosterLoaded(widget.item.posterUri);
  }

  @override
  void didUpdateWidget(covariant _WatchNextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _isHovered = widget.focusNode.hasFocus;
    }
    if (oldWidget.item.posterUri != widget.item.posterUri) {
      context.read<WatchNextService>().ensurePosterLoaded(widget.item.posterUri);
    }
  }

  void _handleTap() {
    _triggerLaunchWithFeedback();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.arrowRight:
          return widget.onNavigationKey(event.logicalKey);
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          _triggerLaunchWithFeedback();
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _triggerLaunchWithFeedback() {
    if (_clicked) return;
    setState(() => _clicked = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      context.read<WatchNextService>().launchItem(widget.item);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _clicked = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final posterData = context.select<WatchNextService, Uint8List?>(
      (service) => service.getCachedPoster(widget.item.posterUri),
    );
    final targetScale = _clicked ? 0.94 : (_isHovered ? 1.06 : 1.0);

    final posterLoadFailed = context.select<WatchNextService, bool>(
      (service) => service.hasPosterLoadFailed(widget.item.posterUri),
    );


    return Padding(
      padding: const EdgeInsets.only(right: _kWatchNextItemSpacing),
      child: RepaintBoundary(
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _handleKeyEvent,
          onFocusChange: (focused) {
            if (_isHovered == focused) return;
            setState(() => _isHovered = focused);
            if (focused) {
              _playFocusSound(context);
            }
            widget.onFocusChanged(focused);
          },
          child: GestureDetector(
            onTap: _handleTap,
            child: AnimatedScale(
              scale: targetScale,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: _isHovered ? 4 : 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: _kWatchNextItemWidth,
                  height: _kWatchNextItemHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPoster(posterData, posterLoadFailed),
                      if (_isHovered) _buildOverlay(),
                      if (_isHovered) _buildProgressIndicator(),
                      if (_isHovered)
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      if (!_isHovered) const IgnorePointer(child: ColoredBox(color: Color(0x1A000000))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(Uint8List? posterData, bool posterLoadFailed) {
    if (posterData != null) {
      return Image.memory(
        posterData,
        fit: BoxFit.cover,
        width: _kWatchNextItemWidth,
        height: _kWatchNextItemHeight,
        cacheWidth: _kWatchNextItemWidth.toInt(),
        cacheHeight: _kWatchNextItemHeight.toInt(),
        filterQuality: FilterQuality.low,
      );
    }

    return Container(
      color: Colors.grey.shade800,
      child: widget.item.posterUri != null && !posterLoadFailed
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _buildFallbackWidget(),
    );
  }

  Widget _buildFallbackWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.play_circle_outline,
          size: 40,
          color: Colors.white70,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.0),
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.item.description != null)
            Text(
              widget.item.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (widget.item.progressPercent == null || widget.item.progressPercent == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: widget.item.progressPercent! / 100.0,
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.primary,
        ),
        minHeight: 3,
      ),
    );
  }
}
