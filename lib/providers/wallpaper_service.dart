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

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../video_wallpapers.dart';

class WallpaperService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final SettingsService _settingsService;

  late File _wallpaperFile;
  late File _wallpaperDayFile;
  late File _wallpaperNightFile;
  File? _videoWallpaperFile;
  Timer? _timer;

  ImageProvider? _wallpaper;
  List<VideoWallpaper> _availableVideoWallpapers = <VideoWallpaper>[];

  ImageProvider?  get wallpaper     => _wallpaper;
  File? get videoWallpaper => _videoWallpaperFile;
  List<VideoWallpaper> get availableVideoWallpapers => List.unmodifiable(_availableVideoWallpapers);

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.pitchBlack,
      );

  WallpaperService(this._fLauncherChannel, this._settingsService) :
    _wallpaper = null
  {
    _settingsService.addListener(_onSettingsChanged);
    _init();
  }

  bool _lastTimeBasedEnabled = false;

  void _onSettingsChanged() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    if (enabled != _lastTimeBasedEnabled) {
      _lastTimeBasedEnabled = enabled;
      _updateTimerState();
    }

    _updateWallpaper();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    _wallpaperDayFile = File("${directory.path}/wallpaper_day");
    _wallpaperNightFile = File("${directory.path}/wallpaper_night");
    _videoWallpaperFile = File("${directory.path}/video_wallpaper");

    _lastTimeBasedEnabled = _settingsService.timeBasedWallpaperEnabled;
    _updateWallpaper();
    _updateTimerState();
  }

  void _updateTimerState() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled && (_timer == null || !_timer!.isActive)) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateWallpaper());
    } else if (!enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _updateWallpaper({bool force = false}) {
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    final isVideoWallpaperEnabled = _settingsService.videoWallpaperEnabled;

    ImageProvider? newWallpaper;

    if (enabled) {
      if (isDay && _wallpaperDayFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperDayFile);
      } else if (!isDay && _wallpaperNightFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperNightFile);
      } else if (_wallpaperFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperFile); // Fallback
      }
    } else {
      if (_wallpaperFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperFile);
      }
    }

    if (_wallpaper != newWallpaper || force) {
      _wallpaper = newWallpaper;
      notifyListeners();
    }
  }

  Future<void> pickWallpaper() async {
    await _pickAndSave(_wallpaperFile);
  }

  Future<void> pickWallpaperDay() async {
    await _pickAndSave(_wallpaperDayFile);
  }

  Future<void> pickWallpaperNight() async {
    await _pickAndSave(_wallpaperNightFile);
  }

  Future<void> _pickAndSave(File targetFile) async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Use stream for memory efficiency
      final readStream = pickedFile.openRead();
      final writeStream = targetFile.openWrite();
      await readStream.cast<List<int>>().pipe(writeStream);

      // Evict from cache to ensure UI updates
      await FileImage(targetFile).evict();

      _updateWallpaper(force: true);
    }
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }

    _settingsService.setGradientUuid(fLauncherGradient.uuid);
    notifyListeners();
  }

  Future<void> loadVideoWallpapersFromJson({
    String sourceUrl = "https://raw.githubusercontent.com/spocky/projectivy-plugin-wallpaper-overflight/refs/heads/main/videos.json",
  }) async {
    final request = await HttpClient().getUrl(Uri.parse(sourceUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw VideoWallpaperException("Failed to fetch JSON: HTTP ${response.statusCode}");
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final dynamic decoded = jsonDecode(responseBody);
    if (decoded is! List) {
      throw VideoWallpaperException("Invalid JSON format: expected a list");
    }

    final wallpapers = <VideoWallpaper>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final location = item["location"] as String? ?? "Unknown";
      final title = item["title"] as String? ?? "Untitled";
      final rawUrl = item["url_1080p"] as String?;
      if (rawUrl == null || rawUrl.isEmpty) {
        continue;
      }

      final normalizedUrl = rawUrl.startsWith("http://")
          ? rawUrl.replaceFirst("http://", "https://")
          : rawUrl;
      wallpapers.add(VideoWallpaper(location: location, title: title, url: normalizedUrl));
    }

    if (wallpapers.isEmpty) {
      throw VideoWallpaperException("No playable video URLs were found in JSON");
    }

    _availableVideoWallpapers = wallpapers;
    notifyListeners();
  }

  Future<File> downloadVideoFromUrl({
    required String videoUrl,
    String? fileName,
  }) async {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      throw VideoWallpaperException("Invalid video URL");
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final videosDirectory = Directory("${appDirectory.path}/video_wallpapers");
    if (!await videosDirectory.exists()) {
      await videosDirectory.create(recursive: true);
    }

    final inferredName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : "video_wallpaper.mov";
    final resolvedFileName = _sanitizeFileName(fileName ?? inferredName);
    final targetFile = File("${videosDirectory.path}/$resolvedFileName");

    try {
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw VideoWallpaperException("Failed to download video: HTTP ${response.statusCode}");
      }

      final sink = targetFile.openWrite();
      await response.pipe(sink);
      return targetFile;
    } catch (_) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      rethrow;
    }
  }

  String _sanitizeFileName(String value) {
    const fallback = "video_wallpaper.mov";
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
        .replaceAll(" ", "_");
    if (sanitized.isEmpty) {
      return fallback;
    }
    return sanitized;
  }

  Future<void> setVideoWallpaper(String url) async {
    if (url.isEmpty) {
      throw VideoWallpaperException("Video URL cannot be empty");
    }

    await downloadVideoFromUrl(videoUrl: url, fileName: 'video_wallpaper');
    await _settingsService.setVideoWallpaperEnabled(true);

    notifyListeners();
  }

  Future<void> clearVideoWallpaper() async {
    await _settingsService.setVideoWallpaperEnabled(false);

    notifyListeners();
  }
}

class NoFileExplorerException implements Exception {}
