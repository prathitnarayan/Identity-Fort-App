import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:identity_fort/services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final StorageService storageService = StorageService(); // Use shared service

  bool _isPasskeyEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPasskeyState();
  }

  Future<void> _checkPasskeyState() async {
    try {
      final value = await storageService.read('passkey_enabled');
      if (mounted) {
        setState(() {
          _isPasskeyEnabled = value == 'true';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPasskeyEnabled = false;
          _isLoading = false;
        });
      }
      print('Error reading from secure storage: $e');
    }
  }

  Future<void> _togglePasskeyAccess() async {
    final isDeviceSupported = await auth.isDeviceSupported();
    if (!isDeviceSupported) {
      _showSnackbar("Device does not support device authentication");
      return;
    }

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: _isPasskeyEnabled
            ? 'Authenticate to disable app lock'
            : 'Authenticate to enable app lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        final newState = !_isPasskeyEnabled;
        
        // Use the shared storage service
        await storageService.write('passkey_enabled', newState.toString());

        if (mounted) {
          setState(() {
            _isPasskeyEnabled = newState;
          });
        }

        _showSnackbar(
          _isPasskeyEnabled ? "App lock enabled" : "App lock disabled",
        );

        // Simple delay then pop back
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showSnackbar("Authentication failed or cancelled");
      }
    } catch (e) {
      print('Authentication error: $e');
      _showSnackbar("Authentication error: ${e.toString()}");
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: Icon(
                    _isPasskeyEnabled ? Icons.lock : Icons.lock_open,
                    color: _isPasskeyEnabled ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    _isPasskeyEnabled ? 'Disable App Lock' : 'Enable App Lock',
                  ),
                  subtitle: Text(
                    _isPasskeyEnabled
                        ? 'App lock is currently enabled'
                        : 'App lock is currently disabled',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _isPasskeyEnabled,
                        onChanged: (_) => _togglePasskeyAccess(),
                      ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: _togglePasskeyAccess,
                ),
                const Divider(),
                // Debug section (remove in production)
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Debug: View All Storage'),
                  onTap: () async {
                    final allData = await storageService.readAll();
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Storage Contents'),
                          content: SingleChildScrollView(
                            child: Text(allData.toString()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }
}