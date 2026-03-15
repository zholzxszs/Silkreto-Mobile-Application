import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/scan_result_model.dart';
import '../services/tflite_model_service.dart';

enum _DownloadType { raw, annotated }

class HistorySection extends StatefulWidget {
  const HistorySection({super.key});

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  final ScrollController _scrollController = ScrollController();
  bool _navVisible = true;
  double _lastScrollOffset = 0.0;
  Timer? _navIdleTimer;

  List<ScanResult> _allScanResults = [];
  List<ScanResult> _filteredScanResults = [];
  List<int> _availableYears = [];
  int? _selectedYear;
  String? _selectedMonth;

  final MediaStore _mediaStore = MediaStore();

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    MediaStore.appFolder = 'Silkreto';
    _scrollController.addListener(_onScroll);
    _loadScanResults();
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

  String _folderForType(_DownloadType type) {
    return type == _DownloadType.raw ? 'Silkreto-Raw' : 'Silkreto-Labeled';
  }

  String _kindForType(_DownloadType type) {
    return type == _DownloadType.raw ? 'raw' : 'labeled';
  }

  void _loadScanResults() async {
    final results = await DatabaseHelper().getAllScanResults();
    final dateFormat = DateFormat('MMM dd, yyyy');

    final years = results
        .map((r) {
          try {
            return dateFormat.parse(r.scanDate).year;
          } catch (_) {
            return null;
          }
        })
        .where((y) => y != null)
        .cast<int>()
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));
    final now = DateTime.now();

    setState(() {
      _allScanResults = results;
      _availableYears = years;

      if (years.contains(now.year)) {
        _selectedYear = now.year;
      } else if (years.isNotEmpty) {
        _selectedYear = years.first;
      }

      _selectedMonth = _months[now.month - 1];
      _filterResults();
    });
  }

  void _filterResults() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (_selectedYear == null) {
      _filteredScanResults = _allScanResults;
    } else {
      _filteredScanResults = _allScanResults.where((r) {
        try {
          final date = dateFormat.parse(r.scanDate);
          final yearMatches = date.year == _selectedYear;
          final monthMatches =
              _selectedMonth == null ||
              date.month == (_months.indexOf(_selectedMonth!) + 1);
          return yearMatches && monthMatches;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    setState(() {});
  }

  Future<void> _deleteScanResult(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this record?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper().deleteScanResult(id);
      _loadScanResults();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Record deleted')));
      }
    }
  }

  void _showImagePreviewFromHistory(
    BuildContext context,
    ScanResult scanResult,
  ) {
    final previewPath =
        scanResult.annotatedImagePath ?? scanResult.rawImagePath;

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${scanResult.scanDate} • ${scanResult.scanTime}',
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(previewPath), fit: BoxFit.cover),
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
                                    'H: ${scanResult.healthyCount}   UH: ${scanResult.diseasedCount}',
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

  @override
  void dispose() {
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
              _buildFilters(),
              _buildHistoryList(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 35 + 60),
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

  Widget _buildHeader(double width) {
    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.50, 0.00),
          end: Alignment(0.50, 1.00),
          colors: [const Color(0xFF63A361), const Color(0xFF375936)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3F000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildDownloadIconButton(),
          const SizedBox(width: 8),
          _buildMonthDropdown(),
          const SizedBox(width: 8),
          _buildYearDropdown(),
        ],
      ),
    );
  }

  Widget _buildDownloadIconButton() {
    final isDisabled = _filteredScanResults.isEmpty;

    return SizedBox(
      height: 34,
      width: 36,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isDisabled ? null : _showDownloadChoiceDialog,
          child: Center(
            child: Icon(
              Icons.download,
              size: 16,
              color: isDisabled ? Colors.grey : const Color(0xFF253D24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _selectedMonth,
        hint: Text('Month', style: GoogleFonts.nunito(fontSize: 12)),
        underline: const SizedBox(),
        isDense: true,
        items: _months.map((String month) {
          return DropdownMenuItem<String>(
            value: month,
            child: Text(month, style: GoogleFonts.nunito(fontSize: 12)),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedMonth = newValue;
            _filterResults();
          });
        },
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<int>(
        value: _selectedYear,
        hint: Text('Year', style: GoogleFonts.nunito(fontSize: 12)),
        underline: const SizedBox(),
        isDense: true,
        items: _availableYears.map((int year) {
          return DropdownMenuItem<int>(
            value: year,
            child: Text(
              year.toString(),
              style: GoogleFonts.nunito(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedYear = newValue;
            _filterResults();
          });
        },
      ),
    );
  }

  Future<void> _showDownloadChoiceDialog() async {
    final monthText = _selectedMonth ?? 'All Months';
    final yearText = _selectedYear?.toString() ?? 'All Years';

    final choice = await showDialog<_DownloadType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Images'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.sourceSansPro(
                  fontSize: 14,
                  color: const Color(0xFF5B532C),
                ),
                children: [
                  const TextSpan(
                    text:
                        'This will download data based on the current filter: ',
                  ),
                  TextSpan(
                    text: '$monthText $yearText',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose file type:',
              style: GoogleFonts.sourceSansPro(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B532C),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DownloadType.raw),
            child: const Text('Raw'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DownloadType.annotated),
            child: const Text('Labeled'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    await _downloadFilteredImages(choice);
  }

  Future<Uint8List> _addHdOverlayToImageBytes({
    required String baseImagePath,
    required int healthyCount,
    required int diseasedCount,
  }) async {
    final data = await File(baseImagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(uiImage.width.toDouble(), uiImage.height.toDouble());

    // draw base image (raw or already-annotated)
    canvas.drawImage(uiImage, Offset.zero, Paint());

    // dynamic font sizing
    final baseSize = min(size.width, size.height);
    final fontSize = (baseSize * 0.045).clamp(14.0, 34.0).toDouble();
    final pad = (fontSize * 0.45);

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: 'H: $healthyCount   UH: $diseasedCount',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(0, 1)),
          ],
        ),
      ),
    )..layout();

    final x = 20.0;
    final y = 20.0;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        x,
        y,
        textPainter.width + pad * 2,
        textPainter.height + pad * 2,
      ),
      const Radius.circular(10),
    );

    canvas.drawRRect(bgRect, Paint()..color = Colors.black.withOpacity(0.45));
    textPainter.paint(canvas, Offset(x + pad, y + pad));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(uiImage.width, uiImage.height);

    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  Future<void> _downloadFilteredImages(_DownloadType type) async {
    int success = 0;
    int missing = 0;
    final missingExamples = <String>[];

    for (final scan in _filteredScanResults) {
      //  RAW = rawImagePath, LABELED = annotatedImagePath
      final sourcePath = (type == _DownloadType.raw)
          ? scan.rawImagePath
          : (scan.annotatedImagePath ?? '');

      if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
        missing++;
        if (missingExamples.length < 3) {
          missingExamples.add(sourcePath.isEmpty ? '(empty path)' : sourcePath);
        }
        continue;
      }

      final ok = await _saveToDownloadsViaMediaStore(
        sourcePath,
        scan: scan,
        type: type,
      );

      if (ok) success++;
    }

    if (!mounted) return;

    if (success == 0) {
      final debug = missingExamples.isEmpty
          ? ''
          : '\nMissing example:\n- ${missingExamples.join('\n- ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No images downloaded.\nMissing: $missing.$debug'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final folder = _folderForType(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved $success image(s) to Downloads/$folder. Missing: $missing.',
        ),
      ),
    );
  }

  /// Saves to Downloads and converts non-JPG to JPG without resizing.
  Future<bool> _saveToDownloadsViaMediaStore(
    String sourcePath, {
    required ScanResult scan,
    required _DownloadType type,
  }) async {
    try {
      final bytes = (type == _DownloadType.annotated)
          ? await _addHdOverlayToImageBytes(
              baseImagePath: sourcePath, // annotatedImagePath OR rawImagePath
              healthyCount: scan.healthyCount,
              diseasedCount: scan.diseasedCount,
            )
          : await _loadBytesPreferOriginal(sourcePath);

      final tempDir = await getTemporaryDirectory();
      final safeDate = scan.scanDate.replaceAll(',', '').replaceAll(' ', '-');
      final safeTime = scan.scanTime.replaceAll(':', '-').replaceAll(' ', '');
      final kind = _kindForType(type);

      final ext = (type == _DownloadType.annotated)
          ? '.png'
          : _targetExtensionFor(sourcePath);
      final fileName = 'silkreto_${safeDate}_${safeTime}_$kind$ext';

      await Directory(tempDir.path).create(recursive: true);
      final tempPath = p.join(tempDir.path, fileName);
      await File(tempPath).writeAsBytes(bytes, flush: true);

      final folderName = _folderForType(type);

      await _mediaStore.saveFile(
        tempFilePath: tempPath,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: folderName,
      );

      return true;
    } catch (e) {
      debugPrint('DOWNLOAD ERROR ($sourcePath): $e');
      return false;
    }
  }

  /// Returns bytes without recompressing, unless we MUST convert.
  Future<Uint8List> _loadBytesPreferOriginal(String path) async {
    final ext = p.extension(path).toLowerCase();

    // Keep exact bytes for common formats (no quality loss)
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
      return Uint8List.fromList(await File(path).readAsBytes());
    }

    // Convert only if needed (ex: heic/heif or unknown)
    final raw = await File(path).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw Exception('Failed to decode image: $path');
    }

    // use PNG (lossless) to avoid blur
    return Uint8List.fromList(img.encodePng(decoded));
  }

  /// If converted -> .png, else keep original extension
  String _targetExtensionFor(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
      return ext;
    }
    return '.png'; // converted formats become PNG (lossless)
  }

  Widget _buildHistoryList() {
    if (_filteredScanResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No data found for the selected period.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _filteredScanResults.length,
      itemBuilder: (context, index) =>
          _buildHistoryCard(context, _filteredScanResults[index]),
    );
  }

  Widget _buildHistoryCard(BuildContext context, ScanResult scanResult) {
    final imagePath = scanResult.annotatedImagePath ?? scanResult.rawImagePath;
    final hasImage = File(imagePath).existsSync();

    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => _showImagePreviewFromHistory(context, scanResult),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFD9D9D9),
                image: hasImage
                    ? DecorationImage(
                        image: FileImage(File(imagePath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (!hasImage)
                    const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  if (hasImage)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${scanResult.scanDate} at ${scanResult.scanTime}',
                      style: GoogleFonts.nunito(
                        color: const Color(0xFF5B532C),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteScanResult(scanResult.id!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCountChip(
                      'Healthy: ${scanResult.healthyCount}',
                      const Color(0xFF4CAF50),
                      Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _buildCountChip(
                      'Unhealthy: ${scanResult.diseasedCount}',
                      const Color(0xFFF44336),
                      Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        children: navItems.asMap().entries.map<Widget>((entry) {
          final item = entry.value;
          final isActive = item['label'] == 'History';

          return GestureDetector(
            onTap: () {
              final route = item['route'] as String?;
              if (route == null || route == '/history') return;
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

    final double baseSize = min(size.width, size.height);
    final double dynamicStroke = (baseSize * 0.014).clamp(4, 12.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dynamicStroke;

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
      final double textSize = (baseSize * 0.04).clamp(14.0, 30.0);

      final label = (d.classId >= 0 && d.classId < labels.length)
          ? labels[d.classId]
          : 'Class ${d.classId}';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: paint.color,
          fontSize: textSize,
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
