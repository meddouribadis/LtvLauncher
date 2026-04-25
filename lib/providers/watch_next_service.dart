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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/watch_next_item.dart';
import 'package:http/http.dart' as http;

class WatchNextService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;

  List<WatchNextItem> _items = [];
  bool _isLoading = false;
  bool _hasPermission = true;
  final Map<String, Uint8List> _posterCache = {};
  final Set<String> _loadingPosters = {};
  final Set<String> _failedPosters = {};
  Timer? _refreshTimer;
  Timer? _posterNotifyDebounce;
  static const int _maxParallelPosterLoads = 2;

  List<WatchNextItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  bool get hasItems => _items.isNotEmpty;

  WatchNextService(this._fLauncherChannel) {
    _init();
  }

  void _init() async {
    await refreshItems();
    // Refresh periodically (every 5 minutes)
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      refreshItems();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _posterNotifyDebounce?.cancel();
    super.dispose();
  }

  Future<void> refreshItems() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final results = await _fLauncherChannel.getWatchNextItems();
      _items = results.map((map) => WatchNextItem.fromMap(map)).toList();
      _hasPermission = true;

      unawaited(_preloadInitialPosters());
    } catch (e) {
      _items = [];
      _hasPermission = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _preloadInitialPosters() async {
    final pendingUris = _items
        .take(3)
        .map((item) => item.posterUri)
        .whereType<String>()
        .where((uri) => !_posterCache.containsKey(uri))
        .toList(growable: false);

    if (pendingUris.isEmpty) {
      return;
    }

    int nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < pendingUris.length) {
        final uri = pendingUris[nextIndex++];
        await _loadPosterImage(uri);
      }
    }

    final workers = List.generate(
      _maxParallelPosterLoads,
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  void ensurePosterLoaded(String? uri) {
    if (uri == null || _posterCache.containsKey(uri) || _failedPosters.contains(uri) || _loadingPosters.contains(uri)) {
      return;
    }
    unawaited(_loadPosterImage(uri));
  }

  Future<void> _loadPosterImage(String uri) async {
    if (_posterCache.containsKey(uri) || _loadingPosters.contains(uri)) {
      return;
    }
    _loadingPosters.add(uri);
    try {
      Uint8List? imageBytes;

      if (uri.startsWith('content://')) {
        imageBytes = await _fLauncherChannel.loadContentUriImage(uri);
      } else {
        final uriObj = Uri.parse(uri);
        final response = await http.get(uriObj).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        _posterCache[uri] = imageBytes;
        _failedPosters.remove(uri);
        _schedulePosterCacheNotification();
      } else {
        _failedPosters.add(uri);
        _schedulePosterCacheNotification();
      }
    } catch (_) {
      _failedPosters.add(uri);
      _schedulePosterCacheNotification();
    } finally {
      _loadingPosters.remove(uri);
    }
  }

  void _schedulePosterCacheNotification() {
    if (_posterNotifyDebounce?.isActive ?? false) {
      return;
    }
    _posterNotifyDebounce = Timer(const Duration(milliseconds: 80), notifyListeners);
  }

  Uint8List? getCachedPoster(String? uri) {
    if (uri == null) return null;
    return _posterCache[uri];
  }

  bool hasPosterLoadFailed(String? uri) {
    if (uri == null) return false;
    return _failedPosters.contains(uri);
  }

  Future<void> launchItem(WatchNextItem item) async {
    debugPrint('WatchNext: Launching item: ${item.title}');
    debugPrint('WatchNext: packageName=${item.packageName}, contentId=${item.contentId}, intentUri=${item.intentUri}');

    if (item.packageName == null && item.intentUri == null) {
      debugPrint('WatchNext: Cannot launch - no package name or intent URI');
      return;
    }

    await _fLauncherChannel.launchWatchNextItem(
      item.packageName,
      item.contentId,
      item.intentUri,
    );
  }
}