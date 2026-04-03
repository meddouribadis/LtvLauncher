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

import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../video_wallpapers.dart';

class VideoWallpaperPanelPage extends StatelessWidget {
  static const String routeName = "video_wallpaper_panel";

  @override
  Widget build(BuildContext context) => Consumer<WallpaperService>(
        builder: (context, wallpaperService, _) => Column(
        children: [
          Text("Video wallpapers", style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _loadVideoWallpapers(context),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text("Load from JSON"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: wallpaperService.availableVideoWallpapers.isEmpty
                ? const Center(child: Text("No video wallpapers loaded"))
                : ListView.builder(
                    itemCount: wallpaperService.availableVideoWallpapers.length,
                    itemBuilder: (_, index) => _videoTile(
                      context,
                      wallpaperService.availableVideoWallpapers[index],
                    ),
                  ),
          ),
        ],
      ),
      );

  Widget _videoTile(BuildContext context, VideoWallpaper wallpaper) => ListTile(
        leading: const Icon(Icons.video_library_outlined),
        title: Text(wallpaper.title),
        subtitle: Text(wallpaper.location),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.read<WallpaperService>().setVideoWallpaper(wallpaper.url),
      );

  Future<void> _loadVideoWallpapers(BuildContext context) async {
    try {
      await context.read<WallpaperService>().loadVideoWallpapersFromJson();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video wallpapers loaded")),
      );
    } on VideoWallpaperException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
