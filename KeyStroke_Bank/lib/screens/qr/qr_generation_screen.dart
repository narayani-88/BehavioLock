import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../services/bank_account_service.dart';

class QRGenerationScreen extends StatefulWidget {
  const QRGenerationScreen({super.key});

  @override
  State<QRGenerationScreen> createState() => _QRGenerationScreenState();
}

class _QRGenerationScreenState extends State<QRGenerationScreen> {
  String? _selectedAccountId;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccounts();
    });
  }

  Future<void> _loadAccounts() async {
    final bankAccountService = Provider.of<BankAccountService>(context, listen: false);
    await bankAccountService.initialize();

    if (mounted) {
      setState(() {
        _accounts = bankAccountService.accounts.map((account) => {
          'id': account.id,
          'displayName': '${account.bankName} •••• ${account.accountNumber.substring(account.accountNumber.length - 4)}',
        }).toList();

        // Set first account as default if available
        if (_accounts.isNotEmpty) {
          _selectedAccountId = _accounts.first['id'];
        }
      });
    }
  }

  String _safeString(String? value) {
    return value ?? 'Unknown';
  }

  String _generateQRData() {
    final bankAccountService = Provider.of<BankAccountService>(context, listen: false);

    if (_selectedAccountId == null) {
      return 'No account selected';
    }

    final account = bankAccountService.getAccountById(_selectedAccountId!);

    if (account == null) {
      return 'No account selected';
    }

    // Create a structured QR data format
    return 'BANK:${_safeString(account.bankName)}|ACCOUNT:${_safeString(account.accountNumber)}|HOLDER:${_safeString(account.accountHolderName)}|IFSC:${_safeString(account.ifscCode)}';
  }

  Future<void> _shareQRCode() async {
    if (_selectedAccountId == null) return;

    try {
      // Generate QR code image
      final qrData = _generateQRData();
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ).toImageData(300);

      if (qrImage == null) {
        _showErrorSnackBar('Failed to generate QR code');
        return;
      }

      // Save QR code to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = await File('${tempDir.path}/account_qr.png').create();
      await tempFile.writeAsBytes(qrImage.buffer.asUint8List());

      // Share the QR code
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Scan this QR code to view my bank account details',
      );

      // Clean up temporary file
      await tempFile.delete();
    } catch (e) {
      _showErrorSnackBar('Error sharing QR code: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Generate Account QR', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account Selection Dropdown
            if (_accounts.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAccountId ?? '',
                    hint: Text(
                      'Select Account',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account['id'] as String? ?? '',
                        child: Text(
                          account['displayName'] as String? ?? '',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAccountId = value;
                      });
                    },
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // QR Code Display
            if (_selectedAccountId != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: QrImageView(
                    data: _generateQRData(),
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    errorStateBuilder: (cxt, err) {
                      return const Center(
                        child: Text(
                          'Error generating QR code',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Share Button
            ElevatedButton.icon(
              onPressed: _selectedAccountId != null ? _shareQRCode : null,
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Share QR Code', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
