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

package com.omeda.arc;

import android.content.Context;
import android.content.Intent;
import android.content.pm.*;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Pair;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.io.ByteArrayOutputStream;
import java.io.File;
import android.app.usage.NetworkStats;
import android.app.usage.NetworkStatsManager;
import android.app.AppOpsManager;
import android.os.RemoteException;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

import java.io.ByteArrayOutputStream;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletionService;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorCompletionService;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class MainActivity extends FlutterActivity {
    private final String METHOD_CHANNEL = "me.efesser.flauncher/method";
    private final String APPS_EVENT_CHANNEL = "me.efesser.flauncher/event_apps";
    private final String NETWORK_EVENT_CHANNEL = "me.efesser.flauncher/event_network";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();

        new MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "getApplications" -> result.success(getApplications());
                case "getApplicationBanner" -> result.success(getApplicationBanner(call.arguments()));
                case "getApplicationIcon" -> result.success(getApplicationIcon(call.arguments()));
                case "applicationExists" -> result.success(applicationExists(call.arguments()));
                case "launchActivityFromAction" -> result.success(launchActivityFromAction(call.arguments()));
                case "launchApp" -> result.success(launchApp(call.arguments()));
                case "openSettings" -> result.success(openSettings());
                case "installApk" -> result.success(installApk(call.arguments()));
                case "requestInstallUnknownAppsPermission" -> {
                    requestInstallUnknownAppsPermission();
                    result.success(null);
                }
                case "openScreensaverSettings" -> result.success(openScreensaverSettings());
                case "openAppInfo" -> result.success(openAppInfo(call.arguments()));
                case "uninstallApp" -> result.success(uninstallApp(call.arguments()));
                case "isDefaultLauncher" -> result.success(isDefaultLauncher());
                case "checkForGetContentAvailability" -> result.success(checkForGetContentAvailability());
                case "startAmbientMode" -> result.success(startAmbientMode());
                case "getActiveNetworkInformation" -> result.success(getActiveNetworkInformation());
                case "getDailyWifiUsage" -> {
                    long usage = getDailyWifiUsage();
                    if (usage == -1) {
                        result.error("PERMISSION_DENIED", "Usage stats permission not granted", null);
                    } else {
                        result.success(usage);
                    }
                }
                case "getWeeklyWifiUsage" -> {
                    long usage = getWeeklyWifiUsage();
                    if (usage == -1) {
                        result.error("PERMISSION_DENIED", "Usage stats permission not granted", null);
                    } else {
                        result.success(usage);
                    }
                }
                case "getMonthlyWifiUsage" -> {
                    long usage = getMonthlyWifiUsage();
                    if (usage == -1) {
                        result.error("PERMISSION_DENIED", "Usage stats permission not granted", null);
                    } else {
                        result.success(usage);
                    }
                }
                case "checkUsageStatsPermission" -> result.success(checkUsageStatsPermission());
                case "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission();
                    result.success(null);
                }
                case "checkWriteSettingsPermission" -> result.success(checkWriteSettingsPermission());
                case "requestWriteSettingsPermission" -> {
                    requestWriteSettingsPermission();
                    result.success(null);
                }
                case "setSystemBrightness" -> {
                    int brightness = call.argument("brightness");
                    result.success(setSystemBrightness(brightness));
                }
                case "openWifiSettings" -> result.success(openWifiSettings());
                default -> throw new IllegalArgumentException();
            }
        });

        new EventChannel(messenger, APPS_EVENT_CHANNEL).setStreamHandler(
                new LauncherAppsEventStreamHandler(this));

        new EventChannel(messenger, NETWORK_EVENT_CHANNEL).setStreamHandler(
                new NetworkEventStreamHandler(this));
    }

    private List<Map<String, Serializable>> getApplications() {
        ExecutorService executor = Executors.newFixedThreadPool(4);
        CompletionService<Pair<Boolean, List<ResolveInfo>>> queryIntentActivitiesCompletionService = new ExecutorCompletionService<>(
                executor);
        queryIntentActivitiesCompletionService.submit(() -> Pair.create(false, queryIntentActivities(false)));
        queryIntentActivitiesCompletionService.submit(() -> Pair.create(true, queryIntentActivities(true)));
        List<ResolveInfo> tvActivitiesInfo = null;
        List<ResolveInfo> nonTvActivitiesInfo = null;

        int completed = 0;
        while (completed < 2) {
            try {
                var activitiesInfo = queryIntentActivitiesCompletionService.take().get();

                if (!activitiesInfo.first) {
                    tvActivitiesInfo = activitiesInfo.second;
                } else {
                    nonTvActivitiesInfo = activitiesInfo.second;
                }
            } catch (InterruptedException | ExecutionException ignored) {
            } finally {
                completed += 1;
            }
        }

        CompletionService<Map<String, Serializable>> completionService = new ExecutorCompletionService<>(executor);

        List<Map<String, Serializable>> applications = new ArrayList<>(
                tvActivitiesInfo.size() + nonTvActivitiesInfo.size());

        boolean settingsPresent = false;
        int appCount = 0;
        for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
            if (!settingsPresent) {
                settingsPresent = tvActivityInfo.activityInfo.packageName.equals("com.android.tv.settings");
            }

            completionService.submit(() -> buildAppMap(tvActivityInfo.activityInfo, false, null));
            appCount += 1;
        }

        for (ResolveInfo nonTvActivityInfo : nonTvActivitiesInfo) {
            boolean nonDuplicate = true;

            if (!settingsPresent) {
                settingsPresent = nonTvActivityInfo.activityInfo.packageName.equals("com.android.settings");
            }

            for (ResolveInfo tvActivityInfo : tvActivitiesInfo) {
                if (tvActivityInfo.activityInfo.packageName.equals(nonTvActivityInfo.activityInfo.packageName)) {
                    nonDuplicate = false;
                    break;
                }
            }

            if (nonDuplicate) {
                appCount += 1;
                completionService.submit(() -> buildAppMap(nonTvActivityInfo.activityInfo, true, null));
            }
        }

        while (appCount > 0) {
            try {
                Future<Map<String, Serializable>> appMap = completionService.take();
                applications.add(appMap.get());
            } catch (InterruptedException | ExecutionException ignored) {
            } finally {
                appCount -= 1;
            }
        }

        executor.shutdown();

        if (!settingsPresent) {
            PackageManager packageManager = getPackageManager();
            Intent settingsIntent = new Intent(Settings.ACTION_SETTINGS);
            ActivityInfo activityInfo = settingsIntent.resolveActivityInfo(packageManager, 0);

            if (activityInfo != null) {
                applications.add(buildAppMap(activityInfo, false, Settings.ACTION_SETTINGS));
            }
        }

        return applications;
    }

    public Map<String, Serializable> getApplication(String packageName) {
        Map<String, Serializable> map = Map.of();
        PackageManager packageManager = getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);

        if (intent == null) {
            intent = packageManager.getLaunchIntentForPackage(packageName);
        }

        if (intent != null) {
            ActivityInfo activityInfo = intent.resolveActivityInfo(getPackageManager(), 0);

            if (activityInfo != null) {
                map = buildAppMap(activityInfo, false, null);
            }
        }

        return map;
    }

    private byte[] getApplicationBanner(String packageName) {
        byte[] imageBytes = new byte[0];

        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadBanner(packageManager);

            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable);
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        return imageBytes;
    }

    private byte[] getApplicationIcon(String packageName) {
        byte[] imageBytes = new byte[0];

        PackageManager packageManager = getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            Drawable drawable = info.loadIcon(packageManager);

            if (drawable != null) {
                imageBytes = drawableToByteArray(drawable);
            }
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        return imageBytes;
    }

    private boolean applicationExists(String packageName) {
        int flags;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            flags = PackageManager.MATCH_UNINSTALLED_PACKAGES;
        } else {
            flags = PackageManager.GET_UNINSTALLED_PACKAGES;
        }

        try {
            getPackageManager().getApplicationInfo(packageName, flags);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }

    private List<ResolveInfo> queryIntentActivities(boolean sideloaded) {
        String category;
        if (sideloaded) {
            category = Intent.CATEGORY_LAUNCHER;
        } else {
            category = Intent.CATEGORY_LEANBACK_LAUNCHER;
        }

        // NOTE: Would be nice to query the applications that match *either* of the
        // above categories
        // but from the addCategory function documentation, it says that it will "use
        // activities
        // that provide *all* the requested categories"
        Intent intent = new Intent(Intent.ACTION_MAIN)
                .addCategory(category);

        return getPackageManager()
                .queryIntentActivities(intent, 0);
    }

    private Map<String, Serializable> buildAppMap(ActivityInfo activityInfo, boolean sideloaded, String action) {
        PackageManager packageManager = getPackageManager();

        String applicationName = activityInfo.loadLabel(packageManager).toString(),
                applicationVersionName = "";
        try {
            applicationVersionName = packageManager.getPackageInfo(activityInfo.packageName, 0).versionName;
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        Map<String, Serializable> appMap = new HashMap<>();
        appMap.put("name", applicationName);
        appMap.put("packageName", activityInfo.packageName);
        appMap.put("version", applicationVersionName);
        appMap.put("sideloaded", sideloaded);

        if (action != null) {
            appMap.put("action", action);
        }
        return appMap;
    }

    private boolean launchActivityFromAction(String action) {
        return tryStartActivity(new Intent(action));
    }

    private boolean launchApp(String packageName) {
        PackageManager packageManager = getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);

        if (intent == null) {
            intent = packageManager.getLaunchIntentForPackage(packageName);
        }

        return tryStartActivity(intent);
    }

    private boolean openSettings() {
        return launchActivityFromAction(Settings.ACTION_SETTINGS);
    }

    private boolean installApk(String apkPath) {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !getPackageManager().canRequestPackageInstalls()) {
            return false;
        }

        Uri apkUri = FileProvider.getUriForFile(
                this,
                getPackageName() + ".fileprovider",
                apkFile
        );

        Intent installIntent = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(apkUri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

        return tryStartActivity(installIntent);
    }

    private void requestInstallUnknownAppsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:" + getPackageName()));
            tryStartActivity(intent);
        }
    }

    private boolean openAppInfo(String packageName) {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null));

        return tryStartActivity(intent);
    }

    private boolean uninstallApp(String packageName) {
        Intent intent = new Intent(Intent.ACTION_DELETE)
                .setData(Uri.fromParts("package", packageName, null));

        return tryStartActivity(intent);
    }

    private boolean checkForGetContentAvailability() {
        List<ResolveInfo> intentActivities = getPackageManager().queryIntentActivities(
                new Intent(Intent.ACTION_GET_CONTENT, null).setTypeAndNormalize("image/*"),
                0);

        return !intentActivities.isEmpty();
    }

    private boolean isDefaultLauncher() {
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        ResolveInfo defaultLauncher = getPackageManager().resolveActivity(intent, 0);

        if (defaultLauncher != null && defaultLauncher.activityInfo != null) {
            return defaultLauncher.activityInfo.packageName.equals(getPackageName());
        }

        return false;
    }

    private boolean startAmbientMode() {
        Intent intent = new Intent(Intent.ACTION_MAIN)
                .setClassName("com.android.systemui", "com.android.systemui.Somnambulator");

        return tryStartActivity(intent);
    }

    private Map<String, Object> getActiveNetworkInformation() {
        ConnectivityManager connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetwork());
        } else {
            // noinspection deprecation
            return NetworkUtils.getNetworkInformation(this, connectivityManager.getActiveNetworkInfo());
        }
    }

    private boolean tryStartActivity(Intent intent) {
        boolean success = true;

        try {
            startActivity(intent);
        } catch (Exception ignored) {
            success = false;
        }

        return success;
    }

    private byte[] drawableToByteArray(Drawable drawable) {
        if (drawable.getIntrinsicWidth() <= 0 || drawable.getIntrinsicHeight() <= 0) {
            return new byte[0];
        }

        Bitmap bitmap;
        if (drawable instanceof BitmapDrawable bitmapDrawable) {
            bitmap = bitmapDrawable.getBitmap();
        } else {
            bitmap = drawableToBitmap(drawable);
        }
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
        return stream.toByteArray();
    }

    Bitmap drawableToBitmap(Drawable drawable) {
        Bitmap bitmap = Bitmap.createBitmap(
                drawable.getIntrinsicWidth(),
                drawable.getIntrinsicHeight(),
                Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }

    private long getDailyWifiUsage() {
        if (!checkUsageStatsPermission()) {
            return -1;
        }

        NetworkStatsManager networkStatsManager = (NetworkStatsManager) getSystemService(Context.NETWORK_STATS_SERVICE);
        if (networkStatsManager == null)
            return 0;

        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0);
        calendar.set(java.util.Calendar.MINUTE, 0);
        calendar.set(java.util.Calendar.SECOND, 0);
        calendar.set(java.util.Calendar.MILLISECOND, 0);
        long startTime = calendar.getTimeInMillis();
        long endTime = System.currentTimeMillis();

        long totalBytes = 0;
        try {
            NetworkStats.Bucket bucket = networkStatsManager.querySummaryForDevice(
                    NetworkCapabilities.TRANSPORT_WIFI,
                    "",
                    startTime,
                    endTime);
            totalBytes = bucket.getRxBytes() + bucket.getTxBytes();
        } catch (RemoteException e) {
            e.printStackTrace();
        }

        return totalBytes;
    }

    private long getWeeklyWifiUsage() {
        if (!checkUsageStatsPermission()) {
            return -1;
        }

        NetworkStatsManager networkStatsManager = (NetworkStatsManager) getSystemService(Context.NETWORK_STATS_SERVICE);
        if (networkStatsManager == null)
            return 0;

        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.DAY_OF_WEEK, calendar.getFirstDayOfWeek());
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0);
        calendar.set(java.util.Calendar.MINUTE, 0);
        calendar.set(java.util.Calendar.SECOND, 0);
        calendar.set(java.util.Calendar.MILLISECOND, 0);
        long startTime = calendar.getTimeInMillis();
        long endTime = System.currentTimeMillis();

        long totalBytes = 0;
        try {
            NetworkStats.Bucket bucket = networkStatsManager.querySummaryForDevice(
                    NetworkCapabilities.TRANSPORT_WIFI,
                    "",
                    startTime,
                    endTime);
            totalBytes = bucket.getRxBytes() + bucket.getTxBytes();
        } catch (RemoteException e) {
            e.printStackTrace();
        }

        return totalBytes;
    }

    private long getMonthlyWifiUsage() {
        if (!checkUsageStatsPermission()) {
            return -1;
        }

        NetworkStatsManager networkStatsManager = (NetworkStatsManager) getSystemService(Context.NETWORK_STATS_SERVICE);
        if (networkStatsManager == null)
            return 0;

        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.DAY_OF_MONTH, 1);
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0);
        calendar.set(java.util.Calendar.MINUTE, 0);
        calendar.set(java.util.Calendar.SECOND, 0);
        calendar.set(java.util.Calendar.MILLISECOND, 0);
        long startTime = calendar.getTimeInMillis();
        long endTime = System.currentTimeMillis();

        long totalBytes = 0;
        try {
            NetworkStats.Bucket bucket = networkStatsManager.querySummaryForDevice(
                    NetworkCapabilities.TRANSPORT_WIFI,
                    "",
                    startTime,
                    endTime);
            totalBytes = bucket.getRxBytes() + bucket.getTxBytes();
        } catch (RemoteException e) {
            e.printStackTrace();
        }

        return totalBytes;
    }

    private boolean checkUsageStatsPermission() {
        AppOpsManager appOps = (AppOpsManager) getSystemService(Context.APP_OPS_SERVICE);
        int mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(), getPackageName());
        return mode == AppOpsManager.MODE_ALLOWED;
    }

    private void requestUsageStatsPermission() {
        Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
        tryStartActivity(intent);
    }

    private boolean checkWriteSettingsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return Settings.System.canWrite(this);
        }
        return true;
    }

    private void requestWriteSettingsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            tryStartActivity(intent);
        }
    }

    private boolean setSystemBrightness(int brightness) {
        if (checkWriteSettingsPermission()) {
            try {
                android.content.ContentResolver resolver = getContentResolver();
                // 1. Standard Android brightness
                Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, brightness);
                
                // 2. Try common TV "Backlight" keys (Vendor specific)
                Settings.System.putInt(resolver, "backlight", brightness);
                Settings.System.putInt(resolver, "backlight_level", brightness);
                
                return true;
            } catch (Exception e) {
                // Ignore errors on specific keys as they may not exist
                return true; 
            }
        }
        return false;
    }

    private boolean openWifiSettings() {
        // 1. Try Android Q+ WiFi panel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent panelIntent = new Intent(Settings.Panel.ACTION_WIFI);
            if (tryStartActivity(panelIntent)) {
                return true;
            }
        }

        // 2. Try standard WiFi settings
        Intent wifiIntent = new Intent(Settings.ACTION_WIFI_SETTINGS);
        if (tryStartActivity(wifiIntent)) {
            return true;
        }

        // 3. Fallback to general wireless settings
        Intent wirelessIntent = new Intent(Settings.ACTION_WIRELESS_SETTINGS);
        if (tryStartActivity(wirelessIntent)) {
            return true;
        }

        // 4. Final fallback - open main settings
        return launchActivityFromAction(Settings.ACTION_SETTINGS);
    }

    private boolean openScreensaverSettings() {
        // 1. Try Android TV specific screensaver settings (DaydreamActivity - from
        // Aerial Views)
        Intent tvIntent = new Intent(Intent.ACTION_MAIN);
        tvIntent.setClassName("com.android.tv.settings",
                "com.android.tv.settings.device.display.daydream.DaydreamActivity");
        if (tryStartActivity(tvIntent)) {
            return true;
        }

        // 2. Try standard Android screensaver/dream settings
        Intent dreamIntent = new Intent(Settings.ACTION_DREAM_SETTINGS);
        if (tryStartActivity(dreamIntent)) {
            return true;
        }

        // 3. FALLBACK: Try Display Settings (often contains screensaver on newer
        // Android TV/Google TV)
        Intent displayIntent = new Intent(Settings.ACTION_DISPLAY_SETTINGS);
        if (tryStartActivity(displayIntent)) {
            return true;
        }

        // 4. Final fallback - open main settings
        return launchActivityFromAction(Settings.ACTION_SETTINGS);
    }

}
