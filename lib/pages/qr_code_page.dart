import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class QRCodePage extends StatefulWidget {
  const QRCodePage({super.key});

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isPermissionGranted = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    // Check current permission status first
    PermissionStatus status = await Permission.camera.request();
    print('Initial camera permission status: $status');

    if (!status.isGranted) {
      status = await Permission.camera.request();
      print('After request - camera permission status: $status');
    }

    if (status.isGranted) {
      setState(() {
        _isPermissionGranted = true;
      });
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      _showPermissionDialog();
    } else {
      // Handle denied, restricted, limited, or any other non-granted status
      print('Camera permission not granted. Status: $status');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera permission is required to scan QR codes. Status: $status',
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _requestCameraPermission,
            ),
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Please enable camera permission in app settings to use QR scanner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // New method to show QR error dialog with retry option
  void _showQRErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('QR Code Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _exitToHomePage(); // Exit to home page
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _resetScanner(); // Restart scanner
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // New method to exit to home page
  void _exitToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<Map<String, String>?> _processSecureQRCode(String encryptedQR) async {
    // These should match your backend configuration
    const AES_KEY =
        '12345678901234567890123456789012'; // Update this to match your ${aes.key}
    const HMAC_KEY =
        'my_secure_hmac_key'; // Update this to match your ${hmac.key}

    try {
      // Step 1: Decrypt the QR code
      final key = encrypt.Key.fromUtf8(AES_KEY);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ecb, padding: 'PKCS7'),
      );
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedQR);
      final decrypted = encrypter.decrypt(encryptedBytes);

      print('Decrypted Payload: $decrypted');

      // Step 2: Format check - now expecting 4 parts: userId|secret|expiry|mac
      final parts = decrypted.split('|');
      if (parts.length != 4) {
        throw FormatException(
          'Decrypted string is malformed: ${parts.length} parts found, expected 4',
        );
      }

      final userId = parts[0];
      final secret = parts[1];
      final expiryStr = parts[2];
      final mac = parts[3];

      // Step 3: Check expiry
      try {
        final expiryTime = int.parse(expiryStr);
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        print('Current time: $currentTime, Expiry time: $expiryTime');

        if (currentTime > expiryTime) {
          print('QR code has expired');
          throw Exception('QR code has expired');
        }
      } catch (e) {
        print('Error parsing expiry time: $e');
        throw Exception('Invalid expiry time format');
      }

      // Step 4: Verify MAC - payload should be userId|secret|expiry (without the MAC part)
      final payload = '$userId|$secret|$expiryStr';
      final hmacSha256 = Hmac(sha256, utf8.encode(HMAC_KEY));
      final digest = hmacSha256.convert(utf8.encode(payload));
      final expectedMac = base64.encode(digest.bytes);

      if (expectedMac != mac) {
        throw Exception('Invalid MAC. Tampering detected.');
      }

      return {
        'secret': secret,
        'issuer': 'PAM', // Changed to match your backend
        'accountName': userId,
      };
    } catch (e) {
      print('Failed to process QR: $e');
      return null;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    _controller.stop();

    try {
      // Case 1: Standard OTP QR with expiry validation
      if (code.startsWith("otpauth://")) {
        final parsed = _parseOTPAuthURI(code);
        if (parsed == null) {
          _showQRErrorDialog(
            "Invalid QR code format. The QR code appears to be corrupted or not a valid OTP code.",
          );
          return;
        }

        // Check if QR code has expired
        if (parsed['isExpired'] == 'true') {
          _showQRErrorDialog(
            "QR code has expired. Please generate a new QR code and try again.",
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              secret: parsed['secret']!,
              issuer: parsed['issuer']!,
              accountName: parsed['accountName']!,
            ),
          ),
        );
        return;
      }

      // Case 2: Custom Secure QR (New encrypted format)
      final secureData = await _processSecureQRCode(code);
      if (secureData != null) {
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              secret: secureData['secret']!,
              issuer: secureData['issuer']!,
              accountName: secureData['accountName']!,
            ),
          ),
        );
        return;
      }

      _showQRErrorDialog(
        "Unable to process QR code. The code may be expired, corrupted, or in an unsupported format.",
      );
    } catch (e) {
      print('Error processing QR code: $e');
      _showQRErrorDialog(
        "An error occurred while processing the QR code. Please ensure the code is valid and try again.",
      );
    }
  }

  Map<String, String>? _parseOTPAuthURI(String uri) {
    try {
      final parsedUri = Uri.parse(uri);

      // Extract secret
      final secret = parsedUri.queryParameters['secret'];
      if (secret == null || secret.isEmpty) return null;

      // Extract expiry time and validate
      final expiresParam = parsedUri.queryParameters['expires'];
      bool isExpired = false;

      if (expiresParam != null) {
        try {
          final expiryTime = int.parse(expiresParam);
          final currentTime = (DateTime.now().millisecondsSinceEpoch / 1000)
              .floor();

          print('Current time: $currentTime, Expiry time: $expiryTime');

          if (currentTime > expiryTime) {
            print('QR code has expired');
            isExpired = true;
          }
        } catch (e) {
          print('Error parsing expiry time: $e');
          // If we can't parse expiry, treat as expired for security
          isExpired = true;
        }
      }

      // Extract account name and issuer
      final path = parsedUri.path.replaceFirst("/", "");
      String accountName = path;
      String issuer = parsedUri.queryParameters['issuer'] ?? 'Unknown';

      // Handle format: otpauth://totp/PAM:email@example.com
      if (path.contains(":")) {
        final parts = path.split(":");
        if (parts.length >= 2) {
          issuer = parts[0];
          accountName = parts.sublist(1).join(":");
        }
      }

      // If issuer is still 'Unknown' but we have a colon-separated format, use the first part
      if (issuer == 'Unknown' && path.contains(":")) {
        issuer = path.split(":")[0];
      }

      return {
        'secret': secret.replaceAll(' ', '').toUpperCase(),
        'issuer': issuer,
        'accountName': accountName,
        'isExpired': isExpired.toString(),
      };
    } catch (e) {
      print('Error parsing OTP URI: $e');
      return null;
    }
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isScanning = true;
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _exitToHomePage(); // Custom exit method
          },
        ),
        actions: [
          if (_isPermissionGranted)
            IconButton(
              icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
              onPressed: () {
                setState(() {
                  _torchEnabled = !_torchEnabled;
                  _controller.toggleTorch();
                });
              },
            ),
        ],
      ),
      body: _isPermissionGranted
          ? Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing QR Code...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Scanner overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Instructions
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Position the QR code within the frame to scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera permission required',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestCameraPermission,
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            ),
    );
  }
}
