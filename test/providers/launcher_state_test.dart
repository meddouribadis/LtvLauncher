import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  group('LauncherState handleBackNavigation', () {
    late MockAppsService mockAppsService;
    late MockSettingsService mockSettingsService;
    late LauncherState launcherState;

    setUp(() {
      mockAppsService = MockAppsService();
      mockSettingsService = MockSettingsService();
      launcherState = LauncherState();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: mockAppsService),
          ChangeNotifierProvider<SettingsService>.value(value: mockSettingsService),
          ChangeNotifierProvider<LauncherState>.value(value: launcherState),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              return GestureDetector(
                onTap: () {
                  launcherState.handleBackNavigation(context);
                },
                child: const Text('Tap Me'),
              );
            },
          ),
        ),
      );
    }

    testWidgets('handleBackNavigation opens clock when action is BACK_BUTTON_ACTION_CLOCK', (WidgetTester tester) async {
      when(mockSettingsService.backButtonAction).thenReturn(BACK_BUTTON_ACTION_CLOCK);
      when(mockAppsService.isDefaultLauncher()).thenAnswer((_) async => true);

      // Force refresh to apply isDefaultLauncher locally if not kDebugMode
      await launcherState.refresh(mockAppsService);

      expect(launcherState.launcherVisible, isTrue);

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(launcherState.launcherVisible, isFalse);
    });

    testWidgets('handleBackNavigation starts screensaver when action is BACK_BUTTON_ACTION_SCREENSAVER', (WidgetTester tester) async {
      when(mockSettingsService.backButtonAction).thenReturn(BACK_BUTTON_ACTION_SCREENSAVER);
      when(mockAppsService.isDefaultLauncher()).thenAnswer((_) async => true);
      when(mockAppsService.startAmbientMode()).thenAnswer((_) async {});

      // Force refresh
      await launcherState.refresh(mockAppsService);

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      verify(mockAppsService.startAmbientMode()).called(1);
    });

    testWidgets('handleBackNavigation does nothing when action is BACK_BUTTON_ACTION_NOTHING', (WidgetTester tester) async {
      when(mockSettingsService.backButtonAction).thenReturn(BACK_BUTTON_ACTION_NOTHING);
      when(mockAppsService.isDefaultLauncher()).thenAnswer((_) async => true);

      // Force refresh
      await launcherState.refresh(mockAppsService);

      expect(launcherState.launcherVisible, isTrue);

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(launcherState.launcherVisible, isTrue);
      verifyNever(mockAppsService.startAmbientMode());
    });
  });
}
