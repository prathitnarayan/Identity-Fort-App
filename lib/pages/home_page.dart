// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otp/otp.dart';
import 'package:identity_fort/pages/qr_code_page.dart';
import 'package:identity_fort/pages/settings.dart';
import 'package:identity_fort/services/otp_storage_service.dart';

class HomePage extends StatefulWidget {
  final String? secret;
  final String? issuer;
  final String? accountName;

  const HomePage({Key? key, this.secret, this.issuer, this.accountName})
    : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showTOTP = true;
  late Timer _timer;
  late Future<List<Map<String, dynamic>>> _accountsFuture;
  int secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _setupInitialAccounts();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _setupInitialAccounts() async {
    List<Map<String, dynamic>> otpAccounts =
        await OTPStorageService.loadAccounts();

    if (widget.secret != null &&
        widget.issuer != null &&
        widget.accountName != null) {
      final newAccount = {
        'secret': widget.secret!,
        'issuer': widget.issuer!,
        'accountName': widget.accountName!,
        'otp': '',
      };
      final bool added = await OTPStorageService.addAccount(newAccount);
      if (added) {
        otpAccounts = await OTPStorageService.loadAccounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New account "${widget.issuer}" added successfully!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account "${widget.issuer}" already exists!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
    return _generateAllTOTPs(otpAccounts);
  }

  List<Map<String, dynamic>> _generateAllTOTPs(
    List<Map<String, dynamic>> accounts,
  ) {
    final now = DateTime.now();
    for (var account in accounts) {
      account['otp'] = OTP.generateTOTPCodeString(
        account['secret'],
        now.millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        interval: 30,
        length: 6,
        isGoogle: true,
      );
    }
    secondsRemaining = 30 - (now.second % 30);
    return accounts;
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteAccount(
    int index,
    List<Map<String, dynamic>> otpAccounts,
  ) async {
    await OTPStorageService.removeAccount(index);
    setState(() {
      _accountsFuture = OTPStorageService.loadAccounts().then(
        _generateAllTOTPs,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showDeleteConfirmation(
    int index,
    List<Map<String, dynamic>> otpAccounts,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text(
            'Are you sure you want to delete this account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount(index, otpAccounts);
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleTOTPVisibility() {
    setState(() {
      _showTOTP = !_showTOTP;
    });
  }

  Widget _buildIndividualTimer(double progress) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Icon(Icons.circle, size: 24, color: Colors.grey[400]),
          Positioned.fill(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                progress > 0.3 ? Colors.blue[700]! : Colors.orange[600]!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatOTP(String otp) {
    if (otp.length == 6) {
      return '${otp.substring(0, 3)} ${otp.substring(3, 6)}';
    }
    return otp;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        final otpAccounts = snapshot.hasData
            ? _generateAllTOTPs(snapshot.data!)
            : <Map<String, dynamic>>[];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              "Identity Fort",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.blue[900],
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _accountsFuture = OTPStorageService.loadAccounts().then(
                      _generateAllTOTPs,
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Codes refreshed'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Codes refreshed'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                tooltip: 'Refresh all codes',
              ),
              IconButton(
                icon: Icon(Icons.qr_code_scanner_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QRCodePage()),
                  );
                },
                tooltip: 'Add new account',
              ),
            ],
          ),
          drawer: SizedBox(
            width: MediaQuery.of(context).size.width * 0.80,
            child: Drawer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(color: Colors.blueAccent),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Authenticator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        _showTOTP ? Icons.visibility : Icons.visibility_off,
                      ),
                      title: Text(_showTOTP ? 'Hide Code' : 'Show Code'),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleTOTPVisibility();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Refresh Codes'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _accountsFuture = OTPStorageService.loadAccounts()
                              .then(_generateAllTOTPs);
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
            child: snapshot.connectionState != ConnectionState.done
                ? Center(
                    child: CircularProgressIndicator(color: Colors.blue[900]),
                  )
                : otpAccounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No accounts added yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the camera icon to scan a QR code',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: otpAccounts.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final Map account = entry.value;
                        final double progress = secondsRemaining / 30.0;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.blue[100]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with issuer, timer, and actions
                              Row(
                                children: [
                                  // Issuer icon and name
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.security,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account['issuer'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          account['accountName'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Individual timer
                                  Column(
                                    children: [
                                      _buildIndividualTimer(progress),
                                      SizedBox(height: 4),
                                      Text(
                                        '${secondsRemaining}s',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: progress > 0.3
                                              ? Colors.blue[700]
                                              : Colors.orange[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 5, height: 4),
                                  // Action buttons
                                  PopupMenuButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                    ),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'copy':
                                          _copyToClipboard(account['otp']);
                                          break;
                                        case 'delete':
                                          _showDeleteConfirmation(
                                            index,
                                            otpAccounts,
                                          );
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'copy',
                                        child: Row(
                                          children: [
                                            Icon(Icons.copy, size: 18),
                                            SizedBox(width: 8),
                                            Text('Copy Code'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              // OTP Code display
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _copyToClipboard(account['otp']),
                                        child: Text(
                                          _showTOTP
                                              ? _formatOTP(account['otp'])
                                              : '••• •••',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            letterSpacing: 3.0,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Progress bar for visual indication
                              // SizedBox(height: 12),
                              // LinearProgressIndicator(
                              //   value: progress,
                              //   backgroundColor: Colors.grey[200],
                              //   valueColor: AlwaysStoppedAnimation(
                              //     progress > 0.3
                              //         ? Colors.blue[600]!
                              //         : Colors.orange[500]!,
                              //   ),
                              //   minHeight: 3,
                              // ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
