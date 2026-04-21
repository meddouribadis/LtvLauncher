import 'package:flauncher/providers/network_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';
import 'dart:async';

import '../mocks.mocks.dart';

void main() {
  late MockFLauncherChannel mockChannel;
  late NetworkService networkService;

  setUp(() {
    mockChannel = MockFLauncherChannel();
    when(mockChannel.getActiveNetworkInformation())
        .thenAnswer((_) async => <String, dynamic>{});
    when(mockChannel.checkUsageStatsPermission())
        .thenAnswer((_) async => false);
    when(mockChannel.addNetworkChangedListener(any)).thenReturn(null);
    networkService = NetworkService(mockChannel);
  });

  tearDown(() {
    networkService.dispose();
  });

  group('getWifiUsageForPeriod', () {
    test('returns daily usage when period is "daily"', () async {
      when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 100);

      final result = await networkService.getWifiUsageForPeriod('daily');

      expect(result, 100);
      verify(mockChannel.getDailyWifiUsage()).called(1);
      verifyNever(mockChannel.getWeeklyWifiUsage());
      verifyNever(mockChannel.getMonthlyWifiUsage());
    });

    test('returns weekly usage when period is "weekly"', () async {
      when(mockChannel.getWeeklyWifiUsage()).thenAnswer((_) async => 500);

      final result = await networkService.getWifiUsageForPeriod('weekly');

      expect(result, 500);
      verify(mockChannel.getWeeklyWifiUsage()).called(1);
      verifyNever(mockChannel.getDailyWifiUsage());
      verifyNever(mockChannel.getMonthlyWifiUsage());
    });

    test('returns monthly usage when period is "monthly"', () async {
      when(mockChannel.getMonthlyWifiUsage()).thenAnswer((_) async => 2000);

      final result = await networkService.getWifiUsageForPeriod('monthly');

      expect(result, 2000);
      verify(mockChannel.getMonthlyWifiUsage()).called(1);
      verifyNever(mockChannel.getDailyWifiUsage());
      verifyNever(mockChannel.getWeeklyWifiUsage());
    });

    test('returns daily usage when period is unknown', () async {
      when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 100);

      final result = await networkService.getWifiUsageForPeriod('unknown_period');

      expect(result, 100);
      verify(mockChannel.getDailyWifiUsage()).called(1);
      verifyNever(mockChannel.getWeeklyWifiUsage());
      verifyNever(mockChannel.getMonthlyWifiUsage());
    });
  });

  group('refreshPermissionAndUsage', () {
    test('when permission granted, fetches usage and notifies listeners periodically', () {
      fakeAsync((async) {
        when(mockChannel.checkUsageStatsPermission()).thenAnswer((_) async => true);
        when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 100);

        int listenerCallCount = 0;
        networkService.addListener(() {
          listenerCallCount++;
        });

        // initial call starts timer
        networkService.refreshPermissionAndUsage();

        async.flushMicrotasks();

        expect(networkService.hasUsageStatsPermission, isTrue);
        expect(networkService.dailyWifiUsage, 100);
        expect(listenerCallCount, greaterThanOrEqualTo(2));
        verify(mockChannel.getDailyWifiUsage()).called(1);

        // advance 5 minutes
        async.elapse(const Duration(minutes: 5));

        // Timer should have fired, calling _fetchUsage again
        verify(mockChannel.getDailyWifiUsage()).called(1);
      });
    });

    test('when permission denied, cancels timer and notifies listeners', () {
      fakeAsync((async) {
        // First, simulate permission granted to start timer
        when(mockChannel.checkUsageStatsPermission()).thenAnswer((_) async => true);
        when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 100);
        networkService.refreshPermissionAndUsage();
        async.flushMicrotasks();
        expect(networkService.hasUsageStatsPermission, isTrue);

        // Advance 5 minutes to verify timer is active
        async.elapse(const Duration(minutes: 5));
        verify(mockChannel.getDailyWifiUsage()).called(2);

        // Now deny it
        when(mockChannel.checkUsageStatsPermission()).thenAnswer((_) async => false);

        int listenerCallCount = 0;
        networkService.addListener(() {
          listenerCallCount++;
        });

        networkService.refreshPermissionAndUsage();
        async.flushMicrotasks();

        expect(networkService.hasUsageStatsPermission, isFalse);
        expect(listenerCallCount, 1);

        // Advance 5 minutes, timer should NOT fire anymore
        async.elapse(const Duration(minutes: 5));

        // Shouldn't have any more calls to getDailyWifiUsage since timer was cancelled
        verifyNever(mockChannel.getDailyWifiUsage());
      });
    });

    test('when permission granted and timer is already active, does not start a new timer but fetches usage', () {
      fakeAsync((async) {
        when(mockChannel.checkUsageStatsPermission()).thenAnswer((_) async => true);
        when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 100);

        // First call starts the timer
        networkService.refreshPermissionAndUsage();
        async.flushMicrotasks();

        // Advance 4 minutes, timer hasn't fired yet
        async.elapse(const Duration(minutes: 4));

        when(mockChannel.getDailyWifiUsage()).thenAnswer((_) async => 200);

        // Second call should fetch usage but reuse the timer
        networkService.refreshPermissionAndUsage();
        async.flushMicrotasks();

        expect(networkService.dailyWifiUsage, 200);
        verify(mockChannel.getDailyWifiUsage()).called(2);

        // Advance another 1 minute (total 5 mins since first call)
        // If a new timer was started, it would fire 5 mins from the second call.
        // If the old timer was kept, it should fire now.
        async.elapse(const Duration(minutes: 1));

        // Timer fired!
        verify(mockChannel.getDailyWifiUsage()).called(1);
      });
    });
  });
}
