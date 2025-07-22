import 'package:flutter/material.dart';
import 'package:identity_fort/services/splash_router.dart';
import 'package:identity_fort/pages/app_lock.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MFA Authenticator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AppLockWrapper(child: SplashRouter()),
    );
  }
}
