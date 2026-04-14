
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class BackButtonActionPage extends StatelessWidget {
  static const String routeName = "back_button_action_panel";

  const BackButtonActionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
        builder: (context, service, _) {
          return Column(
            children: [
              Text(localizations.backButtonAction, style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _radioTile(context, service, localizations.dialogOptionBackButtonActionDoNothing, ""),
                    _radioTile(context, service, localizations.dialogOptionBackButtonActionShowClock, BACK_BUTTON_ACTION_CLOCK),
                    _radioTile(context, service, localizations.dialogOptionBackButtonActionShowScreensaver, BACK_BUTTON_ACTION_SCREENSAVER),
                  ],
                ),
              ),
            ],
          );
        }
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, String label, String value) {
    final isSelected = service.backButtonAction == value;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setBackButtonAction(value),
    );
  }
}
