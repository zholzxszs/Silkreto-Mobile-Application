import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SquareCameraScreen extends StatefulWidget {
  const SquareCameraScreen({super.key});

  @override
  State<SquareCameraScreen> createState() => _SquareCameraScreenState();
}

class _SquareCameraScreenState extends State<SquareCameraScreen> {
  CameraController? _controller;
  bool _busy = true;

  FlashMode _flashMode = FlashMode.off;
  double _exposure = 0.0;

  double _minExposure = 0.0;
  double _maxExposure = 0.0;

  String _flashLabel() {
    switch (_flashMode) {
      case FlashMode.off:
        return 'OFF';
      case FlashMode.auto:
        return 'AUTO';
      case FlashMode.torch:
        return 'ON';
      default:
        return 'OFF';
    }
  }

  Future<void> _toggleFlash() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    FlashMode next;
    if (_flashMode == FlashMode.off) {
      next = FlashMode.auto;
    } else if (_flashMode == FlashMode.auto) {
      next = FlashMode.torch;
    } else {
      next = FlashMode.off;
    }

    try {
      await ctrl.setFlashMode(next);
      if (!mounted) return;
      setState(() => _flashMode = next);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Exposure range (varies by device)
      try {
        _minExposure = await controller.getMinExposureOffset();
        _maxExposure = await controller.getMaxExposureOffset();
      } catch (_) {
        _minExposure = 0.0;
        _maxExposure = 0.0;
      }

      _exposure = 0.0;
      try {
        await controller.setExposureOffset(_exposure);
      } catch (_) {}

      // Default flash off
      await controller.setFlashMode(_flashMode);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.pop(context); // fallback: just close if camera init failed
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureSquare() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    setState(() => _busy = true);

    try {
      final xfile = await c.takePicture();

      final bytes = await File(xfile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Failed to decode image');

      final side = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      final x = ((decoded.width - side) / 2).round();
      final y = ((decoded.height - side) / 2).round();

      final cropped = img.copyCrop(
        decoded,
        x: x,
        y: y,
        width: side,
        height: side,
      );

      final resized = img.copyResize(
        cropped,
        width: 640,
        height: 640,
        interpolation: img.Interpolation.cubic,
      );

      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/scan_square_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath)
        ..writeAsBytesSync(img.encodeJpg(resized, quality: 90));

      if (!mounted) return;
      Navigator.pop(context, outFile.path);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _busy || c == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 10),

                  // Preview locked to 1:1
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final ctrl = _controller!;
                              final double side = constraints.maxWidth;

                              final rawAR = ctrl.value.aspectRatio;

                              final isPortrait =
                                  MediaQuery.of(context).orientation ==
                                  Orientation.portrait;
                              final double previewAR = isPortrait
                                  ? (1 / rawAR)
                                  : rawAR;

                              double childW;
                              double childH;
                              if (previewAR >= 1.0) {
                                // wider than tall
                                childH = side;
                                childW = side * previewAR;
                              } else {
                                // taller than wide
                                childW = side;
                                childH = side / previewAR;
                              }

                              return ClipRect(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: childW,
                                    height: childH,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CameraPreview(ctrl),

                                        // Flash toggle
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: _toggleFlash,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.45,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.flash_on,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _flashLabel(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Exposure slider
                                        if (_maxExposure != _minExposure)
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            bottom: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.45,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.wb_sunny,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  Expanded(
                                                    child: Slider(
                                                      value: _exposure,
                                                      min: _minExposure,
                                                      max: _maxExposure,
                                                      onChanged: (v) async {
                                                        final c = _controller;
                                                        if (c == null) return;
                                                        setState(
                                                          () => _exposure = v,
                                                        );
                                                        try {
                                                          await c
                                                              .setExposureOffset(
                                                                v,
                                                              );
                                                        } catch (_) {}
                                                      },
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
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Capture button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ElevatedButton(
                      onPressed: _busy ? null : _captureSquare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(18),
                      ),
                      child: const Icon(Icons.camera_alt, size: 28),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
