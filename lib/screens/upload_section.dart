import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/scan_result_model.dart';
import '../services/tflite_model_service.dart';
import 'package:crop_your_image/crop_your_image.dart';

class UploadSection extends StatefulWidget {
  const UploadSection({super.key});

  @override
  State<UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<UploadSection> {
  final ImagePicker _picker = ImagePicker();

  XFile? _image;

  bool _isProcessing = false; // analyzing
  bool _isSaving = false;
  bool _busyPicking = false;

  int? healthyCount;
  int? diseasedCount;

  // YOLO detections for bounding boxes
  List<Detection> _detections = const [];
  ModelPrediction? _lastPrediction;

  // Floating nav behavior
  final ScrollController _scrollController = ScrollController();
  bool _navVisible = true;
  double _lastScrollOffset = 0.0;
  Timer? _navIdleTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);

    // Auto open gallery when screen loads (init model first to reduce delay)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await TFLiteModelService().ensureInitialized();
      } catch (_) {}
      await _pickFromGallery();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    const threshold = 4.0;

    // Hide while scrolling up; show when scrolling down.
    if (delta > threshold) {
      _setNavVisibility(false);
    } else if (delta < -threshold) {
      _setNavVisibility(true);
    }

    _lastScrollOffset = offset;
    _restartIdleTimer();
  }

  void _setNavVisibility(bool visible) {
    if (_navVisible == visible || !mounted) return;
    setState(() => _navVisible = visible);
  }

  void _restartIdleTimer() {
    _navIdleTimer?.cancel();
    _navIdleTimer = Timer(const Duration(milliseconds: 260), () {
      _setNavVisibility(true);
    });
  }

  Future<Uint8List?> _cropSquareToJpeg(Uint8List originalBytes) async {
    final controller = CropController();
    CropResult? result;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),

                      // Crop area in a square
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Crop(
                            controller: controller,
                            image: originalBytes,
                            aspectRatio: 1, // fixed square
                            withCircleUi: false,
                            baseColor: Colors.black,
                            maskColor: Colors.black.withOpacity(0.55),
                            onCropped: (CropResult r) {
                              result = r;
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            result = null;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF253D24),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFBDBDBD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => controller.crop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF63A361),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            'Crop',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return null;
    if (result is CropFailure) return null;

    final croppedPngBytes = (result as CropSuccess).croppedImage;

    // convert to JPEG quality 100 (NO resize)
    final decoded = img.decodeImage(croppedPngBytes);
    if (decoded == null) return null;

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 100));
  }

  Future<void> _pickFromGallery() async {
    if (_busyPicking) return;
    _busyPicking = true;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: null,
        maxWidth: null,
        maxHeight: null,
      );

      if (!mounted) return;

      if (picked == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image was selected.')));
        return;
      }

      /// Get file extension
      final extension = picked.path.split('.').last.toLowerCase();

      /// Allowed formats
      const allowedFormats = ['jpg', 'jpeg', 'png'];

      if (!allowedFormats.contains(extension)) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unsupported file format: .$extension. Only JPEG, JPG, and PNG images are supported.',
            ),
          ),
        );
        return;
      }

      /// Read image
      final file = File(picked.path);
      if (!await file.exists()) {
        throw Exception("Selected file could not be accessed.");
      }

      final fileBytes = await file.readAsBytes();

      final decoded = img.decodeImage(fileBytes);
      if (decoded == null) {
        throw Exception("Failed to decode the selected image.");
      }

      /// Downscale extremely large images
      final int maxSide = max(decoded.width, decoded.height);
      final double scale = maxSide > 2048 ? 2048 / maxSide : 1.0;

      final img.Image processed = scale < 1
          ? img.copyResize(
              decoded,
              width: (decoded.width * scale).round(),
              height: (decoded.height * scale).round(),
              interpolation: img.Interpolation.average,
            )
          : decoded;

      /// Encode resized image (keep high quality)
      final Uint8List originalBytes = Uint8List.fromList(
        img.encodeJpg(processed, quality: 100),
      );

      /// Crop square
      final croppedJpegBytes = await _cropSquareToJpeg(originalBytes);
      if (!mounted) return;

      if (croppedJpegBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image cropping was cancelled.')),
        );
        return;
      }

      /// Save cropped image
      final tempDir = await getTemporaryDirectory();

      final outPath =
          '${tempDir.path}/upload_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await File(outPath).writeAsBytes(croppedJpegBytes, flush: true);

      /// Update UI
      setState(() {
        _image = XFile(outPath);
      });

      /// Analyze image
      await _analyzeCurrentImage();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to process the selected image. Please try another image.',
          ),
        ),
      );
    } finally {
      _busyPicking = false;
    }
  }

  Future<void> _analyzeCurrentImage() async {
    if (_image == null) return;

    setState(() {
      _isProcessing = true;
      healthyCount = null;
      diseasedCount = null;
      _detections = const [];
      _lastPrediction = null;
    });

    await Future.delayed(const Duration(milliseconds: 16));

    try {
      final modelService = TFLiteModelService();
      await modelService.ensureInitialized();

      final prediction = await modelService.predictFromImage(_image!.path);

      if (!mounted) return;
      setState(() {
        healthyCount = prediction.healthyCount;
        diseasedCount = prediction.diseasedCount;
        _detections = prediction.detections;
        _lastPrediction = prediction;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Analyze error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildPreviewWithBoxes() {
    if (_image == null) return const SizedBox.shrink();

    // Draw on fixed 640x640 then scale/crop together with the image
    return Stack(
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: 640,
              height: 640,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(File(_image!.path), fit: BoxFit.fill),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: YoloBoxPainter(
                          detections: _detections,
                          labels: const ['H', 'UH'],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Overlay badge
        if (_isProcessing || _isSaving)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isProcessing ? 'Analyzing...' : 'Saving...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Preview',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reupload() async {
    setState(() {
      _image = null;
      healthyCount = null;
      diseasedCount = null;
      _detections = const [];
      _lastPrediction = null;
    });

    await _pickFromGallery();
  }

  Future<void> _confirmAndSave() async {
    if (_image == null) return;

    setState(() => _isSaving = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImage = File('${appDir.path}/$fileName');
      await File(_image!.path).copy(newImage.path);

      final now = DateTime.now();
      final dateFormat = DateFormat('MMM dd, yyyy');
      final timeFormat = DateFormat('h:mm a');

      // Use last prediction (avoid re-inference)
      ModelPrediction prediction = _lastPrediction ?? ModelPrediction.empty();
      if (prediction.status == 'Unknown') {
        final modelService = TFLiteModelService();
        await modelService.ensureInitialized();
        prediction = await modelService.predictFromImage(newImage.path);
      }

      if (mounted) {
        setState(() {
          healthyCount = prediction.healthyCount;
          diseasedCount = prediction.diseasedCount;
          _detections = prediction.detections;
          _lastPrediction = prediction;
        });
      }

      // Create annotated image with boxes
      String? annotatedImagePath;
      if (prediction.detections.isNotEmpty) {
        final bytes = File(newImage.path).readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image != null) {
          final int maxSide = max(image.width, image.height);
          final double scale = maxSide > 1600 ? 1600.0 / maxSide : 1.0;
          final img.Image baseImage = scale < 1
              ? img.copyResize(
                  image,
                  width: (image.width * scale).round(),
                  height: (image.height * scale).round(),
                  interpolation: img.Interpolation.linear,
                )
              : image;

          final canvas = img.Image.from(baseImage);
          final double minSide = min(
            canvas.width.toDouble(),
            canvas.height.toDouble(),
          );
          final int boxThickness = (minSide * 0.0045)
              .round()
              .clamp(3, 10)
              .toInt();

          for (final d in prediction.detections) {
            final color = d.classId == 0
                ? img.ColorRgb8(102, 166, 96)
                : img.ColorRgb8(228, 74, 74);

            // auto detect normalized coords
            final isNorm =
                d.x1.abs() <= 1.5 &&
                d.y1.abs() <= 1.5 &&
                d.x2.abs() <= 1.5 &&
                d.y2.abs() <= 1.5;

            final x1 =
                (isNorm ? d.x1 * canvas.width : d.x1 / 640.0 * canvas.width)
                    .toInt()
                    .clamp(0, canvas.width - 1);
            final y1 =
                (isNorm ? d.y1 * canvas.height : d.y1 / 640.0 * canvas.height)
                    .toInt()
                    .clamp(0, canvas.height - 1);
            final x2 =
                (isNorm ? d.x2 * canvas.width : d.x2 / 640.0 * canvas.width)
                    .toInt()
                    .clamp(0, canvas.width - 1);
            final y2 =
                (isNorm ? d.y2 * canvas.height : d.y2 / 640.0 * canvas.height)
                    .toInt()
                    .clamp(0, canvas.height - 1);

            img.drawRect(
              canvas,
              x1: x1,
              y1: y1,
              x2: x2,
              y2: y2,
              color: color,
              thickness: boxThickness,
            );
          }

          final annotatedFileName =
              'annotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final annotatedPath = '${appDir.path}/$annotatedFileName';
          File(annotatedPath).writeAsBytesSync(img.encodeJpg(canvas));
          annotatedImagePath = annotatedPath;
        }
      }

      final scanResult = ScanResult(
        rawImagePath: newImage.path,
        annotatedImagePath: annotatedImagePath,
        status: prediction.status,
        scanDate: dateFormat.format(now),
        scanTime: timeFormat.format(now),
        healthyCount: prediction.healthyCount,
        diseasedCount: prediction.diseasedCount,
      );

      await DatabaseHelper().insertScanResult(scanResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload saved successfully')),
        );
      }

      // Reset
      if (mounted) {
        setState(() {
          _image = null;
          healthyCount = null;
          diseasedCount = null;
          _detections = const [];
          _lastPrediction = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showUploadPreview() {
    if (_image == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header + Legends
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF253D24),
                              ),
                            ),
                          ),
                          _legendChip(
                            color: const Color(0xFF66A060),
                            label: 'Healthy',
                          ),
                          const SizedBox(width: 8),
                          _legendChip(
                            color: const Color(0xFFE84A4A),
                            label: 'Unhealthy',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Image + Boxes (square) - NO LABELS
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_image!.path), fit: BoxFit.cover),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: YoloBoxPainterPreview(
                                    detections: _detections,
                                  ),
                                ),
                              ),

                              // Count overlay
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'H: ${healthyCount ?? 0}   UH: ${diseasedCount ?? 0}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black54,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Close button below preview
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF63A361),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendChip({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _navIdleTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(screenWidth),
              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        minHeight: 280,
                        maxHeight: 280,
                      ),
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _image == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No image selected',
                                    style: GoogleFonts.nunito(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _pickFromGallery,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF63A361),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Select Image'),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: _showUploadPreview,
                              child: _buildPreviewWithBoxes(),
                            ),
                    ),

                    const SizedBox(height: 24),

                    if (_image != null && !_isProcessing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            'Healthy: ${healthyCount ?? 0}',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFF66A060),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Unhealthy: ${diseasedCount ?? 0}',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFFE84A4A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),

                    if (_image != null && !_isProcessing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _isProcessing ? null : _reupload,
                            child: Container(
                              width: 130,
                              height: 44,
                              decoration: ShapeDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment(0.50, 0.00),
                                  end: Alignment(0.50, 1.00),
                                  colors: [
                                    Color(0xFFE84A4A),
                                    Color(0xFF822929),
                                  ],
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                shadows: const [
                                  BoxShadow(
                                    color: Color(0x3F000000),
                                    blurRadius: 10,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Reupload',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _isSaving ? null : _confirmAndSave,
                            child: Container(
                              width: 130,
                              height: 44,
                              decoration: ShapeDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment(0.50, 1.00),
                                  end: Alignment(0.50, 0.00),
                                  colors: [
                                    Color(0xFF253D24),
                                    Color(0xFF488646),
                                  ],
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                shadows: const [
                                  BoxShadow(
                                    color: Color(0x3F000000),
                                    blurRadius: 10,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Save',
                                        style: GoogleFonts.nunito(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 14),

                    _buildDecisionSupportCard(),

                    const SizedBox(height: 160),
                  ],
                ),
              ),
            ],
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            bottom: _navVisible
                ? MediaQuery.of(context).padding.bottom + 35
                : -100,
            left: 42,
            right: 42,
            child: _buildBottomNavigation(screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionSupportCard() {
    final int? hRaw = healthyCount;
    final int? dRaw = diseasedCount;

    if (hRaw == null && dRaw == null) {
      return const SizedBox.shrink();
    }

    final int h = hRaw ?? 0;
    final int u = dRaw ?? 0;
    final int total = h + u;

    if (total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              "No silkworms were detected",
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Please upload an image containing silkworm larvae to generate health analysis and recommendations.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final double ratio = u / total;
    final double healthyPercent = (h / total) * 100;
    final double unhealthyPercent = (u / total) * 100;
    final double incidencePercent = (u / total) * 100;

    String riskLabel;
    String headline;
    List<String> tips;

    Color pillBg;
    Color pillFg = Colors.white;

    const double lowHighCutoff = 0.10;
    const double severeCutoff = 0.25;

    if (ratio < lowHighCutoff) {
      riskLabel = 'LOW HEALTH RISK';
      pillBg = const Color(0xFF2E7D32);

      headline =
          'Unhealthy signs are below 10%. Maintain hygiene, good feeding practices, and stable conditions to keep risk low.';

      tips = const [
        'Disinfect/clean trays, tools, and rearing area regularly; remove leftover leaves and waste. (Chopade et al., 2021)',
        'Feed fresh, clean, dry mulberry leaves; avoid wet, wilted, or contaminated leaves. (Chopade et al., 2021)',
        'Keep the rearing bed dry; remove wet leaves/waste promptly to reduce contamination build-up. (Chopade et al., 2021)',
        'Maintain stable temperature and humidity; climatic factors can influence health issues and outbreaks. (Rabha et al., 2025)',
        'Monitor daily and isolate any early symptomatic larvae immediately. (Chopade et al., 2021)',
      ];
    } else if (ratio < severeCutoff) {
      riskLabel = 'ELEVATED HEALTH RISK';
      pillBg = const Color(0xFFF57C00);

      headline =
          'Unhealthy signs are 10–24%. Start control actions now: isolate symptomatic larvae, sanitize more often, and stabilize the environment.';

      tips = const [
        'Separate symptomatic/unhealthy larvae promptly to reduce spread. (Chopade et al., 2021)',
        'Increase cleaning/disinfection frequency of trays and rearing beds; remove waste fast. (Chopade et al., 2021)',
        'Avoid overcrowding—spread larvae into more trays to reduce contact transmission and stress. (Chopade et al., 2021)',
        'Stabilize temperature/RH and improve gentle ventilation; weather factors are associated with incidence changes. (Rabha et al., 2025)',
        'Track the trend daily; if unhealthy signs keep rising toward outbreak-level ranges, stronger action may be needed. (Kadam & Manjare, 2025)',
      ];
    } else {
      riskLabel = 'CRITICAL HEALTH RISK';
      pillBg = const Color(0xFFC62828);

      headline =
          'Unhealthy signs are ≥25% (outbreak-level range reported in commercial rearing). Consider stopping the batch and perform full sanitation before restarting.';

      tips = const [
        'Consider terminating the current batch if unhealthy signs keep spreading to prevent larger losses and cross-contamination. (Kadam & Manjare, 2025)',
        'Isolate the rearing unit; dispose/destroy affected larvae and contaminated waste properly. (Chopade et al., 2021)',
        'Perform thorough cleaning and disinfection of the rearing house, trays, and tools before any new batch. (Chopade et al., 2021)',
        'If pébrine is suspected or issues recur, prioritize disease-free eggs/stock and confirm using diagnostic methods. (Gu et al., 2024)',
        'Restart only after full sanitation and stable environmental conditions are restored. (Chopade et al., 2021)',
      ];
    }

    const String note =
        'Note: Unhealthy signs refer to visible abnormalities that may be linked to disease or environmental stress. '
        'Recommendations below are general biosecurity/management practices based on published disease-control literature.';

    final List<String> references = const [
      'Chopade, P., & Raghavendra, C. G. (2021). Assessment of diseases in Bombyx mori silkworm–A survey. Global Transitions Proceedings, 2(1), 133-136.',
      'Gu, H., Cao, Z., Chen, K., & Lü, P. (2024). Detection and control of pébrine disease in the silkworm (Bombyx mori). Invertebrate Survival Journal.',
      'Kadam, R. S., & Manjare, S. A. (2025). Studies on incidence of major seasonal diseases in commercial improved silkworm crossbreeds.',
      'Rabha, M., Ethungbeni, T. N., Rahul, K., Alam, K., & Maheswari, M. (2025). Temporal analysis of climatic factors influencing silkworm disease incidences.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF447042),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grass_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips & Recommendations',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        riskLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: pillFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// PERCENTAGE SUMMARY
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric(
                  label: "Healthy",
                  value: "${healthyPercent.toStringAsFixed(1)}%",
                  color: const Color(0xFF2E7D32),
                ),
                _buildMetric(
                  label: "Unhealthy",
                  value: "${unhealthyPercent.toStringAsFixed(1)}%",
                  color: const Color(0xFFC62828),
                ),
                _buildMetric(
                  label: "Incidence",
                  value: "${incidencePercent.toStringAsFixed(1)}%",
                  color: pillBg,
                  highlight: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          /// HEADLINE
          Text(
            headline,
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          /// NOTE
          Text(
            note,
            style: GoogleFonts.nunito(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.85),
            ),
          ),

          const SizedBox(height: 12),

          /// TIPS
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF63A361),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.6),
          ),

          const SizedBox(height: 10),

          /// REFERENCES
          Text(
            'REFERENCES',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          ...references.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                r,
                textAlign: TextAlign.justify,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: highlight ? 20 : 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildHeader(double width) {
    return Container(
      width: width,
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.50, 0.00),
          end: Alignment(0.50, 1.00),
          colors: [const Color(0xFF63A361), const Color(0xFF375936)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            'SILKRETO',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.90,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(double width) {
    final navItems = [
      {'icon': Icons.home_outlined, 'label': 'Home', 'route': '/home'},
      {'icon': Icons.camera_alt_outlined, 'label': 'Scan', 'route': '/scan'},
      {
        'icon': Icons.cloud_upload_outlined,
        'label': 'Upload',
        'route': '/upload',
      },
      {'icon': Icons.history_outlined, 'label': 'History', 'route': '/history'},
      {'icon': Icons.menu_book_outlined, 'label': 'Manual', 'route': '/manual'},
    ];

    return Container(
      width: width - 84,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.50, 0.00),
          end: Alignment(0.50, 1.00),
          colors: [Color(0xFFFFC50F), Color(0xFF997609)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: navItems.map((item) {
          final isActive = item['label'] == 'Upload';
          return GestureDetector(
            onTap: () {
              final route = item['route'] as String?;
              if (route == null || route == '/upload') return;
              Navigator.pushNamed(context, route);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 24,
                    color: isActive
                        ? const Color(0xFF2F2F2F)
                        : const Color(0xFF504926),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.nunito(
                      color: isActive
                          ? const Color(0xFF2F2F2F)
                          : const Color(0xFF504926),
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class YoloBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final List<String> labels;

  YoloBoxPainter({required this.detections, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    final bool isNormalized = detections.every(
      (d) =>
          d.x1.abs() <= 1.5 &&
          d.y1.abs() <= 1.5 &&
          d.x2.abs() <= 1.5 &&
          d.y2.abs() <= 1.5,
    );

    for (final d in detections) {
      paint.color = (d.classId == 0)
          ? const Color(0xFF66A060)
          : const Color(0xFFE84A4A);

      double x1 = d.x1, y1 = d.y1, x2 = d.x2, y2 = d.y2;

      if (isNormalized) {
        x1 *= size.width;
        x2 *= size.width;
        y1 *= size.height;
        y2 *= size.height;
      } else {
        x1 = x1 / 640.0 * size.width;
        x2 = x2 / 640.0 * size.width;
        y1 = y1 / 640.0 * size.height;
        y2 = y2 / 640.0 * size.height;
      }

      final rect = Rect.fromLTRB(
        x1.clamp(0.0, size.width),
        y1.clamp(0.0, size.height),
        x2.clamp(0.0, size.width),
        y2.clamp(0.0, size.height),
      );

      canvas.drawRect(rect, paint);

      final label = (d.classId >= 0 && d.classId < labels.length)
          ? labels[d.classId]
          : 'Class ${d.classId}';
      final text = label;

      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: paint.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();

      final textOffset = Offset(
        rect.left,
        max(0, rect.top - textPainter.height),
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant YoloBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}

// Preview painter - shows boxes WITH labels
class YoloBoxPainterPreview extends CustomPainter {
  final List<Detection> detections;

  YoloBoxPainterPreview({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    final bool isNormalized = detections.every(
      (d) =>
          d.x1.abs() <= 1.5 &&
          d.y1.abs() <= 1.5 &&
          d.x2.abs() <= 1.5 &&
          d.y2.abs() <= 1.5,
    );

    for (final d in detections) {
      paint.color = (d.classId == 0)
          ? const Color(0xFF66A060)
          : const Color(0xFFE84A4A);

      double x1 = d.x1, y1 = d.y1, x2 = d.x2, y2 = d.y2;

      if (isNormalized) {
        x1 *= size.width;
        x2 *= size.width;
        y1 *= size.height;
        y2 *= size.height;
      } else {
        x1 = x1 / 640.0 * size.width;
        x2 = x2 / 640.0 * size.width;
        y1 = y1 / 640.0 * size.height;
        y2 = y2 / 640.0 * size.height;
      }

      final rect = Rect.fromLTRB(
        x1.clamp(0.0, size.width),
        y1.clamp(0.0, size.height),
        x2.clamp(0.0, size.width),
        y2.clamp(0.0, size.height),
      );

      canvas.drawRect(rect, paint);

      // Draw labels (H or UH)
      final label = d.classId == 0 ? 'H' : 'UH';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: paint.color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();

      final textOffset = Offset(
        rect.left,
        max(0, rect.top - textPainter.height),
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant YoloBoxPainterPreview oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
