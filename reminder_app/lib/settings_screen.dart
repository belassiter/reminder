
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reminder_app/theme_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RadioGroup<ThemeMode>(
          groupValue: themeManager.themeMode,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              themeManager.setThemeMode(value);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const RadioListTile<ThemeMode>(
                title: Text('System'),
                value: ThemeMode.system,
              ),
              const RadioListTile<ThemeMode>(
                title: Text('Light'),
                value: ThemeMode.light,
              ),
              const RadioListTile<ThemeMode>(
                title: Text('Dark'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
