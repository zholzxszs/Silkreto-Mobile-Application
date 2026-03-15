import 'package:flutter/material.dart';
import 'package:silkreto/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AssetImage _backgroundImage = const AssetImage(
    'assets/silkreto-logo-bg-rev.jpg',
  );
  final AssetImage _logoImage = const AssetImage(
    'assets/silkreto-logo-png.png',
  );

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  static const String appVersion = 'v1.0.0';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_backgroundImage, context);
    precacheImage(_logoImage, context);
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _fadeAnimation = TweenSequence<double>([
      // Fade in
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      // Hold
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      // Fade out
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            opaque: false,
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (_, animation, _) {
              return FadeTransition(
                opacity: animation,
                child: const HomeScreen(),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background (static)
          Image(image: _backgroundImage, fit: BoxFit.cover),

          // Logo (fade only)
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoWidth = constraints.maxWidth * 0.5;
                  return Image(
                    image: _logoImage,
                    width: logoWidth.clamp(160, 260),
                  );
                },
              ),
            ),
          ),

          // Footer text
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: const [
                  Text(
                    appVersion,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '© 2026 Silkreto. All rights reserved.',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
