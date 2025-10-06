
import 'package:flutter/material.dart';
import 'package:reminder_app/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await authService.signInWithGoogle();
          },
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
