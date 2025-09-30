import 'package:flutter/material.dart';
import 'package:identity_fort/pages/home_page.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('lib/assets/icons/Logo_qr_au.png', height: 250),
      ),
    );
  }
}
