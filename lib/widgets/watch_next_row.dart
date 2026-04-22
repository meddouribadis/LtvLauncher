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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const double _kWatchNextItemWidth = 400;
const double _kWatchNextItemHeight = 220;
const double _kWatchNextItemSpacing = 12;

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

    return Consumer<WatchNextService>(
      builder: (context, service, child) {
        if (service.isLoading) {
          return const SizedBox.shrink();
        }

        if (!service.hasItems) {
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
              items: service.items,
              service: service,
              isFirstSection: isFirstSection,
            ),
          ],
        );
      },
    );
  }
}

class _WatchNextCleanRow extends StatefulWidget {
  final List<WatchNextItem> items;
  final WatchNextService service;
  final bool isFirstSection;

  const _WatchNextCleanRow({
    required this.items,
    required this.service,
    this.isFirstSection = false,
  });

  @override
  State<_WatchNextCleanRow> createState() => _WatchNextCleanRowState();
}

class _WatchNextCleanRowState extends State<_WatchNextCleanRow> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _focusNodes = [];
  int _focusedIndex = 0;

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
      _focusNodes.add(FocusNode(
        onKeyEvent: (node, event) => _handleKeyEvent(event, i),
      ));
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

  KeyEventResult _handleKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
          if (index < widget.items.length - 1) {
            _focusNodes[index + 1].requestFocus();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (index > 0) {
            _focusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          widget.service.launchItem(widget.items[index]);
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChanged(int index, bool focused) {
    if (focused) {
      _focusedIndex = index;
      _scrollToIndex(index);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    final itemWidth = _kWatchNextItemWidth + _kWatchNextItemSpacing;
    final scrollOffset = (index * itemWidth) - 24;

    _scrollController.animateTo(
      scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kWatchNextItemHeight + 24,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _WatchNextCard(
            item: item,
            watchNextService: widget.service,
            focusNode: _focusNodes[index],
            autofocus: widget.isFirstSection && index == 0,
            onFocusChanged: (focused) => _onFocusChanged(index, focused),
          );
        },
      ),
    );
  }
}

class _WatchNextCard extends StatefulWidget {
  final WatchNextItem item;
  final WatchNextService watchNextService;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<bool> onFocusChanged;

  const _WatchNextCard({
    required this.item,
    required this.watchNextService,
    required this.focusNode,
    this.autofocus = false,
    required this.onFocusChanged,
  });

  @override
  State<_WatchNextCard> createState() => _WatchNextCardState();
}

class _WatchNextCardState extends State<_WatchNextCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isHovered = widget.focusNode.hasFocus);
    widget.onFocusChanged(widget.focusNode.hasFocus);
  }

  void _handleTap() {
    widget.watchNextService.launchItem(widget.item);
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          widget.watchNextService.launchItem(widget.item);
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final posterData = widget.watchNextService.getCachedPoster(widget.item.posterUri);

    return Padding(
      padding: const EdgeInsets.only(right: _kWatchNextItemSpacing),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _handleTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedScale(
            scale: _isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Card(
              elevation: _isHovered ? 8 : 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: _isHovered
                    ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              child: SizedBox(
                width: _kWatchNextItemWidth,
                height: _kWatchNextItemHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPoster(posterData),
                    if (_isHovered) _buildOverlay(),
                    if (_isHovered) _buildProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(Uint8List? posterData) {
    if (posterData != null) {
      return Image.memory(
        posterData,
        fit: BoxFit.cover,
        width: _kWatchNextItemWidth,
        height: _kWatchNextItemHeight,
      );
    }

    return Container(
      color: Colors.grey.shade800,
      child: widget.item.posterUri != null
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
