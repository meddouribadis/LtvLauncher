import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  testWidgets("Left/Right arrow keys switch categories in ApplicationsPanelPage", (tester) async {
    final appsService = MockAppsService();
    // Setup some fake apps to populate tabs
    when(appsService.applications).thenReturn([
      fakeApp(packageName: "pkg.tv", name: "TV App", sideloaded: false, hidden: false),
      fakeApp(packageName: "pkg.sideload", name: "Sideload App", sideloaded: true, hidden: false),
    ]);
    // Mock category for favorites (even if empty)
    when(appsService.categories).thenReturn([]); 

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: appsService),
        ],
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ApplicationsPanelPage()),
          onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => Container()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state: TV Applications (index 0)
    expect(find.text("TV Apps"), findsOneWidget, reason: "Should start on TV Apps tab");

    // Focus on the list (assuming list item is focusable, or we can just send keys if focus is set)
    // To be safe, we'll try to focus the first list item.
    // The list items are _AppListItem which contain Focus/InkWell.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    
    // Simulate Right Arrow
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Should now be on Non-TV Applications (index 1)
    expect(find.text("Non-TV Apps"), findsOneWidget, reason: "Should switch to Non-TV Apps after Right Arrow");
    expect(find.text("Sideload App"), findsOneWidget);

    // Simulate Left Arrow
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    // Should be back on TV Applications (index 0)
    expect(find.text("TV Apps"), findsOneWidget, reason: "Should switch back to TV Apps after Left Arrow");
    expect(find.text("TV App"), findsOneWidget);

    // Check boundary (Left on first tab)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text("TV Apps"), findsOneWidget, reason: "Should stay on TV Apps when pressing Left on first tab");
  });
}
