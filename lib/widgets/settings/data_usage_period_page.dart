
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DataUsagePeriodPage extends StatelessWidget {
  static const String routeName = "data_usage_period_panel";

  const DataUsagePeriodPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
        builder: (context, service, _) {
          return Column(
            children: [
              Text('Data Usage Period', style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _radioTile(context, service, 'Daily', DATA_USAGE_DAILY),
                    _radioTile(context, service, 'Weekly', DATA_USAGE_WEEKLY),
                    _radioTile(context, service, 'Monthly', DATA_USAGE_MONTHLY),
                  ],
                ),
              ),
            ],
          );
        }
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, String label, String value) {
    final isSelected = service.dataUsagePeriod == value;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setDataUsagePeriod(value),
    );
  }
}
