import 'package:dtx/providers/auth_provider.dart';
import 'package:dtx/models/auth_model.dart';
import 'package:dtx/providers/feed_provider.dart'; // Import FeedProvider
import 'package:dtx/providers/filter_provider.dart'; // Import FilterProvider
import 'package:dtx/views/google_sign_in_screen.dart';
import 'package:dtx/views/location.dart';
import 'package:dtx/views/main_navigation_screen.dart'; // Import MainNavigationScreen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed FeedType import
// Removed NameInputScreen import
// Removed Home import

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  bool _animationComplete = false;
  bool _statusCheckComplete = false;
  AuthStatus _authStatus = AuthStatus.unknown;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkAuthStatus();
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _animationComplete = true;
        });
        _navigateIfReady();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    print('[SplashScreen] Checking Auth Status...');
    try {
      final status = await ref
          .read(authProvider.notifier)
          .checkAuthStatus(updateState: false);
      print('[SplashScreen] Auth Status Check Result: $status');

      if (!mounted) return;

      setState(() {
        _authStatus = status;
        _statusCheckComplete = true;
      });
      _navigateIfReady();
    } catch (e) {
      print('[SplashScreen] Error during Auth Status Check: $e');
      if (!mounted) return;
      setState(() {
        _authStatus = AuthStatus.login; // Default to login on error
        _statusCheckComplete = true;
      });
      _navigateIfReady();
    }
  }

  void _initiateEarlyFetches() {
    print("[SplashScreen] Initiating early data fetches (Filters, HomeFeed).");
    // Don't await, let them run in background
    ref.read(filterProvider.notifier).loadFilters();
    ref.read(feedProvider.notifier).fetchFeed();
  }

  void _navigateIfReady() {
    print(
        '[SplashScreen] Navigate If Ready: Animation Complete=$_animationComplete, Status Check Complete=$_statusCheckComplete, Status=$_authStatus');

    if (_animationComplete && _statusCheckComplete) {
      print('[SplashScreen] Conditions met. Navigating...');
      Widget destination;

      switch (_authStatus) {
        case AuthStatus.home:
        case AuthStatus
              .onboarding2: // Both home and onboarding2 go to main screen
          print('[SplashScreen] Navigating to MainNavigationScreen');
          _initiateEarlyFetches(); // Start loading data needed for MainNavigationScreen
          destination = const MainNavigationScreen();
          break;
        case AuthStatus.onboarding1:
          print('[SplashScreen] Navigating to LocationInputScreen');
          destination = const LocationInputScreen();
          break;
        case AuthStatus.login:
        case AuthStatus.unknown:
        default:
          print('[SplashScreen] Navigating to GoogleSignInScreen');
          destination = const GoogleSignInScreen();
          break;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      print('[SplashScreen] Conditions not met. Waiting...');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build method remains largely the same, only navigation logic changed
    final Size screenSize = MediaQuery.of(context).size;
    final double responsiveFontSize = screenSize.width * 0.18;
    final double subtitleFontSize = screenSize.width * 0.04;
    final double bottomPadding = screenSize.height * 0.05;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Peeple',
                          style: GoogleFonts.pacifico(
                            fontSize: responsiveFontSize,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: bottomPadding,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Text(
                      'Connect. Share. Thrive.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_animationComplete && !_statusCheckComplete)
              Positioned(
                bottom: bottomPadding + 50,
                left: 0,
                right: 0,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
