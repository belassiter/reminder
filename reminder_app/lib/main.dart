import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reminder_app/auth_gate.dart';
import 'package:reminder_app/firebase_options.dart';
import 'package:reminder_app/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(ChangeNotifierProvider<ThemeManager>(
    create: (_) => ThemeManager(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      themeMode: context.watch<ThemeManager>().themeMode,
      home: const AuthGate(),
    );
  }
}