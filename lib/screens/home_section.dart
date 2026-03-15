import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/scan_result_model.dart';

class HomeSection extends StatefulWidget {
  const HomeSection({super.key});

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _MonthBars {
  final int monthIndex;
  final String monthLabel;
  final int healthy;
  final int diseased;

  _MonthBars({
    required this.monthIndex,
    required this.monthLabel,
    required this.healthy,
    required this.diseased,
  });
}

Widget _miniLegendDot({required Color color, required String label}) {
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black.withOpacity(0.65),
        ),
      ),
    ],
  );
}

class _GroupedBarChartPainter extends CustomPainter {
  final List<_MonthBars> points;
  final int maxValue;
  final double t;

  _GroupedBarChartPainter({
    required this.points,
    required this.maxValue,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Layout
    final paddingTop = 6.0;
    final paddingBottom = 8.0;
    final paddingH = 4.0;

    final chartHeight = size.height - paddingTop - paddingBottom;
    final chartWidth = size.width - paddingH * 2;

    final origin = Offset(paddingH, paddingTop);

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFEFEFEF)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = origin.dy + chartHeight * (i / 4);
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + chartWidth, y),
        gridPaint,
      );
    }

    // Bars
    final groupW = chartWidth / points.length;
    final barW = (groupW * 0.22).clamp(6.0, 14.0); // responsive
    final gap = (groupW * 0.10).clamp(3.0, 10.0);

    final healthyPaint = Paint()..color = const Color(0xFF66A060);
    final diseasedPaint = Paint()..color = const Color(0xFFE84A4A);

    // Text painters
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );

    TextStyle labelInside(Color color) => TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      shadows: const [
        Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1)),
      ],
    );

    TextStyle labelAbove(Color color) =>
        TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      final baseX = origin.dx + groupW * i + (groupW / 2);
      final healthyX = baseX - gap / 2 - barW;
      final diseasedX = baseX + gap / 2;

      final hVal = p.healthy.toDouble();
      final dVal = p.diseased.toDouble();

      final hH = (hVal / maxValue) * chartHeight * t;
      final dH = (dVal / maxValue) * chartHeight * t;

      final r = Radius.circular(barW); // rounded top

      final hRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(healthyX, origin.dy + chartHeight - hH, barW, hH),
        topLeft: r,
        topRight: r,
      );

      final dRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(diseasedX, origin.dy + chartHeight - dH, barW, dH),
        topLeft: r,
        topRight: r,
      );

      // draw bars
      canvas.drawRRect(hRect, healthyPaint);
      canvas.drawRRect(dRect, diseasedPaint);

      // draw labels ONLY when animation is far enough so it doesn't jitter
      final showLabels = t > 0.75;

      if (showLabels) {
        // Healthy label
        _drawValueOnBar(
          canvas: canvas,
          tp: tp,
          value: p.healthy,
          barX: healthyX,
          barW: barW,
          barTopY: origin.dy + chartHeight - hH,
          barHeight: hH,
          insideStyle: labelInside(const Color(0xFF66A060)),
          aboveStyle: labelAbove(const Color(0xFF66A060)),
        );

        // Unhealthy label
        _drawValueOnBar(
          canvas: canvas,
          tp: tp,
          value: p.diseased,
          barX: diseasedX,
          barW: barW,
          barTopY: origin.dy + chartHeight - dH,
          barHeight: dH,
          insideStyle: labelInside(const Color(0xFFE84A4A)),
          aboveStyle: labelAbove(const Color(0xFFE84A4A)),
        );
      }
    }
  }

  void _drawValueOnBar({
    required Canvas canvas,
    required TextPainter tp,
    required int value,
    required double barX,
    required double barW,
    required double barTopY,
    required double barHeight,
    required TextStyle insideStyle,
    required TextStyle aboveStyle,
  }) {
    if (value <= 0) return; // don't show 0 labels

    final text = value.toString();

    // Decide whether to put label inside or above based on height
    // If bar is tall enough: inside near top; else above the bar
    const insidePadding = 4.0;
    const abovePadding = 3.0;

    // measure text
    tp.text = TextSpan(text: text, style: insideStyle);
    tp.layout(minWidth: 0, maxWidth: barW + 20);

    final canFitInside = barHeight >= (tp.height + 10);

    if (canFitInside) {
      // inside (white) near top area
      final dx = barX + (barW - tp.width) / 2;
      final dy = barTopY + insidePadding; // slightly below rounded top
      tp.paint(canvas, Offset(dx, dy));
    } else {
      // above (colored)
      tp.text = TextSpan(text: text, style: aboveStyle);
      tp.layout(minWidth: 0, maxWidth: barW + 20);

      final dx = barX + (barW - tp.width) / 2;
      final dy = (barTopY - tp.height - abovePadding).clamp(
        0.0,
        double.infinity,
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedBarChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.t != t;
  }
}

class _HomeSectionState extends State<HomeSection> {
  final ScrollController _scrollController = ScrollController();
  bool _navVisible = true;
  double _lastScrollOffset = 0.0;
  Timer? _navIdleTimer;

  List<int> _availableYears = [];
  int? _selectedYear;
  Map<String, Map<String, int>> _monthlyAnalytics = {};

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initHomeFlow();
    });
  }

  Future<void> _initHomeFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownDialog = prefs.getBool('permissions_dialog_shown') ?? false;

    final cam = await Permission.camera.status;

    if (!hasShownDialog && cam.isDenied) {
      await _showPermissionsDialog();
      await prefs.setBool('permissions_dialog_shown', true);
    }

    if (cam.isDenied) {
      await Permission.camera.request();
    }

    await _loadAnalyticsData();
  }

  Future<void> _showPermissionsDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Permissions Required',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF5B532C),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SILKRETO needs the following permissions to function properly:',
                  style: GoogleFonts.sourceSansPro(
                    fontSize: 14,
                    color: const Color(0xFF5B532C),
                  ),
                ),
                const SizedBox(height: 20),
                _buildPermissionItem(
                  Icons.camera_alt,
                  'Camera',
                  'Required to scan silkworm images for health detection.',
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  Icons.photo_library,
                  'Gallery Access',
                  'Allows you to select an image from your gallery. Android provides temporary access only to the selected image.',
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  Icons.save_alt,
                  'Local Storage',
                  'Scan results and processed images are saved locally on your device.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open app settings if permissions are permanently denied
                final cameraStatus = await Permission.camera.status;

                if (cameraStatus.isPermanentlyDenied) {
                  await AppSettings.openAppSettings();
                }
              },
              child: Text(
                'Open Settings',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF63A361),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF63A361),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: const Color(0xFF63A361)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B532C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.sourceSansPro(
                  fontSize: 12,
                  color: const Color(0xCC5B532C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadAnalyticsData() async {
    final results = await DatabaseHelper().getAllScanResults();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final years = results
        .map((r) {
          try {
            return dateFormat.parse(r.scanDate).year;
          } catch (e) {
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
      _availableYears = years;
      if (years.contains(now.year)) {
        _selectedYear = now.year;
      } else if (years.isNotEmpty) {
        _selectedYear = years.first;
      }
      _processDataForYear(_selectedYear, results);
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

  void _processDataForYear(int? year, List<ScanResult> allResults) {
    if (year == null) return;

    final dateFormat = DateFormat('MMM dd, yyyy');
    final yearlyResults = allResults.where((r) {
      try {
        return dateFormat.parse(r.scanDate).year == year;
      } catch (e) {
        return false;
      }
    }).toList();

    final analytics = <String, Map<String, int>>{};
    for (var result in yearlyResults) {
      try {
        final date = dateFormat.parse(result.scanDate);
        final monthName = _months[date.month - 1];

        if (!analytics.containsKey(monthName)) {
          analytics[monthName] = {'healthy': 0, 'unhealthy': 0};
        }

        analytics[monthName]!['healthy'] =
            (analytics[monthName]!['healthy'] ?? 0) + result.healthyCount;
        analytics[monthName]!['diseased'] =
            (analytics[monthName]!['diseased'] ?? 0) + result.diseasedCount;
      } catch (e) {
        // Ignore records with parsing errors
      }
    }

    setState(() {
      _monthlyAnalytics = analytics;
    });
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
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Container(
              width: screenSize.width,
              constraints: BoxConstraints(minHeight: screenSize.height),
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar
                  _buildHeader(screenSize.width),
                  const SizedBox(height: 28),

                  // Analytics Section
                  _buildSectionTitle('Analytics'),
                  const SizedBox(height: 12),

                  // Year Dropdown
                  _buildYearDropdown(screenSize.width),
                  const SizedBox(height: 12),

                  // Line Graph Card
                  _buildBarGraphCard(screenSize.width),
                  const SizedBox(height: 40),

                  // All Months Section - Updated
                  _buildAllMonthsSection(screenSize.width),

                  // Placeholder for floating nav space
                  const SizedBox(height: 95),
                ],
              ),
            ),
          ),
          // Floating Bottom Navigation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            bottom: _navVisible
                ? MediaQuery.of(context).padding.bottom + 35
                : -100,
            left: 42,
            right: 42,
            child: _buildBottomNavigation(screenSize.width),
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
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // SILKRETO Title
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          color: const Color(0xFF5B532C),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildYearDropdown(double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
              if (newValue != null) {
                setState(() {
                  _selectedYear = newValue;
                  _loadAnalyticsData(); // Reload and re-process data for the new year
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarGraphCard(double width) {
    // only months with data
    final monthsWithData =
        _monthlyAnalytics.entries.where((e) {
          final healthy = e.value['healthy'] ?? 0;
          final diseased = e.value['diseased'] ?? 0;
          return (healthy + diseased) > 0;
        }).toList()..sort(
          (a, b) => _months.indexOf(a.key).compareTo(_months.indexOf(b.key)),
        );

    if (monthsWithData.isEmpty) {
      return Container(
        width: width - 42,
        height: 190,
        margin: const EdgeInsets.symmetric(horizontal: 21),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAEAEA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No data found for the selected year.',
            style: GoogleFonts.sourceSansPro(
              fontSize: 13,
              color: Colors.black.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Build chart points
    final points = monthsWithData.map((e) {
      final mIndex = _months.indexOf(e.key);
      final healthy = e.value['healthy'] ?? 0;
      final diseased = e.value['diseased'] ?? 0;
      final short = e.key.substring(0, 3);
      return _MonthBars(
        monthIndex: mIndex,
        monthLabel: short,
        healthy: healthy,
        diseased: diseased,
      );
    }).toList();

    final maxValue = points
        .map((p) => (p.healthy > p.diseased ? p.healthy : p.diseased))
        .fold<int>(0, (prev, v) => v > prev ? v : prev);

    return Container(
      width: width - 42,
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 21),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Monthly Counts',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF253D24),
                ),
              ),
              const Spacer(),
              _miniLegendDot(color: const Color(0xFF66A060), label: 'Healthy'),
              const SizedBox(width: 10),
              _miniLegendDot(
                color: const Color(0xFFE84A4A),
                label: 'Unhealthy',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chart
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return CustomPaint(
                  painter: _GroupedBarChartPainter(
                    points: points,
                    maxValue: maxValue <= 0 ? 1 : maxValue,
                    t: t,
                  ),
                  child: Container(),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // X labels row
          SizedBox(
            height: 18,
            child: Row(
              children: points.map((p) {
                return Expanded(
                  child: Center(
                    child: Text(
                      p.monthLabel,
                      style: GoogleFonts.sourceSansPro(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllMonthsSection(double width) {
    final cardWidth = width - 42;

    final sortedMonths = _monthlyAnalytics.keys.toList()
      ..sort((a, b) => _months.indexOf(b).compareTo(_months.indexOf(a)));

    // keep only months that have non-zero data
    final monthsWithData = sortedMonths.where((monthName) {
      final data = _monthlyAnalytics[monthName];
      if (data == null) return false;
      final total = (data['healthy'] ?? 0) + (data['diseased'] ?? 0);
      return total > 0;
    }).toList();

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Months',
            style: GoogleFonts.nunito(
              color: const Color(0xFF5B532C),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendRow(),
          const SizedBox(height: 8),

          if (monthsWithData.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text('No data found for the selected year.'),
              ),
            )
          else
            Column(
              children: monthsWithData.map<Widget>((monthName) {
                final data = _monthlyAnalytics[monthName]!;
                final total = (data['healthy'] ?? 0) + (data['diseased'] ?? 0);

                final healthyPercent = total > 0
                    ? (((data['healthy'] ?? 0) * 100) / total).round()
                    : 0;

                final diseasedPercent = total > 0
                    ? (((data['diseased'] ?? 0) * 100) / total).round()
                    : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMonthCard(
                    monthName,
                    healthyPercent,
                    diseasedPercent,
                    cardWidth,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendRow() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildLollipopLegendItem('Healthy', const Color(0xFF66A060)),
          const SizedBox(width: 14),
          _buildLollipopLegendItem('Unhealthy', const Color(0xFFE84A4A)),
        ],
      ),
    );
  }

  Widget _buildLollipopLegendItem(String text, Color color) {
    return Row(
      children: [
        // Lollipop visualization
        SizedBox(
          width: 20,
          height: 15,
          child: Stack(
            children: [
              // Horizontal line
              Positioned(
                left: 0,
                top: 6, // Center vertically
                child: Container(
                  width: 15,
                  height: 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.nunito(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCard(
    String month,
    int healthy,
    int diseased,
    double width,
  ) {
    return Container(
      width: width,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3F000000),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month Name
          Text(
            month,
            style: GoogleFonts.nunito(
              color: const Color(0xFF5B532C),
              fontSize: 14, // CHANGED: 12 to 14
              fontWeight: FontWeight.w700,
            ),
          ),

          // Percentages Row (centered on bars)
          SizedBox(
            height: 20,
            child: Stack(
              children: [
                // Healthy percentage
                Positioned(
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      // Healthy segment space
                      Expanded(
                        flex: healthy,
                        child: Center(
                          child: Text(
                            '$healthy%',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFF66A060),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2),
                      // Unhealthy segment space
                      Expanded(
                        flex: diseased,
                        child: Center(
                          child: Text(
                            '$diseased%',
                            style: GoogleFonts.nunito(
                              color: const Color(0xFFE84A4A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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

          // Bars
          Row(
            children: [
              Expanded(
                flex: healthy,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF66A060),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: diseased,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE84A4A),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
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

    void _handleNavigation(String route) {
      Navigator.pushNamed(context, route);
    }

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
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: navItems.asMap().entries.map<Widget>((entry) {
          final item = entry.value;
          final isActive = item['label'] == 'Home';
          return GestureDetector(
            onTap: () {
              _handleNavigation(item['route'] as String);
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
