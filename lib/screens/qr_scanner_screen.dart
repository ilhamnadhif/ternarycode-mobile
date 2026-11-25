import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/host_models.dart';
import '../state/app_controller.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 02 · Native Android CameraX QR Scanner with Slate corner reticle
/// and instant 1-tap detected host banner.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.controller,
    required this.onManualFallback,
    required this.onPaired,
    this.cameraDisabled = false,
  });

  final AppController controller;
  final VoidCallback onManualFallback;
  final VoidCallback onPaired;
  final bool cameraDisabled;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _scanner;
  bool _torchOn = false;
  ParsedPairingQr? _detected;
  bool _pairing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.cameraDisabled) {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  void _onBarcode(BarcodeCapture capture) {
    if (_pairing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final parsed = ParsedPairingQr.tryParse(raw);
      if (parsed != null) {
        setState(() {
          _detected = parsed;
          _error = null;
        });
        return;
      }
    }
  }

  Future<void> _confirmPair() async {
    final det = _detected;
    if (det == null || _pairing) return;
    setState(() {
      _pairing = true;
      _error = null;
    });
    final err = await widget.controller.pairHost(
      rawUrl: det.baseUrl,
      code: det.code,
      deviceName: 'Android Phone',
    );
    if (!mounted) return;
    if (err == null) {
      widget.onPaired();
    } else {
      setState(() {
        _pairing = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const boxSize = 228.0;
          final reticleCenterY = constraints.maxHeight * 0.39;
          final captionTop = reticleCenterY + (boxSize / 2) + 18;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_scanner != null)
                MobileScanner(
                  controller: _scanner!,
                  onDetect: _onBarcode,
                  errorBuilder: (_, err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.cameraSlash,
                              color: Color(0xFFA0A0A9), size: 32),
                          const SizedBox(height: 10),
                          const Text(
                            'Camera unavailable or permission denied.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFEDEDF0), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            err.errorDetails?.message ??
                                'Use manual pairing to connect by address and code.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFA0A0A9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.18),
                      radius: 0.9,
                      colors: [
                        Color(0xFF14141A),
                        Color(0xFF070709),
                      ],
                    ),
                  ),
                ),

              // Translucent reticle mask locked to `reticleCenterY`
              IgnorePointer(
                child: CustomPaint(
                  painter: _ReticleScrimPainter(
                    accent: const Color(0xFF8BB2FF),
                    centerYFraction: 0.39,
                    boxSize: boxSize,
                  ),
                ),
              ),

              // Caption mathematically anchored 18px below the reticle box
              Positioned(
                top: captionTop,
                left: 28,
                right: 28,
                child: const IgnorePointer(
                  child: Text(
                    'Point at the QR code in Settings → Phone on your Mac, Linux, or Windows PC.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      height: 18 / 12.5,
                      color: Color(0xFFD4D4D8),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Top controls (Back + Torch)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CamPillButton(
                            icon: PhosphorIconsRegular.arrowLeft,
                            label: 'Back',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          _CamPillButton(
                            icon: PhosphorIconsRegular.lightning,
                            label: _torchOn ? 'Torch on' : 'Torch',
                            active: _torchOn,
                            onTap: () async {
                              try {
                                await _scanner?.toggleTorch();
                                if (mounted) {
                                  setState(() => _torchOn = !_torchOn);
                                }
                              } catch (_) {
                                if (mounted) {
                                  widget.controller.showToast(
                                    'Torch unavailable on this camera',
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xEB261416),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: c.failed.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFFF6908B),
                                  fontSize: 12,
                                  height: 16 / 12,
                                ),
                              ),
                            ),
                          ],
                          if (_detected != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xF01A1A1D),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0x598BB2FF)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: c.done,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Detected · ${_detected!.hostLabel ?? _detected!.baseUrl}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFEDEDF0),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Code ${_detected!.code}',
                                          style: SlateTypography.data(
                                            SlateColors.dark,
                                            color: const Color(0xFFA0A0A9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SlateButton(
                                    label: 'Pair',
                                    height: 34,
                                    busy: _pairing,
                                    onPressed: _confirmPair,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onManualFallback,
                                borderRadius: BorderRadius.circular(10),
                                child: Ink(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(PhosphorIconsRegular.keyboard,
                                          size: 16, color: Color(0xFFEDEDF0)),
                                      SizedBox(width: 7),
                                      Text(
                                        'Enter code manually',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFEDEDF0),
                                        ),
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CamPillButton extends StatelessWidget {
  const _CamPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? const Color(0x332E6BE6)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: active
                  ? const Color(0x888BB2FF)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFFEDEDF0)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEDEDF0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReticleScrimPainter extends CustomPainter {
  const _ReticleScrimPainter({
    required this.accent,
    this.centerYFraction = 0.39,
    this.boxSize = 228.0,
  });
  final Color accent;
  final double centerYFraction;
  final double boxSize;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * centerYFraction),
      width: boxSize,
      height: boxSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

    final scrimPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      scrimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.56),
    );

    // 4 Slate blue corner brackets
    final cornerPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    const r = 16.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + len)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.left + r, rect.top),
            radius: const Radius.circular(r))
        ..lineTo(rect.left + len, rect.top),
      cornerPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - len, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r),
            radius: const Radius.circular(r))
        ..lineTo(rect.right, rect.top + len),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - len)
        ..lineTo(rect.left, rect.bottom - r)
        ..arcToPoint(Offset(rect.left + r, rect.bottom),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(rect.left + len, rect.bottom),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - len, rect.bottom)
        ..lineTo(rect.right - r, rect.bottom)
        ..arcToPoint(Offset(rect.right, rect.bottom - r),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(rect.right, rect.bottom - len),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticleScrimPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
