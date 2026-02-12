import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import 'attendance_list_page.dart';
import 'attendance_providers.dart';

/// QR display screen shown to teachers after opening an attendance session.
/// Shows QR code, countdown timer, and live scan count.
class QrDisplayPage extends StatefulWidget {
  final String classId;
  final String sessionId;
  final String token;
  final DateTime expiresAt;

  const QrDisplayPage({
    super.key,
    required this.classId,
    required this.sessionId,
    required this.token,
    required this.expiresAt,
  });

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
    _loadStudentCount();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
    if (diff.isNegative) {
      _timer.cancel();
    }
  }

  Future<void> _loadStudentCount() async {
    final count = await fetchClassStudentCount(widget.classId);
    if (mounted) {
      setState(() => _totalStudents = count);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// QR data: JSON string with classId, sessionId, and token.
  String get _qrData {
    return '{"classId":"${widget.classId}",'
        '"sessionId":"${widget.sessionId}",'
        '"token":"${widget.token}"}';
  }

  bool get _isExpired => _remaining == Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Pr\u00e9sence'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Countdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpired
                      ? AppColors.error.withAlpha(25)
                      : AppColors.secondary.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpired ? Icons.timer_off : Icons.timer_outlined,
                      color:
                          _isExpired ? AppColors.error : AppColors.secondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isExpired ? 'Expir\u00e9' : _formatDuration(_remaining),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color:
                            _isExpired ? AppColors.error : AppColors.secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // QR Code
              Expanded(
                child: Center(
                  child: Container(
                    decoration: AppCardStyles.cardDecoration,
                    padding: const EdgeInsets.all(20),
                    child: _isExpired
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_off,
                                  size: 64, color: AppColors.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'Session expir\u00e9e',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 260,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.primary,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Scan count (live stream)
              StreamBuilder<int>(
                stream: attendanceRecordsCountStream(
                  classId: widget.classId,
                  sessionId: widget.sessionId,
                ),
                builder: (context, snapshot) {
                  final scanned = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppCardStyles.cardDecoration,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outlined,
                            color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Scann\u00e9s : $scanned / $_totalStudents',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // View list button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceListPage(
                          classId: widget.classId,
                          sessionId: widget.sessionId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Voir la liste'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
