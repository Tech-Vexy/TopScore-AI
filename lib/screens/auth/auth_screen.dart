import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsLogin;

  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  void _toggleAuth() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLogin) {
      return LoginScreen(onToggle: _toggleAuth);
    } else {
      return SignupScreen(onToggle: _toggleAuth);
    }
  }
}
