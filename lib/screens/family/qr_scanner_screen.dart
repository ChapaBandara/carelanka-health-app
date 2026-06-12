import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #48 — QR scan with account-found bottom sheet.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _found = false;
  bool _shareRecords = true;
  bool _shareMeds = true;
  bool _shareAppts = false;
  bool _shareReports = false;

  void _showFoundSheet() => setState(() => _found = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF1B2B1F)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                            SizedBox(height: 4),
                            Text(
                              'Make sure the QR code is well-lit and in frame',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _showFoundSheet,
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final align in [
                              Alignment.topLeft,
                              Alignment.topRight,
                              Alignment.bottomLeft,
                              Alignment.bottomRight,
                            ])
                              Align(
                                alignment: align,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: align.y < 0 ? const BorderSide(color: AppColors.primaryTeal, width: 4) : BorderSide.none,
                                      left: align.x < 0 ? const BorderSide(color: AppColors.primaryTeal, width: 4) : BorderSide.none,
                                      right: align.x > 0 ? const BorderSide(color: AppColors.primaryTeal, width: 4) : BorderSide.none,
                                      bottom: align.y > 0 ? const BorderSide(color: AppColors.primaryTeal, width: 4) : BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            if (!_found)
                              TextButton(
                                onPressed: _showFoundSheet,
                                child: const Text('Tap to simulate scan', style: TextStyle(color: Colors.white54)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_found) ...[
            ModalBarrier(color: Colors.black.withValues(alpha: 0.45), dismissible: false),
            Align(
              alignment: Alignment.bottomCenter,
              child: _foundSheet(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _foundSheet(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFFE0F7F7), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.primaryTeal, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('Account Found!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Kamal Perera found on CareLanka',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Text('Send a linking invitation to this account?', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: const Text('What can they see?', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDEE2E6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _permRow('Health Records', _shareRecords, (v) => setState(() => _shareRecords = v)),
                _permRow('Medications', _shareMeds, (v) => setState(() => _shareMeds = v)),
                _permRow('Appointments', _shareAppts, (v) => setState(() => _shareAppts = v)),
                _permRow('Reports', _shareReports, (v) => setState(() => _shareReports = v)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Note: View only — they cannot edit your data', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.linkConfirmation),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: CareLankaGradients.primaryHorizontal,
                ),
                child: const Center(
                  child: Text('Send Invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _found = false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }

  Widget _permRow(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: AppColors.primaryTeal,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
