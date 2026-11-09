import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';

/// Full-screen camera scanner for product barcodes and QR codes (PRD §14).
///
/// Push it and await the result: the scanned (or typed) code, or null if the
/// user backed out. Reads EAN-13/8, UPC, Code 128/39 and QR codes.
///
/// ```dart
/// final code = await BarcodeScannerScreen.scan(context);
/// ```
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  static Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(), fullscreenDialog: true),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  bool _done = false;
  bool _torchOn = false;

  bool get _am => Localizations.localeOf(context).languageCode == 'am';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done || !mounted) return;
    _done = true; // ignore any further detections while popping
    Navigator.of(context).pop(code.trim());
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _finish(value);
        return;
      }
    }
  }

  Future<void> _enterManually() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_am ? 'ኮዱን ይጻፉ' : 'Type the code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: _am ? 'ባርኮድ፣ QR ወይም SKU' : 'Barcode, QR or SKU',
            prefixIcon: const Icon(Icons.qr_code),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_am ? 'ተመለስ' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(_am ? 'ፈልግ' : 'Find')),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Wide, short window suits 1-D barcodes and still fits QR codes.
    final windowWidth = size.width * 0.8;
    final windowHeight = windowWidth * 0.6;
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.4),
      width: windowWidth,
      height: windowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_am ? 'ባርኮድ / QR ይቃኙ' : 'Scan barcode / QR'),
        actions: [
          IconButton(
            tooltip: _am ? 'መብራት' : 'Flashlight',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error, am: _am, onManual: _enterManually),
          ),
          // Dim everything except the scan window.
          IgnorePointer(
            child: CustomPaint(painter: _ScanWindowPainter(scanWindow), size: size),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: scanWindow.bottom + 20,
            child: Text(
              _am ? 'ባርኮዱን ወይም QR ኮዱን በሳጥኑ ውስጥ ያስገቡ' : 'Place the barcode or QR code inside the box',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: OutlinedButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.keyboard, color: Colors.white),
                label: Text(_am ? 'ኮዱን በእጅ ይጻፉ' : 'Type the code instead',
                    style: const TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Rect window;
  _ScanWindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(window, const Radius.circular(16));
    final background = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, background, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.primaryGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter old) => old.window != window;
}

class _CameraError extends StatelessWidget {
  final MobileScannerException error;
  final bool am;
  final VoidCallback onManual;

  const _CameraError({required this.error, required this.am, required this.onManual});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            denied
                ? (am ? 'ካሜራ ለመጠቀም ፈቃድ ያስፈልጋል። በስልክዎ ቅንብሮች ውስጥ ይፍቀዱ።'
                    : 'Camera permission is needed. Allow it in your phone settings.')
                : (am ? 'ካሜራውን መክፈት አልተቻለም።' : 'The camera could not be started.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.keyboard),
            label: Text(am ? 'ኮዱን በእጅ ይጻፉ' : 'Type the code instead'),
          ),
        ],
      ),
    );
  }
}
