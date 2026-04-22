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
  Timer? _refreshTimer;

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

      // Preload poster images in background
      _preloadPosters();
    } catch (e) {
      _items = [];
      _hasPermission = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _preloadPosters() async {
    for (final item in _items) {
      if (item.posterUri != null && !_posterCache.containsKey(item.posterUri)) {
        _loadPosterImage(item.posterUri!);
      }
    }
  }

  Future<void> _loadPosterImage(String uri) async {
    print('WatchNext: Loading poster image from: $uri');
    try {
      Uint8List? imageBytes;

      if (uri.startsWith('content://')) {
        print('WatchNext: Using platform channel for content URI');
        imageBytes = await _fLauncherChannel.loadContentUriImage(uri);
        print('WatchNext: Loaded ${imageBytes.length} bytes from content URI');
      } else {
        print('WatchNext: Using HTTP request for URL: $uri');
        final uriObj = Uri.parse(uri);
        final response = await http.get(uriObj).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
          print('WatchNext: Loaded ${imageBytes.length} bytes from HTTP');
        } else {
          print('WatchNext: HTTP error ${response.statusCode}');
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        _posterCache[uri] = imageBytes;
        print('WatchNext: Image cached successfully');
        notifyListeners();
      } else {
        print('WatchNext: Image bytes empty or null');
      }
    } catch (e) {
      print('WatchNext: Error loading poster image: $e');
    }
  }

  Uint8List? getCachedPoster(String? uri) {
    if (uri == null) return null;
    return _posterCache[uri];
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