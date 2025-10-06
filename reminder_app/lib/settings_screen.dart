
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reminder_app/auth_service.dart';
import 'package:reminder_app/theme_manager.dart';

import 'package:reminder_app/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      final hour = prefs.getInt('notificationHour') ?? 9;
      final minute = prefs.getInt('notificationMinute') ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _updateNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
    if (!value) {
      await NotificationService().cancelAllNotifications();
    }
  }

  Future<void> _selectNotificationTime(BuildContext context) async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (newTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notificationHour', newTime.hour);
      await prefs.setInt('notificationMinute', newTime.minute);
      setState(() {
        _notificationTime = newTime;
      });
    }
  }

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
            if (!kIsWeb) ...[
              const Divider(),
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: _notificationsEnabled,
                onChanged: _updateNotificationEnabled,
              ),
              ListTile(
                title: const Text('Notification Time'),
                subtitle: Text(_notificationTime.format(context)),
                onTap: () => _selectNotificationTime(context),
                enabled: _notificationsEnabled,
              ),
            ],
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
