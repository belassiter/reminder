
import 'package:reminder_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reminder_app/theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                ListTile(
                  title: const Text('System'),
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: themeManager.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        themeManager.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    themeManager.setThemeMode(ThemeMode.system);
                  },
                ),
                ListTile(
                  title: const Text('Light'),
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: themeManager.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        themeManager.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    themeManager.setThemeMode(ThemeMode.light);
                  },
                ),
                ListTile(
                  title: const Text('Dark'),
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: themeManager.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        themeManager.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    themeManager.setThemeMode(ThemeMode.dark);
                  },
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await AuthService().signOut();
                  navigator.pop();
                },
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
