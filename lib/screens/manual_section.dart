import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ManualSection extends StatefulWidget {
  const ManualSection({super.key});

  @override
  State<ManualSection> createState() => _ManualSectionState();
}

class _ManualSectionState extends State<ManualSection> {
  final ScrollController _scrollController = ScrollController();
  bool _navVisible = true;
  double _lastScrollOffset = 0.0;
  Timer? _navIdleTimer;

  static const String _appVersion = 'v1.0.0';
  static const String _githubUrl =
      'https://github.com/zholzxszs/Silkreto-Mobile-App.git';
  static const double _manualScreenshotAspectRatio = 1620 / 2880;

  TextStyle get _h1 => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF5B532C),
  );

  TextStyle get _h2 => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: const Color(0xFF5B532C),
  );

  TextStyle get _label => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: const Color(0xFF5B532C),
  );

  TextStyle get _body => GoogleFonts.sourceSansPro(
    fontSize: 12.8,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: Colors.black.withOpacity(0.68),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
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

  void _openScreenshotPreview({
    required List<String> screenshotAssets,
    required int initialIndex,
  }) {
    if (screenshotAssets.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) {
        return _ScreenshotPreviewDialog(
          screenshotAssets: screenshotAssets,
          initialIndex: initialIndex,
          screenshotAspectRatio: _manualScreenshotAspectRatio,
          missingBuilder: _missingScreenshot,
        );
      },
    );
  }

  Widget _missingScreenshot(String assetPath) {
    return Container(
      color: const Color(0xFF111111),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported,
            color: Colors.white70,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'Screenshot placeholder for:\n$assetPath',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSansPro(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your screenshot asset later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSansPro(
              color: Colors.white54,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // ABOUT THE APP
  Widget _aboutCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 21),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF55B06F), Color(0xFF1E3A1D)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SILKRETO',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Silkworm Health Detection & Care Tips',
                      style: GoogleFonts.sourceSansPro(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Text(
                  _appVersion,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overview header
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.92),
              ),
              const SizedBox(width: 8),
              Text(
                'Overview',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Silkreto helps farmers detect Healthy and Unhealthy silkworms using image-based analysis. '
            'It also provides Care Tips and keeps a History for tracking improvements over time.',
            textAlign: TextAlign.justify,
            style: GoogleFonts.sourceSansPro(
              color: Colors.white.withOpacity(0.90),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          // Limitations header
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.92),
              ),
              const SizedBox(width: 8),
              Text(
                'Limitations & Disclaimer',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Silkreto uses AI-based image analysis to help identify healthy and unhealthy silkworms. '
            'While the model achieved a high rate of correct detections during testing, results may still vary depending on image quality, lighting, and visible symptoms. '
            'This tool is intended to assist farmers and should not replace expert judgment or proper farm management practices.',
            textAlign: TextAlign.justify,
            style: GoogleFonts.sourceSansPro(
              color: Colors.white.withOpacity(0.90),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _aboutRow(
                  icon: Icons.verified_outlined,
                  label: 'All Rights Reserved',
                  value: '© ${DateTime.now().year} Silkreto',
                ),
                const SizedBox(height: 8),
                _aboutRow(
                  icon: Icons.code_outlined,
                  label: 'GitHub Repository',
                  value: _githubUrl,
                  onCopy: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _githubUrl),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GitHub link copied')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Institution Header
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.92),
              ),
              const SizedBox(width: 8),
              Text(
                'Institution',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Logos Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Image.asset(
                      'assets/Team and Institution/DMMMSU Logo.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Don Mariano Marcos Memorial State University - South La Union Campus',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSansPro(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 30),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Image.asset(
                      'assets/Team and Institution/CCS Logo.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'College of Computer Science',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSansPro(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 22,
                      color: Colors.white.withOpacity(0.92),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Team',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Leader
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      backgroundImage: AssetImage(
                        'assets/Team and Institution/jud.png',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Judiel G. Legaspina (L)',
                      style: GoogleFonts.sourceSansPro(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Members title
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: Colors.white.withOpacity(0.92),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Members',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        [
                              {
                                'name': 'Renalyn C. Catabay',
                                'img': 'assets/Team and Institution/ren.png',
                              },
                              {
                                'name': 'Jessa C. Fajardo',
                                'img': 'assets/Team and Institution/jes.png',
                              },
                              {
                                'name': 'Mary Joy K. Madriaga',
                                'img': 'assets/Team and Institution/mar.png',
                              },
                              {
                                'name': 'Jerico C. Prado',
                                'img': 'assets/Team and Institution/jer.png',
                              },
                              {
                                'name': 'Jan Leigh D. Romero',
                                'img': 'assets/Team and Institution/jan.png',
                              },
                            ]
                            .map(
                              (member) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.15,
                                      ),
                                      backgroundImage: AssetImage(
                                        member['img']!,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      member['name']!,
                                      style: GoogleFonts.sourceSansPro(
                                        color: Colors.white.withOpacity(0.92),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),

                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.10)),
                const SizedBox(height: 18),

                // Adviser
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 20,
                      color: Colors.white.withOpacity(0.92),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thesis Adviser',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        backgroundImage: AssetImage(
                          'assets/Team and Institution/Fer.png',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Fernan H. Mendoza, DIT',
                        style: GoogleFonts.sourceSansPro(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.95)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.90),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.sourceSansPro(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(
                Icons.copy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detectionTipsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 21),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              _manualIconBadge(Icons.lightbulb_outline),
              const SizedBox(width: 10),
              Text('DETECTION TIPS', style: _h2),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            'Follow these tips to achieve more accurate and consistent results for both Scan and Upload.',
            textAlign: TextAlign.justify,
            style: _body,
          ),

          const SizedBox(height: 12),

          _tipItem(
            icon: Icons.wb_sunny_outlined,
            title: 'Proper Lighting',
            text:
                'Use bright, natural light if possible. Avoid dark environments and strong shadows.',
          ),

          _tipItem(
            icon: Icons.blur_off_outlined,
            title: 'Avoid Motion Blur',
            text:
                'Hold the camera steady and ensure the image is sharp before capturing.',
          ),

          _tipItem(
            icon: Icons.crop_square_outlined,
            title: 'Square Framing',
            text:
                'Keep the silkworms centered inside the square frame for consistent detection.',
          ),

          _tipItem(
            icon: Icons.center_focus_strong_outlined,
            title: 'Correct Distance',
            text:
                'Avoid capturing too close or too far. The silkworms should be clearly visible and well-focused.',
          ),

          _tipItem(
            icon: Icons.eco_outlined,
            title: 'Green or Leaf Background',
            text:
                'Use a green or leaf background, preferably mulberry leaves, for better accuracy.',
          ),

          _tipItem(
            icon: Icons.filter_9_plus_outlined,
            title: 'Silkworm Count per Frame',
            text:
                'Any number of silkworms can be detected, but try not to exceed 15 silkworms per frame. Too many may reduce fine detail and affect accuracy.',
          ),
        ],
      ),
    );
  }

  Widget _sampleDetectionsCard() {
    const samples = [
      _ManualScreenshot(assetPath: 'assets/About Mobile/SamDet1.png'),
      _ManualScreenshot(assetPath: 'assets/About Mobile/SamDet2.png'),
      _ManualScreenshot(assetPath: 'assets/About Mobile/SamDet3.png'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 21),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              _manualIconBadge(Icons.analytics_outlined),
              const SizedBox(width: 10),
              Text('SAMPLE DETECTIONS', style: _h2),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Example detection results showing how Silkreto identifies healthy and unhealthy silkworms. '
            'Swipe the images to see different detection outputs.',
            textAlign: TextAlign.justify,
            style: _body,
          ),

          const SizedBox(height: 14),

          _ManualScreenshotCarousel(
            screenshots: samples,
            previewHeightForWidth: _previewHeightForWidth,
            itemBuilder: (context, screenshot, previewHeight, index) {
              return GestureDetector(
                onTap: () => _openScreenshotPreview(
                  screenshotAssets: samples
                      .map((s) => s.assetPath)
                      .toList(growable: false),
                  initialIndex: index,
                ),
                child: _previewTile(
                  screenshotAsset: screenshot.assetPath,
                  height: previewHeight,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tipItem({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF63A361)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _label),
                const SizedBox(height: 2),
                Text(text, style: _body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _previewHeightForWidth(double width) {
    return (width * 0.78).clamp(210.0, 340.0).toDouble();
  }

  // Manual cards (with steps + what you'll see + tips)
  Widget _manualCard({
    required IconData icon,
    required String title,
    required String description,
    required List<String> steps,
    required List<String> whatYouSee,
    List<String> tips = const [],
    required List<_ManualScreenshot> screenshots,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 21),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              _manualIconBadge(icon),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _h2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: _body),
          const SizedBox(height: 12),
          Text('Step-by-step', style: _label),
          const SizedBox(height: 6),
          ...steps.asMap().entries.map((e) => _numbered(e.value, e.key)),
          const SizedBox(height: 10),
          Text('What you’ll see', style: _label),
          const SizedBox(height: 6),
          ...whatYouSee.map(_bullet),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Quick tips', style: _label),
            const SizedBox(height: 6),
            ...tips.map(_bullet),
          ],
          if (screenshots.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SizedBox(height: 8),
            _buildScreenshotGallery(
              sectionTitle: title,
              screenshots: screenshots,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScreenshotGallery({
    required String sectionTitle,
    required List<_ManualScreenshot> screenshots,
  }) {
    final screenshotAssets = screenshots
        .map((screenshot) => screenshot.assetPath)
        .toList(growable: false);

    if (screenshots.length == 1) {
      return _buildScreenshotPreview(screenshotAssets: screenshotAssets);
    }

    return _ManualScreenshotCarousel(
      key: ValueKey(sectionTitle),
      screenshots: screenshots,
      previewHeightForWidth: _previewHeightForWidth,
      itemBuilder: (context, screenshot, previewHeight, index) {
        return GestureDetector(
          onTap: () => _openScreenshotPreview(
            screenshotAssets: screenshotAssets,
            initialIndex: index,
          ),
          child: _previewTile(
            screenshotAsset: screenshot.assetPath,
            height: previewHeight,
          ),
        );
      },
    );
  }

  Widget _buildScreenshotPreview({required List<String> screenshotAssets}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewHeight = _previewHeightForWidth(constraints.maxWidth);

        return GestureDetector(
          onTap: () => _openScreenshotPreview(
            screenshotAssets: screenshotAssets,
            initialIndex: 0,
          ),
          child: _previewTile(
            screenshotAsset: screenshotAssets.first,
            height: previewHeight,
          ),
        );
      },
    );
  }

  Widget _manualIconBadge(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF63A361),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4E8E58)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _previewTile({
    required String screenshotAsset,
    required double height,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFF111111),
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: _manualScreenshotAspectRatio,
                  child: Image.asset(
                    screenshotAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF3F3F3),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image,
                              size: 28,
                              color: Color(0xFF8A8A8A),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Screenshot Placeholder',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                color: const Color(0xFF253D24),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF63A361)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _body)),
        ],
      ),
    );
  }

  Widget _numbered(String text, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0x1463A361),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x1F63A361)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF253D24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _body)),
        ],
      ),
    );
  }

  // Build
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
              color: const Color(0xFFF5F5F5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(screenSize.width),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'About the App',
                      style: _h1.copyWith(color: const Color(0xFF5B532C)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _aboutCard(),
                  const SizedBox(height: 18),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Detection Tips',
                      style: _h1.copyWith(color: const Color(0xFF5B532C)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Tips to help improve detection accuracy for both Scan and Upload.',
                      style: _body.copyWith(
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detectionTipsCard(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Sample Detections',
                      style: _h1.copyWith(color: const Color(0xFF5B532C)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Swipe through example detection outputs to understand how results appear.',
                      style: _body.copyWith(
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  _sampleDetectionsCard(),

                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Manual',
                      style: _h1.copyWith(color: const Color(0xFF5B532C)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 21),
                    child: Text(
                      'Use this guide to understand each section. Tap previews to see a larger screenshot.',
                      style: _body.copyWith(
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _manualCard(
                    icon: Icons.home_outlined,
                    title: 'HOME',
                    description:
                        'Main dashboard showing silkworm care information and analytics summaries.',
                    steps: const [
                      'Open the Home screen after launching the app.',
                      'Review analytics and monthly summaries to track trends.',
                    ],
                    whatYouSee: const [
                      'Analytics bar graph showing Healthy and Unhealthy counts across all months.',
                      'All Months section with individual cards showing percentage per month.',
                    ],
                    tips: const [
                      'Use the analytics bar graph to observe long-term trends.',
                      'Check All Months cards to compare performance per month.',
                    ],
                    screenshots: const [
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Landing Page.png',
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _manualCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'SCAN',
                    description:
                        'Use the camera to detect Healthy and Unhealthy silkworms with consistent framing and clear visibility.',

                    steps: const [
                      'Tap Scan on the bottom navigation.',
                      'Align the silkworms clearly inside the square frame.',
                      'Ensure the image is well-lit and in focus before capturing.',
                      'Tap the capture icon at the bottom center to analyze and view the results.',
                      'Retake or save the result to store it in History.',
                    ],

                    whatYouSee: const [
                      'Square camera frame for consistent input.',
                      'Bounding boxes + labels for detected worms.',
                      'Counts for Healthy and Unhealthy results.',
                      'Care Tips after detection (based on results).',
                    ],
                    tips: const [
                      'Use bright lighting and avoid motion blur.',
                      'Avoid heavy shadows and glare.',
                      'Keep the silkworms centered inside the frame for better detection.',
                      'Avoid overcrowding the frame, as dense groups may reduce fine detail.',
                      'Use a green or leaf-based background (preferably mulberry leaves) for better consistency with the model training.',
                    ],
                    screenshots: const [
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Camera.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Camera Preview.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Camera Results.png',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _manualCard(
                    icon: Icons.cloud_upload_outlined,
                    title: 'UPLOAD',
                    description:
                        'Analyze a photo from your gallery. Crop to a square frame for consistent detection and ensure the silkworms are clearly visible and well-spaced.',
                    steps: const [
                      'Tap Upload on the bottom navigation.',
                      'Choose an image from your gallery.',
                      'Crop to square (recommended) and confirm.',
                      'View detection results and save or reupload.',
                    ],
                    whatYouSee: const [
                      'Square cropped preview for consistent input.',
                      'Bounding boxes + labels (same as Scan).',
                      'Counts for Healthy and Unhealthy.',
                      'Care Tips after detection.',
                    ],
                    tips: const [
                      'Pick a clear, well-lit image.',
                      'Avoid extremely zoomed or low-resolution images.',
                      'If the photo is long or rectangular, crop it to a square for better framing.',
                      'Avoid overcrowded images, as dense groups may reduce fine detail.',
                      'Use a green or leaf-based background (preferably mulberry leaves) for better consistency with model training.',
                    ],
                    screenshots: const [
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Upload Select.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Upload Results.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/Upload Preview.png',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _manualCard(
                    icon: Icons.history_outlined,
                    title: 'HISTORY',
                    description:
                        'Review saved results, preview images, and manage downloads using filters.',
                    steps: const [
                      'Tap History on the bottom navigation.',
                      'Use the Month and Year filters to narrow down records.',
                      'Tap the Download icon to choose Raw or Labeled images.',
                      'Tap a thumbnail to preview a saved image.',
                    ],
                    whatYouSee: const [
                      'Download icon, Month filter, and Year filter in the same row.',
                      'Saved scan list with date and time.',
                      'Healthy and Unhealthy count chips.',
                      'Tap-to-preview image modal.',
                    ],
                    tips: const [
                      'Download Raw images without bounding boxes.',
                      'Download Labeled images with bounding boxes and labels.',
                      'Selected Month and Year filters determine which images will be downloaded.',
                    ],
                    screenshots: const [
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/History.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/History Preview.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his1.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his2.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his3.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his4.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his5.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his6.png',
                      ),
                      _ManualScreenshot(
                        assetPath: 'assets/About Mobile/his7.png',
                      ),
                    ],
                  ),
                  const SizedBox(height: 95),
                ],
              ),
            ),
          ),

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

  // Bottom nav (active = Manual)
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
          final isActive = item['label'] == 'Manual';

          return GestureDetector(
            onTap: () {
              final route = item['route'] as String?;
              if (route == null || route == '/manual') return;
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

typedef _ManualScreenshotTileBuilder =
    Widget Function(
      BuildContext context,
      _ManualScreenshot screenshot,
      double previewHeight,
      int index,
    );

class _ManualScreenshotCarousel extends StatefulWidget {
  final List<_ManualScreenshot> screenshots;
  final double Function(double width) previewHeightForWidth;
  final _ManualScreenshotTileBuilder itemBuilder;

  const _ManualScreenshotCarousel({
    super.key,
    required this.screenshots,
    required this.previewHeightForWidth,
    required this.itemBuilder,
  });

  @override
  State<_ManualScreenshotCarousel> createState() =>
      _ManualScreenshotCarouselState();
}

class _ManualScreenshotCarouselState extends State<_ManualScreenshotCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewHeight = widget.previewHeightForWidth(
          constraints.maxWidth,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: previewHeight,
              child: PageView.builder(
                itemCount: widget.screenshots.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final screenshot = widget.screenshots[index];
                  return widget.itemBuilder(
                    context,
                    screenshot,
                    previewHeight,
                    index,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.screenshots.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _currentIndex ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == _currentIndex
                        ? const Color(0xFF63A361)
                        : const Color(0xFFD2D2D2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Swipe screenshots',
              style: GoogleFonts.sourceSansPro(
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.45),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScreenshotPreviewDialog extends StatefulWidget {
  final List<String> screenshotAssets;
  final int initialIndex;
  final double screenshotAspectRatio;
  final Widget Function(String assetPath) missingBuilder;

  const _ScreenshotPreviewDialog({
    required this.screenshotAssets,
    required this.initialIndex,
    required this.screenshotAspectRatio,
    required this.missingBuilder,
  });

  @override
  State<_ScreenshotPreviewDialog> createState() =>
      _ScreenshotPreviewDialogState();
}

class _ScreenshotPreviewDialogState extends State<_ScreenshotPreviewDialog> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.screenshotAssets.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.screenshotAssets.length > 1;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxPreviewHeight = (constraints.maxHeight * 0.62)
                .clamp(240.0, 560.0)
                .toDouble();

            return Column(
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: maxPreviewHeight,
                          ),
                          color: const Color(0xFF111111),
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: widget.screenshotAssets.length,
                                onPageChanged: (index) {
                                  setState(() => _currentIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  final assetPath =
                                      widget.screenshotAssets[index];
                                  return Center(
                                    child: AspectRatio(
                                      aspectRatio: widget.screenshotAspectRatio,
                                      child: Image.asset(
                                        assetPath,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                widget.missingBuilder(
                                                  assetPath,
                                                ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (hasMultiple)
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.50),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${_currentIndex + 1}/${widget.screenshotAssets.length}',
                                      style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontSize: 11.3,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (hasMultiple) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.screenshotAssets.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: index == _currentIndex ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: index == _currentIndex
                                    ? const Color(0xFF63A361)
                                    : const Color(0xFFD2D2D2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
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
            );
          },
        ),
      ),
    );
  }
}

class _ManualScreenshot {
  final String assetPath;

  const _ManualScreenshot({required this.assetPath});
}
