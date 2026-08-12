import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65, curve: Curves.easeIn)),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        widget.onFinish();
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
      backgroundColor: AppTheme.primaryNavy,
      body: Stack(
        children: [
          // Background Gradient subtle glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F382C),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Luxury Calligraphy Logo Container
                        Container(
                          width: 140,
                          height: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.secondaryGold.withOpacity(0.35),
                                blurRadius: 30,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: AppTheme.secondaryGold, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Firm Title
                        const Text(
                          'شركة حجاج عبدالرحمن الضويحي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'للمحاماة والاستشارات القانونية',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryGold,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Loading Spinner with Gold accent
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryGold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer Text
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'منصة إدارة القضايا والخدمات القانونية © 2026',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
