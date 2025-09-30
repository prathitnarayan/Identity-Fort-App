import 'package:flutter/material.dart';
import 'package:identity_fort/services/root_detection_service.dart';
import 'package:identity_fort/services/splash_router.dart';
import 'package:identity_fort/pages/app_lock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run root detection check before starting app
  final rootService = RootDetectionService();
  final compromised = await rootService.isDeviceCompromised();

  runApp(MyApp(isCompromised: compromised));
}

class MyApp extends StatelessWidget {
  final bool isCompromised;

  const MyApp({super.key, required this.isCompromised});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MFA Authenticator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: isCompromised
          ? const BlockedScreen() // Blocked if rooted/jailbroken
          : AppLockWrapper(child: SplashRouter()),
    );
  }
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Security Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.red.shade700,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Security Alert',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Main Message
              Text(
                'This device is not supported',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Detailed Explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your device appears to be:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReason('Rooted or Jailbroken'),
                    _buildReason('Running in Developer Mode'),
                    _buildReason('Modified System Software'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Security Explanation
              Text(
                'For your security and data protection, this authenticator app cannot run on modified devices.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please use an unmodified device to ensure the security of your accounts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReason(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}