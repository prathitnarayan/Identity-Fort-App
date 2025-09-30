import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:identity_fort/services/storage_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _authenticated = false;
  bool _appLockEnabled = false;
  String? _authError;
  bool _isLoading = true;
  bool _isAuthenticating = false; // Prevent multiple authentication attempts

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockStatus();
  }

  @override
  void didUpdateWidget(AppLockWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only check for changes if not currently authenticating
    if (!_isAuthenticating) {
      _loadLockStatus();
    }
  }

  Future _loadLockStatus() async {
    if (!mounted || _isAuthenticating) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _storageService.read('passkey_enabled');
      final newLockEnabled = status == 'true';

      if (mounted) {
        setState(() {
          _appLockEnabled = newLockEnabled;
          _isLoading = false;
        });
      }

      // Only authenticate if:
      // 1. App lock is enabled
      // 2. User is not already authenticated
      // 3. Not currently authenticating
      if (_appLockEnabled && !_authenticated && !_isAuthenticating) {
        await _authenticate();
      } else if (!_appLockEnabled && mounted) {
        // If app lock was disabled, allow access
        setState(() {
          _authenticated = true;
          _authError = null;
        });
      }
    } catch (e) {
      print('Error loading lock status: $e');
      if (mounted) {
        setState(() {
          _appLockEnabled = false;
          _authenticated = true;
          _isLoading = false;
        });
      }
    }
  }

  Future _authenticate() async {
    if (!_appLockEnabled || !mounted || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (mounted) {
        setState(() {
          _authenticated = authenticated;
          _authError = authenticated
              ? null
              : 'Authentication failed or cancelled';
          _isAuthenticating = false;
        });
      }
    } on PlatformException catch (e) {
      print('Biometric error: $e');
      if (mounted) {
        setState(() {
          _authenticated = false;
          _authError = 'Authentication error: ${e.message}';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      print('Unexpected error: $e');
      if (mounted) {
        setState(() {
          _authenticated = false;
          _authError = 'Unexpected error occurred';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_appLockEnabled && mounted && !_isAuthenticating) {
      if (state == AppLifecycleState.resumed) {
        // Only authenticate if not already authenticated
        if (!_authenticated) {
          _authenticate();
        }
      } else if (state == AppLifecycleState.paused) {
        setState(() => _authenticated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_appLockEnabled && !_authenticated) {
      return Scaffold(
        body: Center(
          child: _authError == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 64, color: Colors.blue[900]),
                    const SizedBox(height: 24),
                    const Text(
                      'App Locked',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please authenticate to continue',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    if (_isAuthenticating) const CircularProgressIndicator(),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _authError!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isAuthenticating
                          ? null
                          : () {
                              setState(() {
                                _authError = null;
                              });
                              _authenticate();
                            },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
