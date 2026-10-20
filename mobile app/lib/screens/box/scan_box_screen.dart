import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../../controllers/smart_box_controller.dart";
import "../../models/medicine_box_model.dart";
import "../../services/smart_box_service.dart";
import "../../utils/app_colors.dart";
import "../../utils/app_radius.dart";
import "../../utils/app_spacing.dart";
import "box_screen.dart";

class ScanBoxScreen extends StatefulWidget {
  const ScanBoxScreen({super.key, SmartBoxController? controller})
    : _controller = controller;

  final SmartBoxController? _controller;

  @override
  State<ScanBoxScreen> createState() => _ScanBoxScreenState();
}

class _ScanBoxScreenState extends State<ScanBoxScreen> {
  late SmartBoxController _controller;
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _initializing = true;
  String? _lastError;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _controller = widget._controller ?? SmartBoxController();
    _controller.addListener(_onController);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _initializing = false);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    _cameraController.dispose();
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    setState(() {
      _lastError = _controller.error;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_initializing) {
      if (mounted) setState(() => _initializing = false);
    }
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final String? raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _lastError = null;
    });

    final MedicineBoxQrPayload? payload;
    try {
      payload = MedicineBoxQrPayload.parse(raw);
    } on MedicineBoxQrParseException catch (e) {
      if (!mounted) {
        _isProcessing = false;
        return;
      }
      setState(() {
        _lastError = e.message;
        _isProcessing = false;
      });
      return;
    } catch (_) {
      if (!mounted) {
        _isProcessing = false;
        return;
      }
      setState(() {
        _lastError = const InvalidMedicineBoxQrException().message;
        _isProcessing = false;
      });
      return;
    }

    try {
      final MedicineBoxModel activated = await _controller.activateBox(
        deviceId: payload.deviceId,
        deviceToken: payload.deviceToken,
      );
      final String medicineBoxId = activated.id.trim();
      MedicineBoxModel box = activated;
      if (medicineBoxId.isNotEmpty) {
        try {
          box = await _controller.reloadBox(medicineBoxId);
        } catch (_) {
          box = activated;
        }
        try {
          await _controller.loadDrawersForBox(medicineBoxId);
        } catch (_) {}
      }
      await _cameraController.stop();
      if (!mounted) return;
      final bool deviceOffline = !box.deviceStatus.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: deviceOffline ? 4 : 2),
          backgroundColor:
              deviceOffline ? AppColors.warning : AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text(
            deviceOffline
                ? "Medicine box activated.\nDevice is currently offline. Read-only access is available until your box connects."
                : "Medicine box activated successfully.",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => BoxScreen(
            initialBoxId: box.id,
            initialBox: box,
            controller: _controller,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        _isProcessing = false;
        return;
      }
      setState(() {
        _lastError = e.toString().trim().isEmpty
            ? "Failed to activate medicine box."
            : e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.br12,
                        side: BorderSide(color: AppColors.border),
                      ),
                      padding: EdgeInsets.all(AppSpacing.xxs),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "Scan Medicine Box",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.br20,
                          border: Border.all(color: AppColors.border),
                          color: Colors.black,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: MobileScanner(
                                controller: _cameraController,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      MobileScannerException error,
                                      Widget? child,
                                    ) {
                                      if (mounted) {
                                        setState(() {
                                          _initializing = false;
                                        });
                                      }
                                      final String? rawMsg =
                                          error.errorDetails?.message ??
                                          error.errorDetails?.details
                                              ?.toString() ??
                                          error.toString();
                                      final String msg =
                                          rawMsg == null ||
                                              rawMsg.trim().isEmpty
                                          ? "Unable to open camera. Grant camera permission in your device settings and try again."
                                          : rawMsg;
                                      return _CameraErrorView(
                                        message: msg,
                                        onRetry: () {
                                          setState(() {
                                            _permissionError = msg;
                                          });
                                          _cameraController.start();
                                        },
                                      );
                                    },
                                onDetect: _onDetect,
                              ),
                            ),
                            CustomPaint(
                              painter: _ScanFramePainter(
                                frameColor: scheme.primary,
                              ),
                              size: Size.infinite,
                            ),
                            if (_initializing && _permissionError == null)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (_isProcessing)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black54,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "Activating medicine box…",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: AppRadius.br16,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.br12,
                              gradient: LinearGradient(
                                colors: <Color>[
                                  scheme.primary,
                                  scheme.primary.withOpacity(0.78),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: scheme.primary.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  "Scan the QR code on your medicine box",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Hold the camera steady until the code is recognized.",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_lastError != null && _lastError!.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: AppRadius.br12,
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _lastError!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                setState(() {
                                  _lastError = null;
                                  _permissionError = null;
                                  _initializing = true;
                                });
                                try {
                                  await _cameraController.stop();
                                } catch (_) {}
                                if (!mounted) return;
                                await _cameraController.start();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.br14,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          "Re-scan",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121316),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              borderRadius: AppRadius.br16,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.videocam_off_rounded,
              color: AppColors.error,
              size: 34,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          const Text(
            "Camera unavailable",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFC8CCD2),
              height: 1.4,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.br12),
            ),
            child: const Text(
              "Retry",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.frameColor});
  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double squareSide = w < h ? w * 0.78 : h * 0.78;
    final double left = (w - squareSide) / 2;
    final double top = (h - squareSide) / 2;
    final Rect rect = Rect.fromLTWH(left, top, squareSide, squareSide);

    final Paint darkOverlay = Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.fill;
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, darkOverlay);

    final Paint framePaint = Paint()
      ..color = frameColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const double corner = 30;

    void drawCorner(Offset a, Offset b, Offset c) {
      final Path p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy);
      canvas.drawPath(p, framePaint);
    }

    final Radius r = const Radius.circular(26);
    final double rX = r.x;
    final double rY = r.y;

    final Offset tlA = Offset(left, top + corner);
    final Offset tlB = Offset(left, top + rY);
    final Offset tlC = Offset(left + corner, top);
    final Offset tlC2 = Offset(left + rX, top);
    drawCorner(tlA, tlB, tlC);
    final Path tlArc = Path()
      ..moveTo(tlB.dx, tlB.dy)
      ..quadraticBezierTo(left, top, tlC2.dx, tlC2.dy);
    canvas.drawPath(tlArc, framePaint);

    final Offset trA = Offset(left + squareSide - corner, top);
    final Offset trB = Offset(left + squareSide - rX, top);
    final Offset trC = Offset(left + squareSide, top + corner);
    final Offset trC2 = Offset(left + squareSide, top + rY);
    drawCorner(trA, trB, trC);
    final Path trArc = Path()
      ..moveTo(trB.dx, trB.dy)
      ..quadraticBezierTo(left + squareSide, top, trC2.dx, trC2.dy);
    canvas.drawPath(trArc, framePaint);

    final Offset blA = Offset(left, top + squareSide - corner);
    final Offset blB = Offset(left, top + squareSide - rY);
    final Offset blC = Offset(left + corner, top + squareSide);
    final Offset blC2 = Offset(left + rX, top + squareSide);
    drawCorner(blA, blB, blC);
    final Path blArc = Path()
      ..moveTo(blB.dx, blB.dy)
      ..quadraticBezierTo(left, top + squareSide, blC2.dx, blC2.dy);
    canvas.drawPath(blArc, framePaint);

    final Offset brA = Offset(left + squareSide - corner, top + squareSide);
    final Offset brB = Offset(left + squareSide - rX, top + squareSide);
    final Offset brC = Offset(left + squareSide, top + squareSide - corner);
    final Offset brC2 = Offset(left + squareSide, top + squareSide - rY);
    drawCorner(brA, brB, brC);
    final Path brArc = Path()
      ..moveTo(brB.dx, brB.dy)
      ..quadraticBezierTo(
        left + squareSide,
        top + squareSide,
        brC2.dx,
        brC2.dy,
      );
    canvas.drawPath(brArc, framePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.frameColor != frameColor;
}
