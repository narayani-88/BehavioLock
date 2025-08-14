import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../services/bank_account_service.dart';
import '../transactions/transfer_money_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _hasCameraPermission = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    // Prevent concurrent permission requests
    if (_isRequestingPermission) return;

    try {
      setState(() {
        _isRequestingPermission = true;
      });

      final status = await Permission.camera.status;
      
      if (status.isGranted) {
        setState(() {
          _hasCameraPermission = true;
          _isRequestingPermission = false;
        });
        _initializeScanner();
      } else {
        final result = await Permission.camera.request();
        
        setState(() {
          _hasCameraPermission = result.isGranted;
          _isRequestingPermission = false;
        });

        if (result.isGranted) {
          _initializeScanner();
        } else {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      setState(() {
        _isRequestingPermission = false;
      });
      _showErrorSnackBar('Error checking camera permission: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to scan QR codes. Please grant camera permission in your device settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      returnImage: false,
    );
  }

  void _handleScannerError(Object? error) {
    if (mounted) {
      _showErrorSnackBar('Camera error: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _checkCameraPermission();
        break;
      case AppLifecycleState.paused:
        _scannerController.dispose();
        break;
      default:
        break;
    }
  }

  void _handleQRCodeDetection(BarcodeCapture capture) async {
    // Prevent multiple simultaneous processing
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get the first barcode
      final barcode = capture.barcodes.first;
      final rawValue = barcode.rawValue;

      if (rawValue == null) {
        _showErrorSnackBar('Invalid QR code');
        return;
      }

      // Parse the QR code data
      final qrData = _parseQRData(rawValue);

      if (qrData == null) {
        _showErrorSnackBar('Unrecognized QR code format');
        return;
      }

      // Find the recipient's account
      final bankAccountService = Provider.of<BankAccountService>(context, listen: false);
      await bankAccountService.initialize();

      // Find accounts matching the QR code details
      final matchingAccounts = bankAccountService.accounts.where((account) => 
        account.accountNumber == qrData['ACCOUNT'] &&
        account.bankName == qrData['BANK']
      ).toList();

      if (matchingAccounts.isEmpty) {
        _showErrorSnackBar('No matching account found');
        return;
      }

      // Navigate to Transfer Money Screen with pre-selected recipient
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TransferMoneyScreen(
              preselectedRecipientId: matchingAccounts.first.userId,
              preselectedRecipientAccountId: matchingAccounts.first.id,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error processing QR code: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, String>? _parseQRData(String rawValue) {
    try {
      // Split the QR data into key-value pairs
      final parts = rawValue.split('|');
      final qrData = <String, String>{};

      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          qrData[keyValue[0]] = keyValue[1];
        }
      }

      // Validate required fields
      if (qrData.containsKey('BANK') && 
          qrData.containsKey('ACCOUNT') && 
          qrData.containsKey('HOLDER') && 
          qrData.containsKey('IFSC')) {
        return qrData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          if (_hasCameraPermission)
            IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _scannerController.torchState,
                builder: (context, state, child) {
                  switch (state) {
                    case TorchState.off:
                      return const Icon(Icons.flash_off);
                    case TorchState.on:
                      return const Icon(Icons.flash_on);
                  }
                },
              ),
              onPressed: () => _scannerController.toggleTorch(),
            ),
        ],
      ),
      body: _hasCameraPermission
          ? Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleQRCodeDetection,
                  errorBuilder: (context, error, child) {
                    _handleScannerError(error);
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 50),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Error: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _checkCameraPermission,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                  overlay: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                
                // Scanning overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 128), width: 4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                
                // Processing indicator
                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera Permission Required',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkCameraPermission,
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            ),
    );
  }
}
