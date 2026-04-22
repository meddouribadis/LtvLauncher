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

class WatchNextItem {
  final int id;
  final String title;
  final String? description;
  final String? posterUri;
  final String? backdropUri;
  final String? packageName;
  final String? contentId;
  final int? progressPercent;
  final int? duration;
  final DateTime? lastEngagementDate;
  final String? intentUri;
  final int? watchNextType;
  final String? aspectRatio;

  WatchNextItem({
    required this.id,
    required this.title,
    this.description,
    this.posterUri,
    this.backdropUri,
    this.packageName,
    this.contentId,
    this.progressPercent,
    this.duration,
    this.lastEngagementDate,
    this.intentUri,
    this.watchNextType,
    this.aspectRatio,
  });

  factory WatchNextItem.fromMap(Map<dynamic, dynamic> map) {
    return WatchNextItem(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'],
      posterUri: map['posterUri'],
      backdropUri: map['backdropUri'],
      packageName: map['packageName'],
      contentId: map['contentId'],
      progressPercent: map['progressPercent'],
      duration: map['duration'],
      lastEngagementDate: map['lastEngagementDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastEngagementDate'])
          : null,
      intentUri: map['intentUri'],
      watchNextType: map['watchNextType'],
      aspectRatio: map['aspectRatio'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'posterUri': posterUri,
      'backdropUri': backdropUri,
      'packageName': packageName,
      'contentId': contentId,
      'progressPercent': progressPercent,
      'duration': duration,
      'lastEngagementDate': lastEngagementDate?.millisecondsSinceEpoch,
      'intentUri': intentUri,
      'watchNextType': watchNextType,
      'aspectRatio': aspectRatio,
    };
  }
}
