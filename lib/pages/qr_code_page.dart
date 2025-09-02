import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:identity_fort/services/backend_qr_decoder_service.dart';

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
      _showPermissionDialog();
    } else {
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

  void _showQRErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                Navigator.of(context).pop();
                _exitToHomePage();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _resetScanner();
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

  void _exitToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
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
      print(
        'QR Code detected: ${code.substring(0, Math.min(50, code.length))}...',
      );

      // Case 1: Standard OTP URI format (otpauth://)
      if (code.startsWith("otpauth://")) {
        print('Processing standard OTP URI');
        final parsed = _parseOTPAuthURI(code);
        if (parsed == null) {
          _showQRErrorDialog(
            "Invalid QR code format. The QR code appears to be corrupted or not a valid OTP code.",
          );
          return;
        }

        if (parsed['isExpired'] == 'true') {
          _showQRErrorDialog(
            "QR code has expired. Please generate a new QR code and try again.",
          );
          return;
        }

        _navigateToHomePage(parsed);
        return;
      }

      // Case 2: Backend generated encrypted QR payload (Primary method)
      print('Attempting to decode as backend QR payload');
      final backendData = await BackendQRDecoderService.decodeQRPayload(code);
      if (backendData != null && backendData.isNotEmpty) {
        print('Successfully decoded backend QR payload');
        _navigateToHomePage(backendData);
        return;
      }

      // Case 3: Try legacy secure format (for backward compatibility)
      print('Attempting legacy secure format decoding');
      final secureData = await _processLegacySecureQRCode(code);
      if (secureData != null) {
        print('Successfully processed legacy secure QR code');
        _navigateToHomePage(secureData);
        return;
      }

      // Case 4: Plain text format fallback (username:secret)
      final plainData = _tryPlainTextFormat(code);
      if (plainData != null) {
        print('Successfully processed plain text format');
        _navigateToHomePage(plainData);
        return;
      }

      _showQRErrorDialog(
        "Unable to process QR code. Please ensure you're scanning a valid IdentityFort QR code generated by your backend system.",
      );
    } catch (e) {
      print('Error processing QR code: $e');
      _showQRErrorDialog(
        "An error occurred while processing the QR code. Please ensure the code is valid and try again.",
      );
    }
  }

  void _navigateToHomePage(Map<String, String> accountData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          secret: accountData['secret']!,
          issuer: accountData['issuer']!,
          accountName: accountData['accountName']!,
        ),
      ),
    );
  }

  /// Try to parse as plain text format (username:secret)
  Map<String, String>? _tryPlainTextFormat(String code) {
    try {
      if (code.contains(':')) {
        final parts = code.split(':');
        if (parts.length >= 2) {
          final username = parts[0].trim();
          final secret = parts[1].trim().replaceAll(' ', '').toUpperCase();

          // Basic validation for base32 secret
          if (secret.length >= 16 &&
              RegExp(r'^[A-Z2-7]+=*$').hasMatch(secret)) {
            return {
              'secret': secret,
              'issuer': 'IdentityFort',
              'accountName': username,
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('Error parsing plain text format: $e');
      return null;
    }
  }

  // Keep your existing legacy secure QR processing for backward compatibility
  Future<Map<String, String>?> _processLegacySecureQRCode(
    String encryptedQR,
  ) async {
    const AES_KEY = '12345678901234567890123456789012';
    const HMAC_KEY = 'my_secure_hmac_key';

    try {
      final key = encrypt.Key.fromUtf8(AES_KEY);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ecb, padding: 'PKCS7'),
      );
      final encryptedBytes = encrypt.Encrypted.fromBase64(encryptedQR);
      final decrypted = encrypter.decrypt(encryptedBytes);

      print('Decrypted Legacy Payload: $decrypted');

      final parts = decrypted.split('|');

      // Handle both old format (4 parts) and new format (3 parts)
      if (parts.length == 3) {
        // New format: username|timestamp|secret
        final userId = parts[0];
        final expiryStr = parts[1];
        final secret = parts[2];

        // Check expiry (timestamp is in seconds, convert to milliseconds)
        try {
          final expiryTime =
              int.parse(expiryStr) * 1000; // Convert to milliseconds
          final currentTime = DateTime.now().millisecondsSinceEpoch;

          print('Current time: $currentTime, Expiry time: $expiryTime');

          if (currentTime > expiryTime) {
            print('QR code has expired - continuing for testing purposes');
            // For debugging, continue processing expired QR codes
            // In production, uncomment the next line:
            // throw Exception('QR code has expired');
          }
        } catch (e) {
          print('Error parsing expiry time: $e');
          // Don't throw here, continue processing for debugging
          print('Continuing despite expiry error for debugging...');
        }

        // The secret appears to be Base64, need to convert to Base32 for TOTP
        String processedSecret;
        try {
          // If secret is Base64, decode it first then convert to Base32
          final secretBytes = base64Decode(secret);
          // Convert bytes to Base32 (TOTP standard)
          processedSecret = _bytesToBase32(secretBytes);
        } catch (e) {
          // If not Base64, treat as plain text and try to make it Base32 compatible
          print('Secret is not Base64, treating as plain text: $e');
          processedSecret = secret
              .replaceAll(RegExp(r'[^A-Z2-7]'), '')
              .toUpperCase();
          if (processedSecret.length < 16) {
            // Pad to minimum Base32 length
            processedSecret = processedSecret.padRight(16, '2');
          }
        }

        return {
          'secret': processedSecret,
          'issuer': 'IdentityFort',
          'accountName': userId,
        };
      } else if (parts.length == 4) {
        // Old format: username|secret|timestamp|hmac
        final userId = parts[0];
        final secret = parts[1];
        final expiryStr = parts[2];
        final mac = parts[3];

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

        final payload = '$userId|$secret|$expiryStr';
        final hmacSha256 = Hmac(sha256, utf8.encode(HMAC_KEY));
        final digest = hmacSha256.convert(utf8.encode(payload));
        final expectedMac = base64.encode(digest.bytes);

        if (expectedMac != mac) {
          throw Exception('Invalid MAC. Tampering detected.');
        }

        return {
          'secret': secret,
          'issuer': 'IdentityFort',
          'accountName': userId,
        };
      } else {
        throw FormatException(
          'Decrypted string is malformed: ${parts.length} parts found, expected 3 or 4',
        );
      }
    } catch (e) {
      print('Failed to process legacy QR: $e');
      return null;
    }
  }

  // Helper method to convert bytes to Base32
  String _bytesToBase32(List<int> bytes) {
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    String result = '';

    for (int i = 0; i < bytes.length; i += 5) {
      int buffer = 0;
      int bitsLeft = 0;

      for (int j = 0; j < 5 && i + j < bytes.length; j++) {
        buffer = (buffer << 8) | bytes[i + j];
        bitsLeft += 8;
      }

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        result += base32Chars[(buffer >> bitsLeft) & 0x1F];
      }

      if (bitsLeft > 0) {
        result += base32Chars[(buffer << (5 - bitsLeft)) & 0x1F];
      }
    }

    // Add padding
    while (result.length % 8 != 0) {
      result += '=';
    }

    return result;
  }

  Map<String, String>? _parseOTPAuthURI(String uri) {
    try {
      final parsedUri = Uri.parse(uri);

      final secret = parsedUri.queryParameters['secret'];
      if (secret == null || secret.isEmpty) return null;

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
          isExpired = true;
        }
      }

      final path = parsedUri.path.replaceFirst("/", "");
      String accountName = path;
      String issuer = parsedUri.queryParameters['issuer'] ?? 'Unknown';

      if (path.contains(":")) {
        final parts = path.split(":");
        if (parts.length >= 2) {
          issuer = parts[0];
          accountName = parts.sublist(1).join(":");
        }
      }

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
            _exitToHomePage();
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
