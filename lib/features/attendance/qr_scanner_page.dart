import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme.dart';
import 'attendance_providers.dart';

/// Student QR scanner page.
/// Scans a QR code containing {classId, sessionId, token},
/// calls submitAttendance, and shows the result.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

enum _ScanState { scanning, submitting, success, error }

class _QrScannerPageState extends State<QrScannerPage> {
  late MobileScannerController _controller;
  _ScanState _state = _ScanState.scanning;
  String? _checkedAt;
  String? _errorMessage;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _hasScanned = true;
    await _controller.stop();

    setState(() => _state = _ScanState.submitting);

    try {
      final payload = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
      final classId = payload['classId'] as String?;
      final sessionId = payload['sessionId'] as String?;
      final token = payload['token'] as String?;

      if (classId == null || sessionId == null || token == null) {
        throw FormatException('QR code invalide.');
      }

      final result = await callSubmitAttendance(
        classId: classId,
        sessionId: sessionId,
        token: token,
      );

      if (!mounted) return;

      final checkedAtRaw = result['checkedAt'] as String?;
      String displayTime = '';
      if (checkedAtRaw != null) {
        final dt = DateTime.tryParse(checkedAtRaw)?.toLocal();
        if (dt != null) {
          displayTime =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
      }

      setState(() {
        _state = _ScanState.success;
        _checkedAt = displayTime;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMessage = 'QR code invalide. Veuillez scanner un code valide.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMessage = _mapErrorMessage(e.toString());
      });
    }
  }

  String _mapErrorMessage(String error) {
    if (error.contains('already-exists') ||
        error.contains('déjà enregistrée')) {
      return 'Présence déjà enregistrée.';
    }
    if (error.contains('deadline-exceeded') || error.contains('expiré')) {
      return 'La session de présence a expiré.';
    }
    if (error.contains('permission-denied') ||
        error.contains('invalide') ||
        error.contains('Token')) {
      return 'Token de présence invalide.';
    }
    if (error.contains('not-found') || error.contains('introuvable')) {
      return 'Session de présence introuvable.';
    }
    if (error.contains("n'appartenez pas")) {
      return "Vous n'appartenez pas à cette classe.";
    }
    if (error.contains('unauthenticated')) {
      return 'Authentification requise. Veuillez vous reconnecter.';
    }
    return 'Erreur : $error';
  }

  void _resetScanner() {
    _hasScanned = false;
    _controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    setState(() {
      _state = _ScanState.scanning;
      _errorMessage = null;
      _checkedAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner QR')),
      body: switch (_state) {
        _ScanState.scanning => _buildScannerView(),
        _ScanState.submitting => _buildSubmittingView(),
        _ScanState.success => _buildSuccessView(),
        _ScanState.error => _buildErrorView(),
      },
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Impossible d\'accéder à la caméra.\n'
                      'Vérifiez les permissions dans les paramètres.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Overlay with scan hint
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Placez le QR code dans le cadre',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
        // Scan frame overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.secondary, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Envoi en cours...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Validation de votre présence',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Présence enregistrée',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.success),
            ),
            if (_checkedAt != null && _checkedAt!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'à $_checkedAt',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Une erreur est survenue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _resetScanner,
                child: const Text('Réessayer'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
