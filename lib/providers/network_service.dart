/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';

enum NetworkType
{
  Cellular,
  Wifi,
  Vpn,
  Wired,
  Unknown
}

// https://developer.android.com/reference/android/telephony/TelephonyManager#NETWORK_TYPE_CDMA
enum CellularNetworkType
{
  Unknown,  // 0
  Gprs,     // 1
  Edge,     // 2
  Umts,     // 3
  Cdma,     // 4
  EvdoZero, // 5
  EvdoA,    // 6
  Unused_1, // 7
  Hsdpa,    // 8
  Hsupa,    // 9
  Hspa,     // 10
  Iden,     // 11
  EvdoB,    // 12
  Lte,      // 13
  Ehrpd,    // 14
  Hspap,    // 15
  Gsm,      // 16
  TdScdma,  // 17
  Iwlan,    // 18
  Unused_2, // 19
  Nr,       // 20
}

class NetworkService extends ChangeNotifier
{
  final FLauncherChannel  _channel;

  bool                _hasInternetAccess;
  CellularNetworkType _cellularNetworkType;
  NetworkType         _networkType;
  int                 _wirelessNetworkSignalLevel;
  int                 _dailyDataUsage; // In bytes
  bool                _hasUsageStatsPermission;
  Timer?              _usageTimer;


  NetworkService(this._channel) :
        _hasInternetAccess = false,
        _cellularNetworkType = CellularNetworkType.Unknown,
        _networkType = NetworkType.Unknown,
        _wirelessNetworkSignalLevel = 0,
        _dailyDataUsage = 0,
        _hasUsageStatsPermission = false
  {
    _channel.addNetworkChangedListener(_onNetworkChanged);

    _channel
        .getActiveNetworkInformation()
        .then((map) {
          if (map.isNotEmpty) {
            _getNetworkInformation(map);
          }
        });

    _checkPermissionAndStartPolling();
  }

  void _checkPermissionAndStartPolling() async {
    _hasUsageStatsPermission = await _channel.checkUsageStatsPermission();
    if (_hasUsageStatsPermission) {
      _fetchUsage();
      _usageTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchUsage());
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    await _channel.requestUsageStatsPermission();
    // Wait a bit for user to return, or just rely on Lifecycle, but here we can't easily hook into lifecycle.
    // We can assume if they clicked it, they might come back.
    // Ideally we recheck when app resumes. For now let's just recheck after a delay or expose a method to recheck.
  }

  // Call this when app resumes
  Future<void> refreshPermissionAndUsage() async {
    _hasUsageStatsPermission = await _channel.checkUsageStatsPermission();
    if (_hasUsageStatsPermission) {
      _fetchUsage();
      if (_usageTimer == null || !_usageTimer!.isActive) {
         _usageTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchUsage());
      }
    } else {
      _usageTimer?.cancel();
    }
    notifyListeners();
  }

  Future<void> openWifiSettings() async {
    await _channel.openWifiSettings();
  }

  Future<void> _fetchUsage() async {
     // This will be called with the current period from the widget
     // For now, default to daily
     int usage = await _channel.getDailyDataUsage();
     if (usage != -1) {
       _dailyDataUsage = usage;
       notifyListeners();
     }
  }

  Future<int> getDataUsageForPeriod(String period) async {
    switch (period) {
      case 'daily':
        return await _channel.getDailyDataUsage();
      case 'weekly':
        return await _channel.getWeeklyDataUsage();
      case 'monthly':
        return await _channel.getMonthlyDataUsage();
      default:
        return await _channel.getDailyDataUsage();
    }
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    super.dispose();
  }

  bool                  get   hasInternetAccess             => _hasInternetAccess;
  CellularNetworkType   get   cellularNetworkType           => _cellularNetworkType;
  NetworkType           get   networkType                   => _networkType;
  int                   get   wirelessNetworkSignalLevel    => _wirelessNetworkSignalLevel;
  int                 get   dailyDataUsage                => _dailyDataUsage;
  bool                get   hasUsageStatsPermission       => _hasUsageStatsPermission;

  CellularNetworkType _getCellularNetworkType(int index)
  {
    CellularNetworkType type = CellularNetworkType.values[index];
    if (type == CellularNetworkType.Unused_1 || type == CellularNetworkType.Unused_2) {
      type = CellularNetworkType.Unknown;
    }

    return type;
  }

  void _getNetworkInformation(Map<String, dynamic> map)
  {
    int networkTypeInt = map["networkType"];
    _hasInternetAccess = map["internetAccess"];
    _networkType = NetworkType.values[networkTypeInt];

    if (_networkType == NetworkType.Cellular || _networkType == NetworkType.Wifi) {
      _wirelessNetworkSignalLevel = map["wirelessSignalLevel"];
    }
  }

  void _onNetworkChanged(Map<String, dynamic> event)
  {
    switch (event["name"]) {
      case "NETWORK_AVAILABLE":
        Map<dynamic, dynamic> map = event["arguments"];
        _getNetworkInformation(map.cast<String, dynamic>());
        break;
      case "NETWORK_UNAVAILABLE":
        _hasInternetAccess = false;
        _networkType = NetworkType.Unknown;
        break;
      case "CAPABILITIES_CHANGED":
        Map<dynamic, dynamic> map = event["arguments"];
        _getNetworkInformation(map.cast<String, dynamic>());
        break;
      case "CELLULAR_STATE_CHANGED":
        _cellularNetworkType = _getCellularNetworkType(event["arguments"]);
        notifyListeners();
        break;
    }

    notifyListeners();
  }
}